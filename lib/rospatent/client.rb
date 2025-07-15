# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "faraday/follow_redirects"
require "json"
require_relative "input_validator"
require_relative "cache"
require_relative "logger"

module Rospatent
  # Main client for interacting with the Rospatent API
  class Client
    include InputValidator
    # Create a new client instance
    # @param token [String] JWT token for authentication (optional if set in configuration)
    # @param logger [Rospatent::Logger] Custom logger instance (optional)
    # @param cache [Rospatent::Cache] Custom cache instance (optional)
    def initialize(token: nil, logger: nil, cache: nil)
      @token = token || Rospatent.configuration.token
      raise Errors::MissingTokenError, "API token is required" unless @token

      # Initialize logger
      @logger = logger || create_logger

      # Initialize cache
      @cache = cache || create_cache

      # Track request metrics
      @request_count = 0
      @total_duration = 0.0
    end

    # Execute a search against the Rospatent API
    # @param params [Hash] Search parameters
    # @return [Rospatent::SearchResult] Search result object
    def search(**params)
      # Validation is now handled by Search class to avoid duplication
      Search.new(self).execute(**params)
    end

    # Fetch a specific patent by its document ID using dedicated endpoint
    # The document_id must follow one of these formats:
    # - Published documents: {country code}{publication number}{document type code}_
    #   {publication date YYYYMMDD}
    #   Example: RU134694U1_20131120
    # - Unpublished applications: {country code}{application number}{document type code}_
    #   {application date YYYYMMDD}
    #
    # @param document_id [String] The document ID to retrieve
    # @return [Hash] The patent document data
    # @raise [Rospatent::Errors::ApiError] If the document is not found or other API error
    # @raise [Rospatent::Errors::InvalidRequestError] If document_id format is invalid
    def patent(document_id)
      # Validate input
      validated_id = validate_patent_id(document_id)

      # Check cache first
      cache_key = "patent:#{validated_id}"
      cached_result = @cache.get(cache_key)
      if cached_result
        @logger.log_cache("hit", cache_key)
        return cached_result
      end

      @logger.log_cache("miss", cache_key)

      # Make a GET request to the docs endpoint
      result = get("/patsearch/v0.2/docs/#{validated_id}")

      # Cache the result
      @cache.set(cache_key, result, ttl: 3600) # Cache patents for 1 hour
      @logger.log_cache("set", cache_key, ttl: 3600)

      result
    end

    # Retrieve document by document components
    # @param country_code [String] Country code (e.g., "RU")
    # @param number [String] Patent number
    # @param doc_type [String] Document type (e.g., "A1")
    # @param date [String, Date] Publication date
    # @return [Hash] Document data
    # @raise [Rospatent::Errors::InvalidRequestError] If any required parameter is missing
    def patent_by_components(country_code, number, doc_type, date)
      # Validate and normalize inputs
      validated_country = validate_string(country_code, "country_code", max_length: 2)
      validated_number = validate_string(number, "number")
      validated_doc_type = validate_string(doc_type, "doc_type", max_length: 3)
      validated_date = validate_date(date, "date")

      formatted_date = validated_date.strftime("%Y%m%d")
      document_id = "#{validated_country}#{validated_number}#{validated_doc_type}_#{formatted_date}"

      patent(document_id)
    end

    # Find patents similar to a given document ID
    # @param document_id [String] The document ID to find similar patents to
    # @param count [Integer] Maximum number of results to return (default: 100)
    # @return [Hash] The similar search results
    # @raise [Rospatent::Errors::InvalidRequestError] If document_id is not provided
    # @raise [Rospatent::Errors::ApiError] If the API request fails
    #
    # This method uses the Rospatent API's similar search endpoint to find patents
    # similar to the given document ID.
    # The document ID should be in the format 'XX12345Y1_YYYYMMDD', where 'XX' is
    # the country code, '12345' is the publication number,
    # 'Y1' is the document type, and 'YYYYMMDD' is the publication date.
    #
    # The method returns a hash containing the similar search results, which includes
    # the patent IDs, titles, and other relevant information.
    #
    # If the document ID is not provided, the method raises an InvalidRequestError.
    # If the API request fails, the method raises an ApiError.
    def similar_patents_by_id(document_id, count: 100)
      # Validate inputs
      validated_id = validate_patent_id(document_id)
      validated_count = validate_positive_integer(count, "count", max_value: Rospatent.configuration.validation_limits[:similar_count_max_value])

      # Check cache first
      cache_key = "similar:id:#{validated_id}:#{validated_count}"
      cached_result = @cache.get(cache_key)
      if cached_result
        @logger.log_cache("hit", cache_key)
        return cached_result
      end

      @logger.log_cache("miss", cache_key)

      # Build the payload according to API spec
      payload = {
        type_search: "id_search",
        pat_id: validated_id,
        count: validated_count
      }

      # Make the API request with redirect handling
      result = post_with_redirects("/patsearch/v0.2/similar_search", payload)

      # Cache the result
      @cache.set(cache_key, result, ttl: 1800) # Cache for 30 minutes
      @logger.log_cache("set", cache_key, ttl: 1800)

      result
    end

    # Find patents similar to a given text
    # @param text [String] The text to find similar patents to (minimum 50 words required)
    # @param count [Integer] Maximum number of results to return (default: 100)
    # @return [Hash] The similar search results
    # @raise [Rospatent::Errors::ValidationError] If text has insufficient words or errors
    def similar_patents_by_text(text, count: 100)
      # Validate inputs - text must have at least 50 words for the API
              validated_text = validate_text_with_word_count(text, "search_text",
                                                        min_words: Rospatent.configuration.validation_limits[:similar_text_min_words],
                                                        max_length: Rospatent.configuration.validation_limits[:similar_text_max_length])
        validated_count = validate_positive_integer(count, "count", max_value: Rospatent.configuration.validation_limits[:similar_count_max_value])

      # Check cache first (using hash of text for key)
      text_hash = validated_text.hash.abs.to_s(16)
      cache_key = "similar:text:#{text_hash}:#{validated_count}"
      cached_result = @cache.get(cache_key)
      if cached_result
        @logger.log_cache("hit", cache_key)
        return cached_result
      end

      @logger.log_cache("miss", cache_key)

      # Build the payload according to API spec
      payload = {
        type_search: "text_search",
        pat_text: validated_text,
        count: validated_count
      }

      # Make the API request with redirect handling
      result = post_with_redirects("/patsearch/v0.2/similar_search", payload)

      # Cache the result
      @cache.set(cache_key, result, ttl: 1800) # Cache for 30 minutes
      @logger.log_cache("set", cache_key, ttl: 1800)

      result
    end

    # Get the list of available search datasets (collections)
    # @return [Array<Hash>] List of available datasets organized in a tree structure
    def datasets_tree
      # Check cache first
      cache_key = "datasets:tree"
      cached_result = @cache.get(cache_key)
      if cached_result
        @logger.log_cache("hit", cache_key)
        return cached_result
      end

      @logger.log_cache("miss", cache_key)

      # Make the API request
      result = get("/patsearch/v0.2/datasets/tree", {})

      # Cache the result for longer since datasets don't change often
      @cache.set(cache_key, result, ttl: 3600) # Cache for 1 hour
      @logger.log_cache("set", cache_key, ttl: 3600)

      result
    end

    # Retrieve media data (PDF, images, 3D objects) for a patent document
    # @param collection_id [String] Dataset/collection identifier (e.g., "National")
    # @param country_code [String] Country code of publication (e.g., "RU")
    # @param doc_type [String] Document type code (e.g., "U1")
    # @param pub_date [String, Date] Publication date in format YYYY/MM/DD
    # @param pub_number [String] Publication number
    # @param filename [String, nil] Media file name (optional, defaults to "<formatted_number>.pdf")
    # @return [String] Binary content with ASCII-8BIT encoding
    # @raise [Rospatent::Errors::InvalidRequestError] If any required parameter is missing
    # @example Retrieve and save a PDF with auto-generated filename
    #   pdf_data = client.patent_media("National", "RU", "U1", "2013/11/20", "134694")
    #   client.save_binary_file(pdf_data, "patent.pdf")
    # @example Retrieve and save a specific file
    #   pdf_data = client.patent_media("National", "RU", "U1", "2013/11/20", "134694", "document.pdf")
    #   client.save_binary_file(pdf_data, "patent.pdf")
    def patent_media(collection_id, country_code, doc_type, pub_date, pub_number,
                     filename = nil)
      # Validate and normalize inputs
      validated_collection = validate_required_string(collection_id, "collection_id")
      validated_country = validate_required_string(country_code, "country_code", max_length: 2)
      validated_doc_type = validate_required_string(doc_type, "doc_type", max_length: 3)
      validated_date = validate_required_date(pub_date, "pub_date")
      validated_number = validate_required_string(pub_number, "pub_number")

      # Format publication date
      formatted_date = validated_date.strftime("%Y/%m/%d")

      # Format publication number with appropriate padding
      formatted_number = format_publication_number(validated_number, validated_country)

      # Generate default filename if not provided
      validated_filename = if filename.nil?
                             "#{formatted_number}.pdf"
                           else
                             validate_required_string(filename, "filename")
                           end

      # Construct the path
      path = "/media/#{validated_collection}/#{validated_country}/" \
             "#{validated_doc_type}/#{formatted_date}/#{formatted_number}/" \
             "#{validated_filename}"

      # Get binary data
      get(path, {}, binary: true)
    end

    # Retrieve media using simplified patent ID format
    # @param document_id [String] Patent document ID (e.g., "RU134694U1_20131120")
    # @param collection_id [String] Collection identifier (e.g., "National")
    # @param filename [String, nil] Filename to retrieve (optional, defaults to "<formatted_number>.pdf")
    # @return [String] Binary content with ASCII-8BIT encoding
    # @raise [Rospatent::Errors::InvalidRequestError] If document_id format is invalid
    #   or parameters are missing
    # @example Retrieve and save a PDF with auto-generated filename
    #   pdf_data = client.patent_media_by_id("RU134694U1_20131120", "National")
    #   client.save_binary_file(pdf_data, "patent.pdf")
    # @example Retrieve and save a specific file
    #   pdf_data = client.patent_media_by_id("RU134694U1_20131120", "National", "document.pdf")
    #   client.save_binary_file(pdf_data, "patent.pdf")
    def patent_media_by_id(document_id, collection_id, filename = nil)
      # Validate inputs
      validated_id = validate_patent_id(document_id)
      validated_collection = validate_required_string(collection_id, "collection_id")

      # Validate filename if provided
      validated_filename = filename ? validate_required_string(filename, "filename") : nil

      # Parse the patent ID to extract components
      id_parts = parse_patent_id(validated_id)

      # Format the date from YYYYMMDD to YYYY/MM/DD
      formatted_date = id_parts[:date].gsub(/^(\d{4})(\d{2})(\d{2})$/, '\1/\2/\3')

      # Call the base method with extracted components
      # If no filename provided, patent_media will generate default using format_publication_number
      patent_media(validated_collection, id_parts[:country_code], id_parts[:doc_type],
                   formatted_date, id_parts[:number], validated_filename)
    end

    # Extract and parse the abstract content from a patent document
    # Delegates to PatentParser.parse_abstract
    # @param patent_data [Hash] The patent document data returned by #patent method
    # @param format [Symbol] The desired output format (:text or :html)
    # @param language [String] The language code (e.g., "ru", "en")
    # @return [String, nil] The parsed abstract content in the requested format or nil if not found
    # @example Get plain text abstract
    #   abstract = client.parse_abstract(patent_doc)
    # @example Get HTML abstract in English
    #   abstract_html = client.parse_abstract(patent_doc, format: :html, language: "en")
    def parse_abstract(patent_data, format: :text, language: "ru")
      # Validate inputs
      validate_enum(format, %i[text html], "format")
      validate_string(language, "language", max_length: 5) if language

      PatentParser.parse_abstract(patent_data, format: format, language: language)
    end

    # Extract and parse the description content from a patent document
    # Delegates to PatentParser.parse_description
    # @param patent_data [Hash] The patent document data returned by #patent method
    # @param format [Symbol] The desired output format (:text, :html, or :sections)
    # @param language [String] The language code (e.g., "ru", "en")
    # @return [String, Array, nil] The parsed description content in the requested
    #   format or nil if not found
    # @example Get plain text description
    #   description = client.parse_description(patent_doc)
    # @example Get HTML description
    #   description_html = client.parse_description(patent_doc, format: :html)
    # @example Get description split into sections
    #   sections = client.parse_description(patent_doc, format: :sections)
    def parse_description(patent_data, format: :text, language: "ru")
      # Validate inputs
      validate_enum(format, %i[text html sections], "format")
      validate_string(language, "language", max_length: 5) if language

      PatentParser.parse_description(patent_data, format: format, language: language)
    end

    # Search within a classification system (IPC or CPC) using natural language
    # @param classifier_id [String] Classification system identifier ("ipc" or "cpc")
    # @param query [String] Search query in natural language
    # @param lang [String] Language for the search ("ru" or "en")
    # @return [Hash] Search results containing classification codes and descriptions
    # @raise [Rospatent::Errors::ValidationError] If parameters are invalid
    # @example Search for rocket-related IPC codes
    #   results = client.classification_search("ipc", query: "ракета", lang: "ru")
    def classification_search(classifier_id, query:, lang: "ru")
      # Validate inputs
      validated_classifier = validate_enum(classifier_id, %w[ipc cpc], "classifier_id").to_s
      validated_query = validate_string(query, "query", max_length: Rospatent.configuration.validation_limits[:classification_query_max_length])
      validated_lang = validate_enum(lang, %w[ru en], "lang").to_s

      # Check cache first
      cache_key = "classification:search:#{validated_classifier}:" \
                  "#{validated_query}:#{validated_lang}"
      cached_result = @cache.get(cache_key)
      if cached_result
        @logger.log_cache("hit", cache_key)
        return cached_result
      end

      @logger.log_cache("miss", cache_key)

      # Build the payload
      payload = {
        query: validated_query,
        lang: validated_lang
      }

      # Make a POST request to the classification search endpoint
      result = post("/patsearch/v0.2/classification/#{validated_classifier}/search/", payload)

      # Cache the result
      @cache.set(cache_key, result, ttl: 1800) # Cache for 30 minutes
      @logger.log_cache("set", cache_key, ttl: 1800)

      result
    end

    # Get detailed information about a specific classification code
    # @param classifier_id [String] Classification system identifier ("ipc" or "cpc")
    # @param code [String] Classification code to look up
    # @param lang [String] Language for the description ("ru" or "en")
    # @return [Hash] Detailed information about the classification code
    # @raise [Rospatent::Errors::ValidationError] If parameters are invalid
    # @example Get information about IPC code
    #   info = client.classification_code("ipc", code: "F02K9/00", lang: "ru")
    def classification_code(classifier_id, code:, lang: "ru")
      # Validate inputs
      validated_classifier = validate_enum(classifier_id, %w[ipc cpc], "classifier_id").to_s
      validated_code = validate_string(code, "code", max_length: Rospatent.configuration.validation_limits[:classification_code_max_length])
      validated_lang = validate_enum(lang, %w[ru en], "lang").to_s

      # Check cache first
      cache_key = "classification:code:#{validated_classifier}:#{validated_code}:#{validated_lang}"
      cached_result = @cache.get(cache_key)
      if cached_result
        @logger.log_cache("hit", cache_key)
        return cached_result
      end

      @logger.log_cache("miss", cache_key)

      # Build the payload
      payload = {
        code: validated_code,
        lang: validated_lang
      }

      # Make a POST request to the classification code endpoint
      result = post("/patsearch/v0.2/classification/#{validated_classifier}/code/", payload)

      # Cache the result for longer since classification codes don't change often
      @cache.set(cache_key, result, ttl: 3600) # Cache for 1 hour
      @logger.log_cache("set", cache_key, ttl: 3600)

      result
    end

    # Execute a GET request to the API
    # @param endpoint [String] API endpoint
    # @param params [Hash] Query parameters (optional)
    # @param binary [Boolean] Whether to expect binary response (default: false)
    # @return [Hash, String] Response data (Hash for JSON, String for binary)
    def get(endpoint, params = {}, binary: false)
      start_time = Time.now
      request_id = generate_request_id

      @logger.log_request("GET", endpoint, params, connection.headers)
      @request_count += 1

      response = connection.get(endpoint, params) do |req|
        if binary
          req.headers["Accept"] = "*/*"
        else
          req.headers["Accept"] = "application/json"
          req.headers["Content-Type"] = "application/json"
        end
        req.headers["X-Request-ID"] = request_id
      end

      duration = Time.now - start_time
      @total_duration += duration

      @logger.log_response("GET", endpoint, response.status, duration,
                           response_size: response.body&.bytesize, request_id: request_id)

      if binary
        handle_binary_response(response, request_id)
      else
        handle_response(response, request_id)
      end
    rescue Faraday::Error => e
      @logger.log_error(e, { endpoint: endpoint, params: params, request_id: request_id })
      handle_error(e)
    end

    # Execute a POST request to the API
    # @param endpoint [String] API endpoint
    # @param payload [Hash] Request payload
    # @return [Hash] Response data
    def post(endpoint, payload)
      start_time = Time.now
      request_id = generate_request_id

      @logger.log_request("POST", endpoint, payload, connection.headers)
      @request_count += 1

      response = connection.post(endpoint) do |req|
        req.headers["Accept"] = "application/json"
        req.headers["Content-Type"] = "application/json"
        req.headers["X-Request-ID"] = request_id
        req.body = payload.to_json
      end

      duration = Time.now - start_time
      @total_duration += duration

      @logger.log_response("POST", endpoint, response.status, duration,
                           response_size: response.body&.bytesize, request_id: request_id)

      handle_response(response, request_id)
    rescue Faraday::Error => e
      @logger.log_error(e, { endpoint: endpoint, payload: payload, request_id: request_id })
      handle_error(e)
    end

    # Batch process multiple patents
    # @param document_ids [Array<String>] Array of document IDs
    # @param batch_size [Integer] Number of patents to process concurrently
    # @return [Enumerator] Enumerator that yields patent documents
    def batch_patents(document_ids, batch_size: 10)
      return enum_for(:batch_patents, document_ids, batch_size: batch_size) unless block_given?

      validate_array(document_ids, "document_ids", max_size: Rospatent.configuration.validation_limits[:batch_ids_max_size])
      validated_batch_size = validate_positive_integer(batch_size, "batch_size", max_value: Rospatent.configuration.validation_limits[:batch_size_max_value])

      document_ids.each_slice(validated_batch_size) do |batch|
        threads = batch.map do |doc_id|
          Thread.new do
            patent(doc_id)
          rescue StandardError => e
            @logger.log_error(e, { document_id: doc_id, operation: "batch_patents" })
            { error: e.message, document_id: doc_id }
          end
        end

        threads.each { |thread| yield thread.value }
      end
    end

    # Get client statistics
    # @return [Hash] Client usage statistics
    def statistics
      {
        requests_made: @request_count,
        total_duration_seconds: @total_duration.round(3),
        average_request_time: if @request_count.positive?
                                (@total_duration / @request_count).round(3)
                              else
                                0
                              end,
        cache_stats: @cache.statistics
      }
    end

    # Save binary data to a file with proper encoding handling
    # This method ensures that binary data (PDFs, images, etc.) is written correctly
    # @param binary_data [String] Binary data returned from patent_media methods
    # @param file_path [String] Path where to save the file
    # @return [Integer] Number of bytes written
    # @raise [SystemCallError] If file cannot be written
    # @example Save a PDF file with auto-generated filename
    #   pdf_data = client.patent_media_by_id("RU134694U1_20131120", "National")
    #   client.save_binary_file(pdf_data, "patent.pdf")
    # @example Save a specific file
    #   pdf_data = client.patent_media_by_id("RU134694U1_20131120", "National", "document.pdf")
    #   client.save_binary_file(pdf_data, "patent.pdf")
    def save_binary_file(binary_data, file_path)
      validate_required_string(binary_data, "binary_data")
      validate_required_string(file_path, "file_path")

      # Ensure data is properly encoded as binary
      data_to_write = binary_data.dup.force_encoding(Encoding::ASCII_8BIT)

      # Write in binary mode to prevent any encoding conversions
      File.binwrite(file_path, data_to_write)
    end

    private

    # Validate search parameters
    # @param params [Hash] Search parameters to validate
    # @return [Hash] Validated parameters
    # @deprecated This method is deprecated. Validation now happens in Search class.
    def validate_search_params(params)
      # Validation is now handled by Search class to avoid duplication
      # This method remains for backward compatibility but does no validation
      params
    end

    # Parse a patent ID string into its component parts
    # @param document_id [String] The document ID to parse
    # @return [Hash] The component parts of the document ID
    # @example Parse "RU134694U1_20131120"
    #   parse_patent_id("RU134694U1_20131120")
    #   # => { country_code: "RU", number: "134694", doc_type: "U1", date: "20131120" }
    def parse_patent_id(document_id)
      # Split into main parts (before and after underscore)
      main_part, date = document_id.split("_")

      # Extract country code (first 2 characters)
      country_code = main_part[0..1]

      # Extract doc type (letter+digit at the end of main part)
      # This regex finds the last occurrence of a letter followed by digits at the end of the string
      doc_type_match = main_part.match(/([A-Z]\d+)$/)
      doc_type = doc_type_match ? doc_type_match[0] : nil

      # Extract number (everything between country code and doc type)
      number_end_pos = doc_type_match ? doc_type_match.begin(0) - 1 : -1
      number = main_part[2..number_end_pos]

      {
        country_code: country_code,
        number: number,
        doc_type: doc_type,
        date: date
      }
    end

    # Create a Faraday connection with appropriate configuration
    # @return [Faraday::Connection] Configured connection
    def connection
      @connection ||= Faraday.new(url: Rospatent.configuration.api_url) do |conn|
        conn.headers["Authorization"] = "Bearer #{@token}"
        conn.headers["User-Agent"] = Rospatent.configuration.user_agent

        conn.options.timeout = Rospatent.configuration.timeout
        conn.options.open_timeout = Rospatent.configuration.timeout

        conn.request :retry, {
          max: Rospatent.configuration.retry_count,
          interval: 0.5,
          interval_randomness: 0.5,
          backoff_factor: 2
        }

        conn.adapter Faraday.default_adapter
      end
    end

    # Create a Faraday connection with redirect following for specific endpoints
    # @return [Faraday::Connection] Configured connection with redirect support
    def connection_with_redirects
      @connection_with_redirects ||= Faraday.new(url: Rospatent.configuration.api_url) do |conn|
        conn.headers["Authorization"] = "Bearer #{@token}"
        conn.headers["User-Agent"] = Rospatent.configuration.user_agent

        conn.options.timeout = Rospatent.configuration.timeout
        conn.options.open_timeout = Rospatent.configuration.timeout

        conn.request :retry, {
          max: Rospatent.configuration.retry_count,
          interval: 0.5,
          interval_randomness: 0.5,
          backoff_factor: 2
        }

        conn.response :follow_redirects
        conn.adapter Faraday.default_adapter
      end
    end

    # Make an HTTP POST request with redirect support
    # @param endpoint [String] API endpoint
    # @param payload [Hash] Request payload
    # @return [Hash] Parsed response data
    def post_with_redirects(endpoint, payload = {})
      start_time = Time.now
      request_id = generate_request_id

      @logger.log_request("POST", endpoint, payload, connection_with_redirects.headers)
      @request_count += 1

      response = connection_with_redirects.post(endpoint) do |req|
        req.headers["Accept"] = "application/json"
        req.headers["Content-Type"] = "application/json"
        req.headers["X-Request-ID"] = request_id
        req.body = payload.to_json
      end

      duration = Time.now - start_time
      @total_duration += duration

      @logger.log_response("POST", endpoint, response.status, duration,
                           response_size: response.body&.bytesize, request_id: request_id)

      handle_response(response, request_id)
    rescue Faraday::Error => e
      @logger.log_error(e, { endpoint: endpoint, payload: payload, request_id: request_id })
      handle_error(e)
    end

    # Process API response
    # @param response [Faraday::Response] Raw response from the API
    # @param request_id [String] Request ID for tracking
    # @return [Hash] Parsed response data
    # @raise [Rospatent::Errors::ApiError] If the response is not successful
    def handle_response(response, request_id = nil)
      return JSON.parse(response.body) if response.success?

      error_msg = begin
        data = JSON.parse(response.body)
        # Try different possible error message fields used by Rospatent API
        data["result"] || data["error"] || data["message"] || "Unknown error"
      rescue JSON::ParserError
        response.body
      end

      # Create specific error types based on status code
      case response.status
      when 401
        raise Errors::AuthenticationError, "#{error_msg} [Request ID: #{request_id}]"
      when 404
        raise Errors::NotFoundError.new("#{error_msg} [Request ID: #{request_id}]", response.status)
      when 422
        errors = extract_validation_errors(response)
        raise Errors::ValidationError.new(error_msg, errors)
      when 429
        retry_after = response.headers["Retry-After"]&.to_i
        raise Errors::RateLimitError.new(error_msg, response.status, retry_after)
      when 503
        raise Errors::ServiceUnavailableError.new("#{error_msg} [Request ID: #{request_id}]",
                                                  response.status)
      else
        raise Errors::ApiError.new(error_msg, response.status, response.body, request_id)
      end
    end

    # Process binary API response (for media files)
    # @param response [Faraday::Response] Raw response from the API
    # @param request_id [String] Request ID for tracking
    # @return [String] Binary response data with proper encoding
    # @raise [Rospatent::Errors::ApiError] If the response is not successful
    def handle_binary_response(response, request_id = nil)
      if response.success?
        # Ensure binary data is properly encoded as ASCII-8BIT to prevent encoding issues
        binary_data = response.body.dup
        binary_data.force_encoding(Encoding::ASCII_8BIT)
        return binary_data
      end

      # For binary endpoints, error responses might still be JSON
      error_msg = begin
        data = JSON.parse(response.body)
        # Try different possible error message fields used by Rospatent API
        data["result"] || data["error"] || data["message"] || "Unknown error"
      rescue JSON::ParserError
        "Binary request failed"
      end

      # Create specific error types based on status code
      case response.status
      when 401
        raise Errors::AuthenticationError, "#{error_msg} [Request ID: #{request_id}]"
      when 404
        raise Errors::NotFoundError.new("#{error_msg} [Request ID: #{request_id}]", response.status)
      when 422
        errors = extract_validation_errors(response)
        raise Errors::ValidationError.new(error_msg, errors)
      when 429
        retry_after = response.headers["Retry-After"]&.to_i
        raise Errors::RateLimitError.new(error_msg, response.status, retry_after)
      when 503
        raise Errors::ServiceUnavailableError.new("#{error_msg} [Request ID: #{request_id}]",
                                                  response.status)
      else
        raise Errors::ApiError.new(error_msg, response.status, response.body, request_id)
      end
    end

    # Handle connection errors
    # @param error [Faraday::Error] Connection error
    # @raise [Rospatent::Errors::ConnectionError] Wrapped connection error
    def handle_error(error)
      case error
      when Faraday::TimeoutError
        raise Errors::TimeoutError.new("Request timed out: #{error.message}", error)
      when Faraday::ConnectionFailed
        raise Errors::ConnectionError.new("Connection failed: #{error.message}", error)
      else
        raise Errors::ConnectionError.new("Connection error: #{error.message}", error)
      end
    end

    # Extract validation errors from API response
    # @param response [Faraday::Response] API response
    # @return [Hash] Field-specific validation errors
    def extract_validation_errors(response)
      data = JSON.parse(response.body)
      # Check various possible validation error fields
      data["errors"] || data["validation_errors"] || data["details"] || {}
    rescue JSON::ParserError
      {}
    end

    # Create logger instance based on configuration
    # @return [Rospatent::Logger, Rospatent::NullLogger] Logger instance
    def create_logger
      config = Rospatent.configuration
      return NullLogger.new if config.log_level == :none

      Logger.new(
        level: config.log_level,
        formatter: config.environment == "production" ? :json : :text
      )
    end

    # Create cache instance based on configuration
    # @return [Rospatent::Cache, Rospatent::NullCache] Cache instance
    def create_cache
      config = Rospatent.configuration
      return NullCache.new unless config.cache_enabled

      Cache.new(
        ttl: config.cache_ttl,
        max_size: config.cache_max_size
      )
    end

    # Generate a unique request ID
    # @return [String] Unique request identifier
    def generate_request_id
      "req_#{Time.now.to_f}_#{rand(10_000)}"
    end

    # Pad publication number with leading zeros for specific countries
    # @param number [String] Publication number to pad
    # @param country_code [String] Country code (e.g., "RU")
    # @return [String] Padded publication number
    def format_publication_number(number, country_code)
      # Russian patents require 10-digit publication numbers
      if country_code == "RU" && number.length < 10
        number.rjust(10, "0")
      else
        number
      end
    end
  end
end
