# frozen_string_literal: true

module Rospatent
  # Error classes for the Rospatent API client
  module Errors
    # Base error class for all Rospatent API errors
    class Error < StandardError; end

    # Raised when authentication token is missing
    class MissingTokenError < Error; end

    # Raised when authentication fails
    class AuthenticationError < Error; end

    # Raised when the API returns an error response
    class ApiError < Error
      attr_reader :status_code, :response_body, :request_id

      # Initialize a new API error
      # @param message [String] Error message
      # @param status_code [Integer] HTTP status code
      # @param response_body [String] Response body from API
      # @param request_id [String] Request ID for tracking
      def initialize(message, status_code = nil, response_body = nil, request_id = nil)
        @status_code = status_code
        @response_body = response_body
        @request_id = request_id
        super(message)
      end

      # Provide more descriptive error message
      # @return [String] Formatted error message
      def to_s
        msg = "API Error (#{@status_code || 'unknown'}): #{super}"
        msg += " [Request ID: #{@request_id}]" if @request_id
        msg
      end

      # Check if error is retryable based on status code
      # @return [Boolean] true if the error might be temporary
      def retryable?
        return false unless @status_code

        # Retryable status codes: 408, 429, 500, 502, 503, 504
        [408, 429, 500, 502, 503, 504].include?(@status_code)
      end
    end

    # Raised when API rate limit is exceeded
    class RateLimitError < ApiError
      attr_reader :retry_after

      # Initialize a new rate limit error
      # @param message [String] Error message
      # @param status_code [Integer] HTTP status code
      # @param retry_after [Integer] Seconds to wait before retrying
      def initialize(message, status_code = 429, retry_after = nil)
        @retry_after = retry_after
        super(message, status_code)
      end

      def to_s
        msg = super
        msg += " Retry after #{@retry_after} seconds." if @retry_after
        msg
      end
    end

    # Raised when a resource is not found
    class NotFoundError < ApiError
      def initialize(message = "Resource not found", status_code = 404)
        super
      end
    end

    # Raised for connection-related errors
    class ConnectionError < Error
      attr_reader :original_error

      def initialize(message, original_error = nil)
        @original_error = original_error
        super(message)
      end

      def to_s
        msg = super
        msg += " (#{@original_error.class}: #{@original_error.message})" if @original_error
        msg
      end
    end

    # Raised when request times out
    class TimeoutError < ConnectionError; end

    # Raised for malformed request errors
    class InvalidRequestError < Error; end

    # Raised for validation errors with detailed field information
    class ValidationError < InvalidRequestError
      attr_reader :errors

      # Initialize a new validation error
      # @param message [String] Error message
      # @param errors [Hash] Field-specific validation errors
      def initialize(message, errors = {})
        @errors = errors
        super(message)
      end

      def to_s
        msg = super
        if @errors&.any?
          field_errors = @errors.map { |field, error| "#{field}: #{error}" }
          msg += " (#{field_errors.join(', ')})"
        end
        msg
      end
    end

    # Raised when server is temporarily unavailable
    class ServiceUnavailableError < ApiError
      def initialize(message = "Service temporarily unavailable", status_code = 503)
        super
      end
    end
  end
end
