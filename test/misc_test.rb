require_relative "test_helper"

class MiscTest < Minitest::Test
  def test_healthy
    assert_equal true, immudb.healthy?
  end

  def test_version
    skip if immudb.version == "1"
    assert_match(/\A\d+\.\d+/, immudb.version)
  end

  def test_clean_index
    error = assert_raises(Immudb::Error) do
      immudb.clean_index
    end
    assert_match "compaction threshold not yet reached", error.message
  end
end
