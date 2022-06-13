require_relative "test_helper"

class KeyTest < Minitest::Test
  def test_get_set
    key = random_key
    assert_nil immudb.set(key, "world")
    assert_equal "world", immudb.get(key)
  end

  def test_verified_get_verified_set
    key = random_key
    assert_nil immudb.verified_set(key, "world")
    assert_equal "world", immudb.verified_get(key)
  end

  def test_verified_get_verified_get_multiple_clients
    key = random_key
    assert_nil immudb.verified_set(key, "world")
    assert_nil immudb2.verified_set(key, "world2")
    assert_equal "world2", immudb.verified_get(key)
    assert_equal "world2", immudb2.verified_get(key)
  end

  def test_verified_set_metadata
    skip unless metadata_supported?

    key = random_key
    metadata = Immudb::KVMetadata.new
    metadata.expires_at(Time.now + 5)
    metadata.as_non_indexable(true)
    assert_nil immudb.verified_set(key, "world", metadata: metadata)

    metadata.as_deleted(true)

    assert_raises(Immudb::VerificationError) do
      immudb.verified_set(key, "world", metadata: metadata)
    end
  end

  def test_expiration
    skip unless metadata_supported?

    key = random_key
    metadata = Immudb::KVMetadata.new
    metadata.expires_at(Time.now)
    assert_nil immudb.verified_set(key, "world", metadata: metadata)

    error = assert_raises(Immudb::Error) do
      immudb.verified_get(key)
    end
    assert_equal "key not found: expired entry", error.message
  end

  def test_get_all_set_all
    kv = {random_key => "one", random_key => "two"}
    assert_nil immudb.set_all(kv)
    assert_equal kv, immudb.get_all(kv.keys)
  end

  def test_history
    key = random_key
    immudb.set(key, "one")
    immudb.set(key, "two")
    immudb.set(key, "three")
    assert_equal ["one", "two", "three"], immudb.history(key).map { |v| v[:value] }
    assert_equal ["three", "two", "one"], immudb.history(key, desc: true).map { |v| v[:value] }
  end

  def test_scan
    prefix = random_key
    immudb.set("#{prefix}1", "one")
    immudb.set("#{prefix}2", "two")
    assert_equal ["#{prefix}1", "#{prefix}2"], immudb.scan(prefix: prefix).map { |v| v[:key] }
    assert_equal ["#{prefix}2", "#{prefix}1"], immudb.scan(prefix: prefix, desc: true).map { |v| v[:key] }
  end

  private

  def metadata_supported?
    immudb.version.to_f >= 1.2
  end
end
