require_relative "test_helper"

class MiscTest < Minitest::Test
  def test_healthy
    assert_equal true, immudb.healthy?
  end

  def test_version
    assert_match(/\A\d+\.\d+\.\d+/, immudb.version)
  end

  def test_clean_index
    assert_nil immudb.clean_index
  end
end
