# frozen_string_literal: true

require_relative "../test_helper"

class CacheTest < Minitest::Test
  def setup
    @cache = Rospatent::Cache.new(ttl: 60, max_size: 5)
    @null_cache = Rospatent::NullCache.new
  end

  def test_initialization_with_defaults
    cache = Rospatent::Cache.new
    assert_equal 300, cache.instance_variable_get(:@ttl)
    assert_equal 1000, cache.instance_variable_get(:@max_size)
    assert_empty cache.instance_variable_get(:@store)
  end

  def test_initialization_with_custom_values
    cache = Rospatent::Cache.new(ttl: 120, max_size: 10)
    assert_equal 120, cache.instance_variable_get(:@ttl)
    assert_equal 10, cache.instance_variable_get(:@max_size)
  end

  def test_set_and_get_value
    @cache.set("key1", "value1")
    assert_equal "value1", @cache.get("key1")
  end

  def test_get_nonexistent_key
    assert_nil @cache.get("nonexistent")
  end

  def test_key_existence_check
    @cache.set("key1", "value1")
    assert @cache.key?("key1")
    refute @cache.key?("nonexistent")
  end

  def test_delete_existing_key
    @cache.set("key1", "value1")
    result = @cache.delete("key1")
    assert_equal "value1", result
    refute @cache.key?("key1")
  end

  def test_delete_nonexistent_key
    result = @cache.delete("nonexistent")
    assert_nil result
  end

  def test_cache_size
    assert_equal 0, @cache.size
    @cache.set("key1", "value1")
    assert_equal 1, @cache.size
    @cache.set("key2", "value2")
    assert_equal 2, @cache.size
  end

  def test_cache_empty
    assert @cache.empty?
    @cache.set("key1", "value1")
    refute @cache.empty?
  end

  def test_clear_cache
    @cache.set("key1", "value1")
    @cache.set("key2", "value2")
    @cache.clear
    assert_equal 0, @cache.size
    assert @cache.empty?
  end

  def test_ttl_expiration
    short_ttl_cache = Rospatent::Cache.new(ttl: 1, max_size: 5)
    short_ttl_cache.set("key1", "value1")

    # Should exist immediately
    assert_equal "value1", short_ttl_cache.get("key1")

    # Wait for expiration
    sleep(1.1)

    # Should be nil after expiration
    assert_nil short_ttl_cache.get("key1")
    refute short_ttl_cache.key?("key1")
  end

  def test_custom_ttl_for_entry
    @cache.set("key1", "value1", ttl: 1)
    assert_equal "value1", @cache.get("key1")

    sleep(1.1)
    assert_nil @cache.get("key1")
  end

  def test_size_limit_eviction
    # Set max_size to 3 for easier testing
    small_cache = Rospatent::Cache.new(ttl: 60, max_size: 3)

    # Fill the cache to capacity
    small_cache.set("key1", "value1")
    small_cache.set("key2", "value2")
    small_cache.set("key3", "value3")
    assert_equal 3, small_cache.size

    # Adding one more should evict the least recently used
    small_cache.set("key4", "value4")
    assert_equal 3, small_cache.size

    # key1 should be evicted (least recently used)
    assert_nil small_cache.get("key1")
    assert_equal "value4", small_cache.get("key4")
  end

  def test_lru_access_order_update
    small_cache = Rospatent::Cache.new(ttl: 60, max_size: 3)

    small_cache.set("key1", "value1")
    small_cache.set("key2", "value2")
    small_cache.set("key3", "value3")

    # Access key1 to make it recently used
    small_cache.get("key1")

    # Add new key, key2 should be evicted (now least recently used)
    small_cache.set("key4", "value4")

    assert_equal "value1", small_cache.get("key1")  # Still there
    assert_nil small_cache.get("key2")              # Evicted
    assert_equal "value3", small_cache.get("key3")  # Still there
    assert_equal "value4", small_cache.get("key4")  # New entry
  end

  def test_statistics_tracking
    stats = @cache.statistics
    assert_equal 0, stats[:hits]
    assert_equal 0, stats[:misses]
    assert_equal 0, stats[:evictions]
    assert_equal 0, stats[:expired]
    assert_equal 0, stats[:size]
    assert_equal 0, stats[:total_requests]
    assert_equal 0, stats[:hit_rate_percent]

    # Test hit
    @cache.set("key1", "value1")
    @cache.get("key1")
    stats = @cache.statistics
    assert_equal 1, stats[:hits]
    assert_equal 0, stats[:misses]

    # Test miss
    @cache.get("nonexistent")
    stats = @cache.statistics
    assert_equal 1, stats[:hits]
    assert_equal 1, stats[:misses]
    assert_equal 50.0, stats[:hit_rate_percent]
  end

  def test_cleanup_expired_entries
    short_ttl_cache = Rospatent::Cache.new(ttl: 1, max_size: 5)
    short_ttl_cache.set("key1", "value1")
    short_ttl_cache.set("key2", "value2")

    # Wait for expiration
    sleep(1.1)

    # Cleanup should remove expired entries
    removed_count = short_ttl_cache.cleanup_expired
    assert_equal 2, removed_count
    assert_equal 0, short_ttl_cache.size
  end

  def test_fetch_with_block_cache_hit
    @cache.set("key1", "cached_value")

    result = @cache.fetch("key1", "block_value")
    assert_equal "cached_value", result
  end

  def test_fetch_with_block_cache_miss
    result = @cache.fetch("key1", "block_value")
    assert_equal "block_value", result

    # Should now be cached
    assert_equal "block_value", @cache.get("key1")
  end

  def test_fetch_without_block_cache_miss
    result = @cache.fetch("nonexistent")
    assert_nil result
  end

  def test_fetch_with_nil_block_result
    result = @cache.fetch("key1", nil)
    assert_nil result

    # Should not cache nil values
    refute @cache.key?("key1")
  end

  def test_fetch_with_custom_ttl
    result = @cache.fetch("key1", ttl: 1) { "value1" }
    assert_equal "value1", result

    sleep(1.1)
    assert_nil @cache.get("key1")
  end

  def test_cache_entry_access_count
    @cache.set("key1", "value1")

    # Access multiple times
    @cache.get("key1")
    @cache.get("key1")
    @cache.get("key1")

    entry = @cache.instance_variable_get(:@store)["key1"]
    assert_equal 3, entry.access_count
  end

  def test_cache_entry_expired_check
    entry = Rospatent::Cache::CacheEntry.new("value", Time.now - 10, Time.now, 0)
    assert entry.expired?

    entry = Rospatent::Cache::CacheEntry.new("value", Time.now + 10, Time.now, 0)
    refute entry.expired?
  end

  def test_cache_entry_touch
    entry = Rospatent::Cache::CacheEntry.new("value", Time.now + 10, Time.now, 0)
    assert_equal 0, entry.access_count

    entry.touch!
    assert_equal 1, entry.access_count
  end

  def test_expired_entry_removal_on_get
    short_ttl_cache = Rospatent::Cache.new(ttl: 1, max_size: 5)
    short_ttl_cache.set("key1", "value1")

    sleep(1.1)

    # Getting expired key should remove it and update stats
    result = short_ttl_cache.get("key1")
    assert_nil result
    assert_equal 0, short_ttl_cache.size

    stats = short_ttl_cache.statistics
    assert_equal 1, stats[:expired]
    assert_equal 1, stats[:misses]
  end

  def test_expired_entry_removal_on_key_check
    short_ttl_cache = Rospatent::Cache.new(ttl: 1, max_size: 5)
    short_ttl_cache.set("key1", "value1")

    sleep(1.1)

    # Checking expired key should remove it
    result = short_ttl_cache.key?("key1")
    refute result
    assert_equal 0, short_ttl_cache.size
  end

  def test_overwriting_existing_key
    @cache.set("key1", "value1")
    @cache.set("key1", "value2")

    assert_equal "value2", @cache.get("key1")
    assert_equal 1, @cache.size # Should not increase size
  end

  # NullCache tests
  def test_null_cache_get_always_returns_nil
    assert_nil @null_cache.get("any_key")
  end

  def test_null_cache_set_returns_value
    result = @null_cache.set("key", "value")
    assert_equal "value", result
  end

  def test_null_cache_key_always_returns_false
    @null_cache.set("key", "value")
    refute @null_cache.key?("key")
  end

  def test_null_cache_delete_returns_nil
    assert_nil @null_cache.delete("any_key")
  end

  def test_null_cache_clear_no_op
    @null_cache.clear # Should not raise error
  end

  def test_null_cache_size_always_zero
    @null_cache.set("key", "value")
    assert_equal 0, @null_cache.size
  end

  def test_null_cache_always_empty
    @null_cache.set("key", "value")
    assert @null_cache.empty?
  end

  def test_null_cache_statistics_all_zeros
    stats = @null_cache.statistics
    assert_equal 0, stats[:hits]
    assert_equal 0, stats[:misses]
    assert_equal 0, stats[:evictions]
    assert_equal 0, stats[:expired]
    assert_equal 0, stats[:size]
    assert_equal 0, stats[:total_requests]
    assert_equal 0, stats[:hit_rate_percent]
  end

  def test_null_cache_cleanup_expired_returns_zero
    assert_equal 0, @null_cache.cleanup_expired
  end

  def test_null_cache_fetch_calls_block
    result = @null_cache.fetch("key", "block_value")
    assert_equal "block_value", result
  end

  def test_null_cache_fetch_without_block_returns_nil
    result = @null_cache.fetch("key")
    assert_nil result
  end

  def test_thread_safety
    # Use a larger cache for this test to avoid evictions
    large_cache = Rospatent::Cache.new(ttl: 60, max_size: 20)
    threads = []
    results = {}

    # Create multiple threads that access the cache simultaneously
    10.times do |i|
      threads << Thread.new do
        large_cache.set("key#{i}", "value#{i}")
        results[i] = large_cache.get("key#{i}")
      end
    end

    threads.each(&:join)

    # All threads should have succeeded
    10.times do |i|
      assert_equal "value#{i}", results[i]
    end

    assert_equal 10, large_cache.size
  end
end
