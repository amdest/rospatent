# frozen_string_literal: true

require "monitor"

module Rospatent
  # Simple in-memory cache with TTL and size limits
  class Cache
    include MonitorMixin

    # Cache entry with value and expiration time
    CacheEntry = Struct.new(:value, :expires_at, :created_at, :access_count) do
      def expired?
        Time.now > expires_at
      end

      def touch!
        self.access_count += 1
      end
    end

    attr_reader :stats

    # Initialize a new cache
    # @param ttl [Integer] Time to live in seconds
    # @param max_size [Integer] Maximum number of entries
    def initialize(ttl: 300, max_size: 1000)
      super()
      @ttl = ttl
      @max_size = max_size
      @store = {}
      @access_order = []
      @stats = {
        hits: 0,
        misses: 0,
        evictions: 0,
        expired: 0
      }
    end

    # Get a value from the cache
    # @param key [String] Cache key
    # @return [Object, nil] Cached value or nil if not found/expired
    def get(key)
      synchronize do
        entry = @store[key]

        unless entry
          @stats[:misses] += 1
          return nil
        end

        if entry.expired?
          delete_entry(key)
          @stats[:expired] += 1
          @stats[:misses] += 1
          return nil
        end

        # Update access order for LRU
        @access_order.delete(key)
        @access_order.push(key)

        entry.touch!
        @stats[:hits] += 1
        entry.value
      end
    end

    # Set a value in the cache
    # @param key [String] Cache key
    # @param value [Object] Value to cache
    # @param ttl [Integer, nil] Custom TTL for this entry (optional)
    def set(key, value, ttl: nil)
      synchronize do
        effective_ttl = ttl || @ttl
        expires_at = Time.now + effective_ttl

        entry = CacheEntry.new(value, expires_at, Time.now, 0)

        # Remove existing entry if present
        @access_order.delete(key) if @store.key?(key)

        @store[key] = entry
        @access_order.push(key)

        # Evict entries if over size limit
        evict_if_needed

        value
      end
    end

    # Check if a key exists and is not expired
    # @param key [String] Cache key
    # @return [Boolean] true if key exists and is valid
    def key?(key)
      synchronize do
        entry = @store[key]
        return false unless entry

        if entry.expired?
          delete_entry(key)
          @stats[:expired] += 1
          return false
        end

        true
      end
    end

    # Delete a specific key
    # @param key [String] Cache key
    # @return [Object, nil] Deleted value or nil if not found
    def delete(key)
      synchronize do
        entry = @store.delete(key)
        @access_order.delete(key)
        entry&.value
      end
    end

    # Clear all entries from the cache
    def clear
      synchronize do
        @store.clear
        @access_order.clear
        reset_stats
      end
    end

    # Get current cache size
    # @return [Integer] Number of entries in cache
    def size
      synchronize { @store.size }
    end

    # Check if cache is empty
    # @return [Boolean] true if cache has no entries
    def empty?
      synchronize { @store.empty? }
    end

    # Get cache statistics
    # @return [Hash] Statistics including hits, misses, hit rate, etc.
    def statistics
      synchronize do
        total_requests = @stats[:hits] + @stats[:misses]
        hit_rate = total_requests.positive? ? (@stats[:hits].to_f / total_requests * 100).round(2) : 0

        @stats.merge(
          size: @store.size,
          total_requests: total_requests,
          hit_rate_percent: hit_rate
        )
      end
    end

    # Clean up expired entries
    # @return [Integer] Number of expired entries removed
    def cleanup_expired
      synchronize do
        expired_keys = []
        @store.each do |key, entry|
          expired_keys << key if entry.expired?
        end

        expired_keys.each { |key| delete_entry(key) }
        @stats[:expired] += expired_keys.size

        expired_keys.size
      end
    end

    # Fetch value with fallback block or default value
    # @param key [String] Cache key
    # @param default_value [Object, nil] Default value to return if cache miss (optional)
    # @param ttl [Integer, nil] Custom TTL for this entry
    # @yield Block to execute if cache miss
    # @return [Object] Cached value, default value, or result of block
    def fetch(key, default_value = nil, ttl: nil)
      value = get(key)
      return value unless value.nil?

      result = if default_value
                 default_value
               elsif block_given?
                 yield
               else
                 return nil
               end

      set(key, result, ttl: ttl) unless result.nil?
      result
    end

    private

    # Delete an entry and update access order
    # @param key [String] Key to delete
    def delete_entry(key)
      @store.delete(key)
      @access_order.delete(key)
    end

    # Evict least recently used entries if over size limit
    def evict_if_needed
      while @store.size > @max_size
        lru_key = @access_order.shift
        break unless lru_key

        @store.delete(lru_key)
        @stats[:evictions] += 1

      end
    end

    # Reset statistics counters
    def reset_stats
      @stats = {
        hits: 0,
        misses: 0,
        evictions: 0,
        expired: 0
      }
    end
  end

  # Null cache implementation for when caching is disabled
  class NullCache
    def get(_key)
      nil
    end

    def set(_key, value, ttl: nil)
      value
    end

    def key?(_key)
      false
    end

    def delete(_key)
      nil
    end

    def clear
      # no-op
    end

    def size
      0
    end

    def empty?
      true
    end

    def statistics
      {
        hits: 0,
        misses: 0,
        evictions: 0,
        expired: 0,
        size: 0,
        total_requests: 0,
        hit_rate_percent: 0
      }
    end

    def cleanup_expired
      0
    end

    def fetch(_key, default_value = nil, ttl: nil)
      if default_value
        default_value
      elsif block_given?
        yield
      end
    end
  end
end
