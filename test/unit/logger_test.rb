# frozen_string_literal: true

require "test_helper"

class LoggerTest < Minitest::Test
  def test_initialize_with_io_output
    # Arrange
    output = StringIO.new

    # Act
    logger = Rospatent::Logger.new(output: output, level: :info)

    # Assert
    assert logger.logger.is_a?(::Logger), "Should create a new Logger instance for IO output"
    assert_equal ::Logger::INFO, logger.logger.level, "Should set the correct log level"
  end

  def test_initialize_with_existing_logger
    # Arrange - create a more realistic Rails.logger mock
    rails_logger = Class.new do
      attr_accessor :level

      def debug(message = nil)
        yield if block_given?
      end

      def info(message = nil)
        yield if block_given?
      end

      def warn(message = nil)
        yield if block_given?
      end

      def error(message = nil)
        yield if block_given?
      end

      def fatal(message = nil)
        yield if block_given?
      end
    end.new

    # Act
    logger = Rospatent::Logger.new(output: rails_logger, level: :info)

    # Assert
    assert_equal rails_logger, logger.logger, "Should use the existing logger instance directly"
    assert_equal ::Logger::INFO, rails_logger.level, "Should set the log level on the existing logger"
  end

  def test_initialize_with_stdout
    # Arrange & Act
    logger = Rospatent::Logger.new(output: $stdout, level: :debug)

    # Assert
    assert logger.logger.is_a?(::Logger), "Should create a new Logger instance for STDOUT"
    assert_equal ::Logger::DEBUG, logger.logger.level, "Should set the debug log level"
  end

  def test_initialize_with_real_rails_logger_duck_type
    # Arrange - create a simple Rails.logger duck type
    rails_logger_like = Class.new do
      attr_accessor :level

      def debug(message = nil)
        yield if block_given?
      end

      def info(message = nil)
        yield if block_given?
      end

      def warn(message = nil)
        yield if block_given?
      end

      def error(message = nil)
        yield if block_given?
      end

      def fatal(message = nil)
        yield if block_given?
      end
    end.new

    # Act
    logger = Rospatent::Logger.new(output: rails_logger_like, level: :warn)

    # Assert
    assert_equal rails_logger_like, logger.logger, "Should use Rails-like logger directly"
    assert_equal ::Logger::WARN, rails_logger_like.level, "Should set the warn log level"
  end

  def test_log_structured_with_existing_logger
    # Arrange
    output = StringIO.new
    existing_logger = ::Logger.new(output)
    existing_logger.formatter = proc { |severity, datetime, progname, msg| "#{msg}\n" }

    logger = Rospatent::Logger.new(output: existing_logger, level: :info)

    # Act
    logger.info("Test message", { context: "test" })

    # Assert
    output.rewind
    log_content = output.read
    assert_match(/Test message/, log_content, "Should log through existing logger")
  end

  def test_log_levels_mapping
    # Test all log levels are properly mapped
    levels = {
      debug: ::Logger::DEBUG,
      info: ::Logger::INFO,
      warn: ::Logger::WARN,
      error: ::Logger::ERROR,
      fatal: ::Logger::FATAL
    }

    levels.each do |level_symbol, expected_level|
      output = StringIO.new
      logger = Rospatent::Logger.new(output: output, level: level_symbol)

      assert_equal expected_level, logger.logger.level,
                   "Level #{level_symbol} should map to #{expected_level}"
    end
  end

  def test_logger_methods_work_with_rails_logger
    # Arrange - create a logger that captures messages
    logged_messages = []
    rails_logger = Class.new do
      attr_accessor :level

      def initialize(messages_array)
        @messages = messages_array
      end

      def debug(message = nil)
        @messages << [:debug, message]
        yield if block_given?
      end

      def info(message = nil)
        @messages << [:info, message]
        yield if block_given?
      end

      def warn(message = nil)
        @messages << [:warn, message]
        yield if block_given?
      end

      def error(message = nil)
        @messages << [:error, message]
        yield if block_given?
      end

      def fatal(message = nil)
        @messages << [:fatal, message]
        yield if block_given?
      end
    end.new(logged_messages)

    logger = Rospatent::Logger.new(output: rails_logger, level: :info)

    # Act
    logger.info("Test message")

    # Assert
    assert_equal 1, logged_messages.length, "Should have logged one message"
    assert_equal :info, logged_messages.first[0], "Should have logged at info level"
    assert logged_messages.first[1].is_a?(Hash), "Should have logged structured data"
  end
end
