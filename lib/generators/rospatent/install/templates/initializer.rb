# frozen_string_literal: true

# Rospatent API client configuration
# Documentation: https://online.rospatent.gov.ru/open-data/open-api
Rospatent.configure do |config|
  # API URL (default: https://searchplatform.rospatent.gov.ru)
  # config.api_url = ENV.fetch("ROSPATENT_API_URL", "https://searchplatform.rospatent.gov.ru")

  # JWT Bearer token for API authorization - REQUIRED
  # Obtain this from the Rospatent API administration
  config.token = Rails.application.credentials.rospatent_api_token || ENV.fetch(
    "ROSPATENT_API_TOKEN", nil
  )

  # Rails-specific environment integration
  config.environment = Rails.env
  config.cache_enabled = Rails.env.production?
  config.log_level = Rails.env.production? ? :warn : :debug

  # Optional: Override defaults if needed
  # config.timeout = 30
  # config.retry_count = 3
  # config.user_agent = "YourApp/1.0"
end
