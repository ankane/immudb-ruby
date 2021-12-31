require_relative "test_helper"

class DatabaseTest < Minitest::Test
  def test_list_databases
    assert_includes immudb.list_databases, "testdb"
  end
end
