require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"

Immudb::Client.new.create_database("testdb") rescue nil

class Minitest::Test
  def immudb
    @immudb ||= Immudb::Client.new(database: "testdb")
  end

  def immudb2
    @immudb2 ||= Immudb::Client.new(database: "testdb")
  end

  def random_key
    "key#{rand(100_000_000)}"
  end

  def random_table
    "table#{rand(100_000_000)}"
  end

  def random_user
    "testuser#{rand(100_000_000)}"
  end
end
