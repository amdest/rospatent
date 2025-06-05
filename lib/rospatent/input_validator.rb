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

    # Validate string enum value (preserves string type)
    # @param value [String, nil] Value to validate
    # @param allowed_values [Array<String>] Array of allowed string values
    # @param field_name [String] Name of the field for error messages
    # @return [String] Validated string
    # @raise [ValidationError] If value is not in allowed list
    def validate_string_enum(value, allowed_values, field_name)
      return nil if value.nil?

      # Ensure value is a string
      value = value.to_s if value.respond_to?(:to_s)

      unless allowed_values.include?(value)
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

    # Validate string or array parameter (for highlight tags)
    # @param value [String, Array, nil] String or Array to validate
    # @param field_name [String] Name of the field for error messages
    # @param max_length [Integer, nil] Maximum string length (for string values)
    # @param max_size [Integer, nil] Maximum array size (for array values)
    # @return [String, Array] Validated string or array
    # @raise [ValidationError] If value is invalid
    def validate_string_or_array(value, field_name, max_length: nil, max_size: nil)
      return nil if value.nil?

      case value
      when String
        validate_string(value, field_name, max_length: max_length)
      when Array
        validate_array(value, field_name, max_size: max_size) do |element|
          validate_string(element, "#{field_name} element", max_length: max_length)
        end
      else
        raise Errors::ValidationError,
              "Invalid #{field_name} type. Expected String or Array, got #{value.class}"
      end
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
                                when :string_or_array
                                  validate_string_or_array(
                                    value,
                                    param_name.to_s,
                                    max_length: rules[:max_length],
                                    max_size: rules[:max_size]
                                  )
                                when :enum
                                  validate_enum(value, rules[:allowed_values], param_name.to_s)
                                when :string_enum
                                  validate_string_enum(value, rules[:allowed_values], param_name.to_s)
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
                                when :filter
                                  validate_filter(value, param_name.to_s)
                                when :boolean
                                  # Convert to boolean, nil values remain nil
                                  value.nil? ? nil : !!value
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

    # Validate filter parameter according to Rospatent API specification
    # @param filter [Hash, nil] Filter hash to validate
    # @param field_name [String] Name of the field for error messages
    # @return [Hash] Validated filter hash
    # @raise [ValidationError] If filter structure is invalid
    def validate_filter(filter, field_name = "filter")
      return nil if filter.nil?

      unless filter.is_a?(Hash)
        raise Errors::ValidationError,
              "Invalid #{field_name} type. Expected Hash, got #{filter.class}"
      end

      validated_filter = {}

      filter.each do |filter_field, filter_value|
        case filter_field.to_s
        when "authors", "patent_holders", "country", "kind", "ids",
             "classification.ipc", "classification.ipc_group", "classification.ipc_subclass",
             "classification.cpc", "classification.cpc_group", "classification.cpc_subclass"
          # These fields use {"values": [...]} format
          validated_filter[filter_field] = validate_filter_values(filter_value, filter_field)
        when "date_published", "application.filing_date"
          # These fields use {"range": {"gt": "20000101"}} format
          validated_filter[filter_field] = validate_filter_range(filter_value, filter_field)
        else
          raise Errors::ValidationError,
                "Invalid filter field '#{filter_field}'. Allowed fields: authors, patent_holders, " \
                "country, kind, ids, date_published, application.filing_date, classification.ipc, " \
                "classification.ipc_group, classification.ipc_subclass, classification.cpc, " \
                "classification.cpc_group, classification.cpc_subclass"
        end
      end

      validated_filter
    end

    # Validate filter values structure (for list-based filters)
    # @param filter_value [Hash] Filter value to validate
    # @param filter_field [String] Filter field name for error messages
    # @return [Hash] Validated filter value
    # @raise [ValidationError] If structure is invalid
    def validate_filter_values(filter_value, filter_field)
      unless filter_value.is_a?(Hash)
        raise Errors::ValidationError,
              "Invalid #{filter_field} filter structure. Expected Hash with 'values' key, got #{filter_value.class}"
      end

      unless filter_value.key?("values") || filter_value.key?(:values)
        raise Errors::ValidationError,
              "Missing required 'values' key in #{filter_field} filter. Expected format: {\"values\": [...]}"
      end

      values = filter_value["values"] || filter_value[:values]

      unless values.is_a?(Array)
        raise Errors::ValidationError,
              "Invalid 'values' type in #{filter_field} filter. Expected Array, got #{values.class}"
      end

      if values.empty?
        raise Errors::ValidationError,
              "Empty 'values' array in #{filter_field} filter. At least one value must be provided"
      end

      # Validate each value is a string
      values.each_with_index do |value, index|
        unless value.is_a?(String) || value.is_a?(Symbol)
          raise Errors::ValidationError,
                "Invalid value type at index #{index} in #{filter_field} filter. Expected String, got #{value.class}"
        end
      end

      { "values" => values.map(&:to_s) }
    end

    # Validate filter range structure (for date-based filters)
    # @param filter_value [Hash] Filter value to validate
    # @param filter_field [String] Filter field name for error messages
    # @return [Hash] Validated filter value
    # @raise [ValidationError] If structure is invalid
    def validate_filter_range(filter_value, filter_field)
      unless filter_value.is_a?(Hash)
        raise Errors::ValidationError,
              "Invalid #{filter_field} filter structure. Expected Hash with 'range' key, got #{filter_value.class}"
      end

      unless filter_value.key?("range") || filter_value.key?(:range)
        raise Errors::ValidationError,
              "Missing required 'range' key in #{filter_field} filter. Expected format: {\"range\": {\"gt\": \"20000101\"}}"
      end

      range = filter_value["range"] || filter_value[:range]

      unless range.is_a?(Hash)
        raise Errors::ValidationError,
              "Invalid 'range' type in #{filter_field} filter. Expected Hash, got #{range.class}"
      end

      # Allowed range operators
      allowed_operators = %w[gt gte lt lte]
      validated_range = {}

      if range.empty?
        raise Errors::ValidationError,
              "Empty 'range' object in #{filter_field} filter. At least one operator (gt, gte, lt, lte) must be provided"
      end

      range.each do |operator, value|
        operator_str = operator.to_s

        unless allowed_operators.include?(operator_str)
          raise Errors::ValidationError,
                "Invalid range operator '#{operator_str}' in #{filter_field} filter. " \
                "Allowed operators: #{allowed_operators.join(', ')}"
        end

        # Validate date format (YYYYMMDD)
        validated_date = validate_filter_date(value, filter_field, operator_str)
        validated_range[operator_str] = validated_date
      end

      { "range" => validated_range }
    end

    # Validate date format for filter ranges
    # @param date_value [String, Date] Date value to validate
    # @param filter_field [String] Filter field name for error messages
    # @param operator [String] Range operator for error messages
    # @return [String] Validated date in YYYYMMDD format
    # @raise [ValidationError] If date format is invalid
    def validate_filter_date(date_value, filter_field, operator)
      # Convert Date objects to string
      return date_value.strftime("%Y%m%d") if date_value.is_a?(Date)

      unless date_value.is_a?(String)
        raise Errors::ValidationError,
              "Invalid date type for '#{operator}' in #{filter_field} filter. Expected String or Date, got #{date_value.class}"
      end

      # Check if it's already in YYYYMMDD format
      if date_value.match?(/^\d{8}$/)
        # Validate that it's a real date
        begin
          year = date_value[0..3].to_i
          month = date_value[4..5].to_i
          day = date_value[6..7].to_i
          Date.new(year, month, day)
          return date_value
        rescue ArgumentError
          raise Errors::ValidationError,
                "Invalid date '#{date_value}' for '#{operator}' in #{filter_field} filter. Not a valid date"
        end
      end

      # Try to parse various date formats and convert to YYYYMMDD
      begin
        parsed_date = case date_value
                      when /^\d{4}-\d{2}-\d{2}$/ # YYYY-MM-DD
                        Date.parse(date_value)
                      when %r{^\d{4}/\d{2}/\d{2}$}  # YYYY/MM/DD
                        Date.parse(date_value)
                      when %r{^\d{2}/\d{2}/\d{4}$}  # MM/DD/YYYY
                        Date.strptime(date_value, "%m/%d/%Y")
                      when /^\d{2}-\d{2}-\d{4}$/ # MM-DD-YYYY
                        Date.strptime(date_value, "%m-%d-%Y")
                      else
                        Date.parse(date_value) # Let Date.parse try to handle it
                      end

        parsed_date.strftime("%Y%m%d")
      rescue ArgumentError
        raise Errors::ValidationError,
              "Invalid date format '#{date_value}' for '#{operator}' in #{filter_field} filter. " \
              "Expected YYYYMMDD format (e.g., '20200101') or standard date formats (YYYY-MM-DD, etc.)"
      end
    end
  end
end
