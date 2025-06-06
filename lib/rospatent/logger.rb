# frozen_string_literal: true

require "logger"
require "json"
require "time"

module Rospatent
  # Structured logger for API requests, responses, and events
  class Logger
    LEVELS = {
      debug: ::Logger::DEBUG,
      info: ::Logger::INFO,
      warn: ::Logger::WARN,
      error: ::Logger::ERROR,
      fatal: ::Logger::FATAL
    }.freeze

    attr_reader :logger, :level

    # Initialize a new logger
    # @param output [IO, String, Logger] Output destination (STDOUT, file path, existing logger, etc.)
    # @param level [Symbol] Log level (:debug, :info, :warn, :error, :fatal)
    # @param formatter [Symbol] Log format (:json, :text)
    def initialize(output: $stdout, level: :info, formatter: :text)
      @level = level

      # Handle different types of output
      @logger = if output.respond_to?(:debug) && output.respond_to?(:info) && output.respond_to?(:error)
                  # If it's already a logger instance (like Rails.logger), use it directly
                  output
                else
                  # If it's an IO object or file path, create a new Logger
                  new_logger = ::Logger.new(output)
                  new_logger.formatter = case formatter
                                         when :json
                                           method(:json_formatter)
                                         else
                                           method(:text_formatter)
                                         end
                  new_logger
                end

      # Set the log level
      @logger.level = LEVELS[level] || ::Logger::INFO
    end

    # Log an API request
    # @param method [String] HTTP method
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request parameters
    # @param headers [Hash] Request headers (optional)
    def log_request(method, endpoint, params = {}, headers = {})
      return unless should_log?(:info)

      safe_params = sanitize_params(params)
      safe_headers = sanitize_headers(headers)

      log_structured(:info, "API Request", {
                       http_method: method.upcase,
                       endpoint: endpoint,
                       params: safe_params,
                       headers: safe_headers,
                       timestamp: Time.now.iso8601,
                       request_id: generate_request_id
                     })
    end

    # Log an API response
    # @param method [String] HTTP method
    # @param endpoint [String] API endpoint
    # @param status [Integer] Response status code
    # @param duration [Float] Request duration in seconds
    # @param response_size [Integer] Response body size (optional)
    # @param request_id [String] Request ID for correlation
    def log_response(method, endpoint, status, duration, response_size: nil, request_id: nil)
      return unless should_log?(:info)

      level = status >= 400 ? :warn : :info

      log_structured(level, "API Response", {
                       http_method: method.upcase,
                       endpoint: endpoint,
                       status_code: status,
                       duration_ms: (duration * 1000).round(2),
                       response_size_bytes: response_size,
                       timestamp: Time.now.iso8601,
                       request_id: request_id
                     })
    end

    # Log an error with context
    # @param error [Exception] The error object
    # @param context [Hash] Additional context information
    def log_error(error, context = {})
      log_structured(:error, "Error occurred", {
                       error_class: error.class.name,
                       error_message: error.message,
                       error_backtrace: error.backtrace&.first(10),
                       context: context,
                       timestamp: Time.now.iso8601
                     })
    end

    # Log cache operations
    # @param operation [String] Cache operation (hit, miss, set, delete)
    # @param key [String] Cache key
    # @param ttl [Integer] Time to live (for set operations)
    def log_cache(operation, key, ttl: nil)
      return unless should_log?(:debug)

      log_structured(:debug, "Cache operation", {
                       operation: operation,
                       cache_key: key,
                       ttl_seconds: ttl,
                       timestamp: Time.now.iso8601
                     })
    end

    # Log performance metrics
    # @param operation [String] Operation name
    # @param duration [Float] Duration in seconds
    # @param metadata [Hash] Additional metadata
    def log_performance(operation, duration, metadata = {})
      return unless should_log?(:info)

      log_structured(:info, "Performance metric", {
                       operation: operation,
                       duration_ms: (duration * 1000).round(2),
                       metadata: metadata,
                       timestamp: Time.now.iso8601
                     })
    end

    # Log debug information
    # @param message [String] Debug message
    # @param data [Hash] Additional debug data
    def debug(message, data = {})
      log_structured(:debug, message, data)
    end

    # Log info message
    # @param message [String] Info message
    # @param data [Hash] Additional data
    def info(message, data = {})
      log_structured(:info, message, data)
    end

    # Log warning
    # @param message [String] Warning message
    # @param data [Hash] Additional data
    def warn(message, data = {})
      log_structured(:warn, message, data)
    end

    # Log error message
    # @param message [String] Error message
    # @param data [Hash] Additional data
    def error(message, data = {})
      log_structured(:error, message, data)
    end

    # Log fatal error
    # @param message [String] Fatal error message
    # @param data [Hash] Additional data
    def fatal(message, data = {})
      log_structured(:fatal, message, data)
    end

    private

    # Check if we should log at the given level
    # @param level [Symbol] Log level to check
    # @return [Boolean] true if should log
    def should_log?(level)
      LEVELS[level] >= @logger.level
    end

    # Log structured data
    # @param level [Symbol] Log level
    # @param message [String] Log message
    # @param data [Hash] Structured data
    def log_structured(level, message, data = {})
      return unless should_log?(level)

      log_data = {
        message: message,
        level: level.to_s.upcase,
        gem: "rospatent",
        version: Rospatent::VERSION
      }.merge(data)

      @logger.send(level, log_data)
    end

    # Sanitize request parameters to remove sensitive data
    # @param params [Hash] Request parameters
    # @return [Hash] Sanitized parameters
    def sanitize_params(params)
      return {} unless params.is_a?(Hash)

      sanitized = params.dup
      sensitive_keys = %w[token password secret key auth authorization]

      sensitive_keys.each do |key|
        sanitized.each do |param_key, _value|
          sanitized[param_key] = "[REDACTED]" if param_key.to_s.downcase.include?(key.downcase)
        end
      end

      sanitized
    end

    # Sanitize headers to remove sensitive data
    # @param headers [Hash] Request headers
    # @return [Hash] Sanitized headers
    def sanitize_headers(headers)
      return {} unless headers.is_a?(Hash)

      sanitized = headers.dup
      sensitive_headers = %w[authorization x-api-key x-auth-token bearer]

      sensitive_headers.each do |header|
        sanitized.each do |header_key, _value|
          sanitized[header_key] = "[REDACTED]" if header_key.to_s.downcase.include?(header.downcase)
        end
      end

      sanitized
    end

    # Generate a unique request ID
    # @return [String] Unique request identifier
    def generate_request_id
      "req_#{Time.now.to_f}_#{rand(10_000)}"
    end

    # JSON formatter for structured logging
    # @param severity [String] Log severity
    # @param datetime [Time] Log timestamp
    # @param progname [String] Program name
    # @param msg [Object] Log message/data
    # @return [String] Formatted log entry
    def json_formatter(severity, datetime, progname, msg)
      log_entry = if msg.is_a?(Hash)
                    msg.merge(
                      severity: severity,
                      datetime: datetime.iso8601,
                      progname: progname
                    )
                  else
                    {
                      severity: severity,
                      datetime: datetime.iso8601,
                      progname: progname,
                      message: msg.to_s
                    }
                  end

      "#{JSON.generate(log_entry)}\n"
    end

    # Text formatter for human-readable logging
    # @param severity [String] Log severity
    # @param datetime [Time] Log timestamp
    # @param progname [String] Program name
    # @param msg [Object] Log message/data
    # @return [String] Formatted log entry
    def text_formatter(severity, datetime, progname, msg)
      timestamp = datetime.strftime("%Y-%m-%d %H:%M:%S")

      if msg.is_a?(Hash)
        message = msg[:message] || "Structured log"
        details = msg.except(:message).map { |k, v| "#{k}=#{v}" }.join(" ")
        formatted_msg = details.empty? ? message : "#{message} (#{details})"
      else
        formatted_msg = msg.to_s
      end

      "[#{timestamp}] #{severity} -- #{progname}: #{formatted_msg}\n"
    end
  end

  # Null logger implementation for when logging is disabled
  class NullLogger
    def log_request(*args); end
    def log_response(*args); end
    def log_error(*args); end
    def log_cache(*args); end
    def log_performance(*args); end
    def debug(*args); end
    def info(*args); end
    def warn(*args); end
    def error(*args); end
    def fatal(*args); end
  end
end
