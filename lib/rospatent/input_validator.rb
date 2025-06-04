# frozen_string_literal: true

require "date"

module Rospatent
  # Module for validating input parameters and converting types
  module InputValidator
    # Validate and normalize date input
    # @param date [String, Date, nil] Date input to validate
    # @param field_name [String] Name of the field for error messages
    # @return [Date] Normalized Date object
    # @raise [ValidationError] If date format is invalid
    def validate_date(date, field_name = "date")
      return nil if date.nil?
      return date if date.is_a?(Date)

      if date.is_a?(String)
        begin
          return Date.parse(date)
        rescue Date::Error
          raise Errors::ValidationError,
                "Invalid #{field_name} format. Expected YYYY-MM-DD or Date object"
        end
      end

      raise Errors::ValidationError,
            "Invalid #{field_name} type. Expected String or Date, got #{date.class}"
    end

    # Validate and normalize required date input (does not allow nil)
    # @param date [String, Date] Date input to validate
    # @param field_name [String] Name of the field for error messages
    # @return [Date] Normalized Date object
    # @raise [ValidationError] If date format is invalid or nil
    def validate_required_date(date, field_name = "date")
      raise Errors::ValidationError, "#{field_name.capitalize} is required" if date.nil?

      validate_date(date, field_name)
    end

    # Validate positive integer
    # @param value [Integer, String, nil] Value to validate
    # @param field_name [String] Name of the field for error messages
    # @param min_value [Integer] Minimum allowed value
    # @param max_value [Integer, nil] Maximum allowed value (optional)
    # @return [Integer] Validated integer
    # @raise [ValidationError] If value is invalid
    def validate_positive_integer(value, field_name, min_value: 1, max_value: nil)
      return nil if value.nil?

      # Convert string to integer if possible
      if value.is_a?(String)
        begin
          value = Integer(value)
        rescue ArgumentError
          raise Errors::ValidationError,
                "Invalid #{field_name}. Expected integer, got non-numeric string"
        end
      end

      unless value.is_a?(Integer)
        raise Errors::ValidationError,
              "Invalid #{field_name} type. Expected Integer, got #{value.class}"
      end

      if value < min_value
        raise Errors::ValidationError,
              "#{field_name.capitalize} must be at least #{min_value}"
      end

      if max_value && value > max_value
        raise Errors::ValidationError,
              "#{field_name.capitalize} must be at most #{max_value}"
      end

      value
    end

    # Validate non-empty string
    # @param value [String, nil] String to validate
    # @param field_name [String] Name of the field for error messages
    # @param max_length [Integer, nil] Maximum allowed length
    # @return [String] Validated string
    # @raise [ValidationError] If string is invalid
    def validate_string(value, field_name, max_length: nil)
      return nil if value.nil?

      unless value.is_a?(String)
        raise Errors::ValidationError,
              "Invalid #{field_name} type. Expected String, got #{value.class}"
      end

      raise Errors::ValidationError, "#{field_name.capitalize} cannot be empty" if value.empty?

      if max_length && value.length > max_length
        raise Errors::ValidationError,
              "#{field_name.capitalize} cannot exceed #{max_length} characters"
      end

      value.strip
    end

    # Validate text with word count requirements
    # @param value [String, nil] Text to validate
    # @param field_name [String] Name of the field for error messages
    # @param min_words [Integer] Minimum required word count
    # @param max_length [Integer, nil] Maximum allowed character length
    # @return [String] Validated text
    # @raise [ValidationError] If text is invalid or has insufficient words
    def validate_text_with_word_count(value, field_name, min_words:, max_length: nil)
      # First, apply standard string validation
      validated_text = validate_string(value, field_name, max_length: max_length)
      return nil if validated_text.nil?

      # Count words by splitting on whitespace
      word_count = count_words(validated_text)

      if word_count < min_words
        raise Errors::ValidationError,
              "#{field_name.capitalize} must contain at least #{min_words} words (currently has #{word_count})"
      end

      validated_text
    end

    # Validate required non-empty string (does not allow nil)
    # @param value [String, nil] String to validate
    # @param field_name [String] Name of the field for error messages
    # @param max_length [Integer, nil] Maximum allowed length
    # @return [String] Validated string
    # @raise [ValidationError] If string is invalid or nil
    def validate_required_string(value, field_name, max_length: nil)
      raise Errors::ValidationError, "#{field_name.capitalize} is required" if value.nil?

      unless value.is_a?(String)
        raise Errors::ValidationError,
              "Invalid #{field_name} type. Expected String, got #{value.class}"
      end

      raise Errors::ValidationError, "#{field_name.capitalize} cannot be empty" if value.empty?

      if max_length && value.length > max_length
        raise Errors::ValidationError,
              "#{field_name.capitalize} cannot exceed #{max_length} characters"
      end

      value.strip
    end

    # Validate enum value
    # @param value [Symbol, String, nil] Value to validate
    # @param allowed_values [Array] Array of allowed values
    # @param field_name [String] Name of the field for error messages
    # @return [Symbol] Validated symbol
    # @raise [ValidationError] If value is not in allowed list
    def validate_enum(value, allowed_values, field_name)
      return nil if value.nil?

      # Convert to symbol for consistency
      value = value.to_sym if value.respond_to?(:to_sym)

      # Convert allowed values to symbols for comparison
      allowed_symbols = allowed_values.map(&:to_sym)

      unless allowed_symbols.include?(value)
        raise Errors::ValidationError,
              "Invalid #{field_name}. Allowed values: #{allowed_values.join(', ')}"
      end

      value
    end

    # Validate array parameter
    # @param value [Array, nil] Array to validate
    # @param field_name [String] Name of the field for error messages
    # @param max_size [Integer, nil] Maximum array size
    # @param element_validator [Proc, nil] Proc to validate each element
    # @return [Array] Validated array
    # @raise [ValidationError] If array is invalid
    def validate_array(value, field_name, max_size: nil, element_validator: nil)
      return nil if value.nil?

      unless value.is_a?(Array)
        raise Errors::ValidationError,
              "Invalid #{field_name} type. Expected Array, got #{value.class}"
      end

      raise Errors::ValidationError, "#{field_name.capitalize} cannot be empty" if value.empty?

      if max_size && value.size > max_size
        raise Errors::ValidationError,
              "#{field_name.capitalize} cannot contain more than #{max_size} items"
      end

      if element_validator
        value.each_with_index do |element, index|
          element_validator.call(element)
        rescue Errors::ValidationError => e
          raise Errors::ValidationError,
                "Invalid #{field_name}[#{index}]: #{e.message}"
        rescue StandardError => e
          raise Errors::ValidationError,
                "Invalid #{field_name}[#{index}]: #{e.message}"
        end
      end

      value
    end

    # Validate hash parameter
    # @param value [Hash, nil] Hash to validate
    # @param field_name [String] Name of the field for error messages
    # @param required_keys [Array] Required keys in the hash
    # @param allowed_keys [Array, nil] Allowed keys (if nil, any keys allowed)
    # @return [Hash] Validated hash
    # @raise [ValidationError] If hash is invalid
    def validate_hash(value, field_name, required_keys: [], allowed_keys: nil)
      return nil if value.nil?

      unless value.is_a?(Hash)
        raise Errors::ValidationError,
              "Invalid #{field_name} type. Expected Hash, got #{value.class}"
      end

      # Check required keys
      missing_keys = required_keys.map(&:to_s) - value.keys.map(&:to_s)
      unless missing_keys.empty?
        raise Errors::ValidationError,
              "Missing required #{field_name} keys: #{missing_keys.join(', ')}"
      end

      # Check allowed keys if specified
      if allowed_keys
        invalid_keys = value.keys.map(&:to_s) - allowed_keys.map(&:to_s)
        unless invalid_keys.empty?
          raise Errors::ValidationError,
                "Invalid #{field_name} keys: #{invalid_keys.join(', ')}"
        end
      end

      value
    end

    # Validate patent ID format
    # @param document_id [String] Patent document ID
    # @return [String] Validated document ID
    # @raise [ValidationError] If format is invalid
    def validate_patent_id(document_id)
      raise Errors::ValidationError, "Document_id is required" if document_id.nil?

      value = validate_string(document_id, "document_id")
      return nil if value.nil?

      # Regex pattern for patent IDs
      # Format: {country code (2 letters)}{publication number (alphanumeric)}{document type (letter+digits)}_{date (YYYYMMDD)}
      pattern = /^[A-Z]{2}[A-Z0-9]+[A-Z]\d*_\d{8}$/

      unless value.match?(pattern)
        raise Errors::ValidationError,
              "Invalid patent ID format. Expected format: 'XX12345Y1_YYYYMMDD' (country code + alphanumeric publication number + document type + date)"
      end

      value
    end

    # Validate multiple parameters at once
    # @param params [Hash] Parameters to validate
    # @param validations [Hash] Validation rules for each parameter
    # @return [Hash] Hash of validated parameters
    # @raise [ValidationError] If any validation fails
    # @example
    #   validate_params(
    #     { limit: "10", offset: "0" },
    #     {
    #       limit: { type: :positive_integer, max_value: 100 },
    #       offset: { type: :positive_integer, min_value: 0 }
    #     }
    #   )
    def validate_params(params, validations)
      validated = {}
      errors = {}

      validations.each do |param_name, rules|
        value = params[param_name]
        validated[param_name] = case rules[:type]
                                when :positive_integer
                                  validate_positive_integer(
                                    value,
                                    param_name.to_s,
                                    min_value: rules[:min_value] || 1,
                                    max_value: rules[:max_value]
                                  )
                                when :string
                                  validate_string(
                                    value,
                                    param_name.to_s,
                                    max_length: rules[:max_length]
                                  )
                                when :enum
                                  validate_enum(value, rules[:allowed_values], param_name.to_s)
                                when :date
                                  validate_date(value, param_name.to_s)
                                when :array
                                  validate_array(
                                    value,
                                    param_name.to_s,
                                    max_size: rules[:max_size],
                                    element_validator: rules[:element_validator]
                                  )
                                when :hash
                                  validate_hash(
                                    value,
                                    param_name.to_s,
                                    required_keys: rules[:required_keys] || [],
                                    allowed_keys: rules[:allowed_keys]
                                  )
                                else
                                  value
                                end
      rescue Errors::ValidationError => e
        errors[param_name] = e.message
      end

      raise Errors::ValidationError.new("Validation failed", errors) unless errors.empty?

      validated.compact
    end

    private

    # Count words in a text by splitting on whitespace
    # @param text [String] Text to count words in
    # @return [Integer] Number of words
    def count_words(text)
      text.split.size
    end
  end
end
