# frozen_string_literal: true

require_relative "rospatent/version"
require_relative "rospatent/configuration"
require_relative "rospatent/input_validator"
require_relative "rospatent/cache"
require_relative "rospatent/logger"
require_relative "rospatent/patent_parser"
require_relative "rospatent/client"
require_relative "rospatent/search"
require_relative "rospatent/errors"

# Load Rails integration if Rails is available
require_relative "rospatent/railtie" if defined?(Rails)

# Main module for the Rospatent API client
module Rospatent
  class << self
    attr_writer :configuration

    # Returns the current configuration
    # @return [Rospatent::Configuration] Current configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure the gem
    # @yield [config] Configuration block
    # @yieldparam [Rospatent::Configuration] config The configuration object
    def configure
      yield(configuration)
    end

    # Creates a new client instance
    # @param token [String] API token (optional if already set in configuration)
    # @param logger [Rospatent::Logger] Custom logger instance (optional)
    # @param cache [Rospatent::Cache] Custom cache instance (optional)
    # @param options [Hash] Additional client options
    # @return [Rospatent::Client] A new client instance
    def client(token = nil, logger: nil, cache: nil, **)
      Client.new(token: token, logger: logger, cache: cache, **)
    end

    # Create a shared cache instance
    # @param ttl [Integer] Time to live in seconds
    # @param max_size [Integer] Maximum cache size
    # @return [Rospatent::Cache] Shared cache instance
    def shared_cache(ttl: nil, max_size: nil)
      @shared_cache ||= Cache.new(
        ttl: ttl || configuration.cache_ttl,
        max_size: max_size || configuration.cache_max_size
      )
    end

    # Create a shared logger instance
    # @param level [Symbol] Log level
    # @param formatter [Symbol] Log formatter (:json or :text)
    # @return [Rospatent::Logger] Shared logger instance
    def shared_logger(level: nil, formatter: nil)
      @shared_logger ||= Logger.new(
        level: level || configuration.log_level,
        formatter: formatter || (configuration.environment == "production" ? :json : :text)
      )
    end

    # Reset the configuration to defaults
    def reset
      @configuration = Configuration.new
      @shared_cache = nil
      @shared_logger = nil
    end

    # Clear all shared resources
    def clear_shared_resources
      @shared_cache&.clear
      @shared_cache = nil
      @shared_logger = nil
    end

    # Get global statistics (if shared cache is being used)
    # @return [Hash] Global usage statistics
    def statistics
      cache_stats = @shared_cache&.statistics || { size: 0, hits: 0, misses: 0 }

      {
        configuration: {
          environment: configuration.environment,
          cache_enabled: configuration.cache_enabled,
          api_url: configuration.effective_api_url
        },
        cache: cache_stats,
        shared_resources: {
          cache_initialized: !@shared_cache.nil?,
          logger_initialized: !@shared_logger.nil?
        }
      }
    end

    # Validate the current configuration
    # @return [Array<String>] Array of validation errors (empty if valid)
    def validate_configuration
      errors = []

      unless configuration.valid_environment?
        errors << "Invalid environment: #{configuration.environment}"
      end

      errors << "API token is required" if configuration.token.nil? || configuration.token.empty?

      errors << "Timeout must be positive" if configuration.timeout <= 0

      errors << "Retry count cannot be negative" if configuration.retry_count.negative?

      errors
    end
  end
end
