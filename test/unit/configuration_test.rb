# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def test_default_values
    # Arrange
    config = Rospatent::Configuration.new

    # Assert
    assert_equal "https://searchplatform.rospatent.gov.ru", config.api_url,
                 "Default API URL should be set to Rospatent API endpoint"
    assert_nil config.token, "Default token should be nil"
    assert_equal 10, config.timeout, "Default timeout should be 10 seconds in development"
    assert_equal 1, config.retry_count, "Default retry count should be 1 in development"
    assert_equal "Rospatent Ruby Client/#{Rospatent::VERSION}", config.user_agent,
                 "Default user agent should include gem version"
  end

  def test_global_configure
    # Arrange
    custom_url = "https://test-api.example.com"
    custom_token = "test_jwt_token"
    custom_timeout = 60
    custom_retry_count = 5
    custom_user_agent = "TestApp/1.0"

    # Act
    Rospatent.configure do |config|
      config.api_url = custom_url
      config.token = custom_token
      config.timeout = custom_timeout
      config.retry_count = custom_retry_count
      config.user_agent = custom_user_agent
    end

    # Assert
    config = Rospatent.configuration
    assert_equal custom_url, config.api_url, "API URL should be customizable"
    assert_equal custom_token, config.token, "Token should be customizable"
    assert_equal custom_timeout, config.timeout, "Timeout should be customizable"
    assert_equal custom_retry_count, config.retry_count, "Retry count should be customizable"
    assert_equal custom_user_agent, config.user_agent, "User agent should be customizable"
  end

  def test_reset_configuration
    # Arrange
    Rospatent.configure do |config|
      config.api_url = "https://test-api.example.com"
    end

    # Act
    Rospatent.reset

    # Assert
    config = Rospatent.configuration
    assert_equal "https://searchplatform.rospatent.gov.ru", config.api_url,
                 "Reset should restore default API URL"
  end
end
