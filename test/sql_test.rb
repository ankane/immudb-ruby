require_relative "test_helper"

class SqlTest < Minitest::Test
  def test_works
    table = random_table

    immudb.sql_exec("CREATE TABLE #{table} (id INTEGER, name VARCHAR, PRIMARY KEY id)")
    assert_includes immudb.list_tables, table
    # sort needed for immudb 1.0
    assert_equal ["id", "name"], immudb.describe_table(table).map { |v| v["COLUMN"] }.sort

    immudb.sql_exec("INSERT INTO #{table} (id, name) VALUES (1, 'Chicago')")
    immudb.sql_exec("INSERT INTO #{table} (id, name) VALUES (@id, @name)", {id: 2, name: "New York"})
    immudb.sql_exec("INSERT INTO #{table} (id, name) VALUES (@id, @name)", {id: 3, name: nil})

    result = immudb.sql_query("SELECT * FROM #{table} ORDER BY id")
    expected = [
      {"id" => 1, "name" => "Chicago"},
      {"id" => 2, "name" => "New York"},
      {"id" => 3, "name" => nil}
    ]
    assert_equal expected, result.to_a

    assert_equal 1, immudb.sql_query("SELECT * FROM #{table} WHERE id = @id", {id: 1}).rows.size
  end

  def test_unsupported_param
    error = assert_raises(ArgumentError) do
      immudb.sql_query("SELECT @v", {v: Object.new})
    end
    assert_equal "Unsupported param type: Object", error.message
  end
end
