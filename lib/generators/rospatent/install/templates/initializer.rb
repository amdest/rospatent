# frozen_string_literal: true

# Rospatent API client configuration
# Documentation: https://online.rospatent.gov.ru/open-data/open-api
Rospatent.configure do |config|
  # JWT Bearer token for API authorization - REQUIRED
  # Priority: Rails credentials > Environment variable > Manual setting
  config.token = Rails.application.credentials.rospatent_token ||
                 ENV["ROSPATENT_TOKEN"] ||
                 ENV.fetch("ROSPATENT_API_TOKEN", nil)

  # Environment configuration - respect environment variables
  config.environment = ENV.fetch("ROSPATENT_ENV", Rails.env)

  # Cache configuration - respect environment variables or use Rails defaults
  config.cache_enabled = if ENV.key?("ROSPATENT_CACHE_ENABLED")
                           ENV["ROSPATENT_CACHE_ENABLED"] == "true"
                         else
                           Rails.env.production?
                         end

  # Logging configuration - CRITICAL: Respect environment variables first!
  config.log_level = if ENV.key?("ROSPATENT_LOG_LEVEL")
                       ENV["ROSPATENT_LOG_LEVEL"].to_sym
                     else
                       Rails.env.production? ? :warn : :debug
                     end

  config.log_requests = if ENV.key?("ROSPATENT_LOG_REQUESTS")
                          ENV["ROSPATENT_LOG_REQUESTS"] == "true"
                        else
                          !Rails.env.production?
                        end

  config.log_responses = if ENV.key?("ROSPATENT_LOG_RESPONSES")
                           ENV["ROSPATENT_LOG_RESPONSES"] == "true"
                         else
                           Rails.env.development?
                         end

  # Optional: Override other defaults if needed
  # config.api_url = ENV.fetch("ROSPATENT_API_URL", "https://searchplatform.rospatent.gov.ru")
  # config.timeout = ENV.fetch("ROSPATENT_TIMEOUT", "30").to_i
  # config.retry_count = ENV.fetch("ROSPATENT_RETRY_COUNT", "3").to_i
  # config.cache_ttl = ENV.fetch("ROSPATENT_CACHE_TTL", "300").to_i
  # config.cache_max_size = ENV.fetch("ROSPATENT_CACHE_MAX_SIZE", "1000").to_i
  # config.connection_pool_size = ENV.fetch("ROSPATENT_POOL_SIZE", "5").to_i
end
