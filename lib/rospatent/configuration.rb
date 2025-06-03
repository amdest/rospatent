# frozen_string_literal: true

require "time"

module Rospatent
  # Configuration class for Rospatent API client
  class Configuration
    ENVIRONMENTS = %w[development staging production].freeze

    # Base URL for the Rospatent API
    attr_accessor :api_url
    # JWT token for authentication
    attr_accessor :token
    # Request timeout in seconds
    attr_accessor :timeout
    # Number of retries for failed requests
    attr_accessor :retry_count
    # User agent to be sent with requests
    attr_accessor :user_agent
    # Current environment
    attr_accessor :environment
    # Cache configuration
    attr_accessor :cache_enabled, :cache_ttl, :cache_max_size
    # Logging configuration
    attr_accessor :log_level, :log_requests, :log_responses
    # Token management
    attr_accessor :token_expires_at, :token_refresh_callback
    # Connection pooling
    attr_accessor :connection_pool_size, :connection_keep_alive

    # Initialize a new configuration with default values
    def initialize
      @api_url = "https://searchplatform.rospatent.gov.ru"
      @token = nil
      @timeout = 30
      @retry_count = 3
      @user_agent = "Rospatent Ruby Client/#{Rospatent::VERSION}"

      # Environment configuration
      @environment = ENV.fetch("ROSPATENT_ENV", "development")

      # Cache configuration
      @cache_enabled = ENV.fetch("ROSPATENT_CACHE_ENABLED", "true") == "true"
      @cache_ttl = ENV.fetch("ROSPATENT_CACHE_TTL", "300").to_i
      @cache_max_size = ENV.fetch("ROSPATENT_CACHE_MAX_SIZE", "1000").to_i

      # Logging configuration
      @log_level = ENV.fetch("ROSPATENT_LOG_LEVEL", "info").to_sym
      @log_requests = ENV.fetch("ROSPATENT_LOG_REQUESTS", "false") == "true"
      @log_responses = ENV.fetch("ROSPATENT_LOG_RESPONSES", "false") == "true"

      # Token management
      @token_expires_at = nil
      @token_refresh_callback = nil

      # Connection pooling
      @connection_pool_size = ENV.fetch("ROSPATENT_POOL_SIZE", "5").to_i
      @connection_keep_alive = ENV.fetch("ROSPATENT_KEEP_ALIVE", "true") == "true"

      load_environment_config
    end

    # Check if the current token is still valid
    # @return [Boolean] true if token is valid or no expiration is set
    def token_valid?
      return true unless @token_expires_at

      Time.now < @token_expires_at
    end

    # Validate the current environment
    # @return [Boolean] true if environment is valid
    def valid_environment?
      ENVIRONMENTS.include?(@environment)
    end

    # Get environment-specific API URL if needed
    # @return [String] API URL for current environment
    def effective_api_url
      case @environment
      when "development"
        ENV.fetch("ROSPATENT_DEV_API_URL", @api_url)
      when "staging"
        ENV.fetch("ROSPATENT_STAGING_API_URL", @api_url)
      when "production"
        @api_url
      else
        @api_url
      end
    end

    # Reset configuration to defaults
    def reset!
      initialize
    end

    # Configure from hash
    # @param options [Hash] Configuration options
    def configure_from_hash(options)
      options.each do |key, value|
        setter = "#{key}="
        send(setter, value) if respond_to?(setter)
      end
    end

    private

    # Load environment-specific configuration
    def load_environment_config
      unless valid_environment?
        raise ArgumentError, "Invalid environment: #{@environment}. " \
                             "Allowed: #{ENVIRONMENTS.join(', ')}"
      end

      case @environment
      when "production"
        @timeout = 60
        @retry_count = 5
        @log_level = :warn
        @cache_ttl = 600 # 10 minutes in production
      when "staging"
        @timeout = 45
        @retry_count = 3
        @log_level = :info
        @cache_ttl = 300 # 5 minutes in staging
      when "development"
        @timeout = 10
        @retry_count = 1
        @log_level = :debug
        @log_requests = true
        @log_responses = true
        @cache_ttl = 60 # 1 minute in development
      end
    end
  end
end
