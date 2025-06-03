# frozen_string_literal: true

require "test_helper"

class ErrorsTest < Minitest::Test
  def test_api_error_with_status_code
    # Arrange
    status_code = 401
    message = "Unauthorized access"

    # Act
    error = Rospatent::Errors::ApiError.new(message, status_code)

    # Assert
    assert_equal status_code, error.status_code, "Should store status code"
    assert_equal "API Error (401): Unauthorized access", error.to_s,
                 "Should format error message with status code"
  end

  def test_api_error_without_status_code
    # Arrange & Act
    error = Rospatent::Errors::ApiError.new("Unknown error")

    # Assert
    assert_nil error.status_code, "Should handle nil status code"
    assert_equal "API Error (unknown): Unknown error", error.to_s,
                 "Should format error message even without status code"
  end

  def test_missing_token_error
    # Act & Assert
    error = assert_raises(Rospatent::Errors::MissingTokenError) do
      raise Rospatent::Errors::MissingTokenError, "API token is required"
    end

    assert_equal "API token is required", error.message, "Should pass message correctly"
    assert_kind_of Rospatent::Errors::Error, error, "Should be a subclass of Error"
  end

  def test_connection_error
    # Act & Assert
    error = assert_raises(Rospatent::Errors::ConnectionError) do
      raise Rospatent::Errors::ConnectionError, "Connection failed"
    end

    assert_equal "Connection failed", error.message, "Should pass message correctly"
    assert_kind_of Rospatent::Errors::Error, error, "Should be a subclass of Error"
  end

  def test_invalid_request_error
    # Act & Assert
    error = assert_raises(Rospatent::Errors::InvalidRequestError) do
      raise Rospatent::Errors::InvalidRequestError, "Invalid request parameters"
    end

    assert_equal "Invalid request parameters", error.message, "Should pass message correctly"
    assert_kind_of Rospatent::Errors::Error, error, "Should be a subclass of Error"
  end
end
