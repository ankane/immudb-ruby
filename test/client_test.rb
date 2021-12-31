require_relative "test_helper"

class ClientTest < Minitest::Test
  def test_invalid_host
    error = assert_raises(ArgumentError) do
      Immudb::Client.new(host: "localhost:3322")
    end
    assert_equal "Invalid host", error.message
  end

  def test_invalid_scheme
    error = assert_raises(ArgumentError) do
      Immudb::Client.new(url: "http://")
    end
    assert_equal "Expected url to start with immudb://", error.message
  end

  def test_inspect
    assert_match /\A#<Immudb::Client:0x[0-9a-f]+>\z/, immudb.inspect
    assert_match /\A#<Immudb::Client:0x[0-9a-f]+>\z/, immudb.to_s

    # double check
    refute_match "token", immudb.inspect
    refute_match "token", immudb.to_s
  end
end
