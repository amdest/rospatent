# frozen_string_literal: true

require_relative "input_validator"

module Rospatent
  # Search result class to handle API responses
  class SearchResult
    attr_reader :total, :available, :hits, :raw_response

    # Initialize a search result from API response
    # @param response [Hash] API response data
    def initialize(response)
      @raw_response = response
      @total = response["total"]
      @available = response["available"]
      @hits = response["hits"] || []
    end

    # Check if the search has any results
    # @return [Boolean] true if there are any hits
    def any? = !@hits.empty?

    # Return the number of hits in the current response
    # @return [Integer] number of hits
    def count = @hits.count
  end

  # Search class to handle search queries to the API
  class Search
    include InputValidator

    # Initialize a new search instance
    # @param client [Rospatent::Client] API client instance
    def initialize(client)
      @client = client
    end

    # Execute a search against the API
    #
    # @param q [String] Search query using the special query language
    # @param qn [String] Natural language search query
    # @param limit [Integer] Maximum number of results to return
    # @param offset [Integer] Offset for pagination
    # @param pre_tag [String, Array<String>] HTML tag(s) to prepend to highlighted matches
    # @param post_tag [String, Array<String>] HTML tag(s) to append to highlighted matches
    # @param sort [Symbol, String] Sort option (:relevance, :pub_date, :filing_date)
    # @param group_by [String] Grouping option ("family:docdb", "family:dwpi")
    # @param include_facets [Boolean] Whether to include facet information (true/false, converted to 1/0 for API)
    # @param filter [Hash] Filters to apply to the search
    # @param datasets [Array<String>] Datasets to search within
    # @param highlight [Hash] Advanced highlight configuration with profiles
    #
    # @return [Rospatent::SearchResult] Search result object
    def execute(
      q: nil,
      qn: nil,
      limit: nil,
      offset: nil,
      pre_tag: nil,
      post_tag: nil,
      sort: nil,
      group_by: nil,
      include_facets: nil,
      filter: nil,
      datasets: nil,
      highlight: nil
    )
      # Filter out nil parameters to only validate explicitly provided ones
      params = {
        q: q, qn: qn, limit: limit, offset: offset,
        pre_tag: pre_tag, post_tag: post_tag, sort: sort,
        group_by: group_by, include_facets: include_facets,
        filter: filter, datasets: datasets, highlight: highlight
      }.compact

      # Validate and normalize parameters
      validated_params = validate_and_normalize_params(**params)

      payload = build_payload(**validated_params)
      response = @client.post("/patsearch/v0.2/search", payload)
      SearchResult.new(response)
    end

    private

    # Validate and normalize all search parameters
    # @param params [Hash] Search parameters
    # @return [Hash] Validated and normalized parameters
    # @raise [Rospatent::Errors::ValidationError] when validation fails
    def validate_and_normalize_params(**params)
      # Check that at least one query parameter is provided
      unless params[:q] || params[:qn]
        raise Errors::InvalidRequestError,
              "Either 'q' or 'qn' parameter must be provided for search"
      end

      validated = {}

      # Validate query parameters
      config = Rospatent.configuration
      validated[:q] = validate_string(params[:q], "q", max_length: config.validation_limits[:query_max_length]) if params[:q]
      validated[:qn] = validate_string(params[:qn], "qn", max_length: config.validation_limits[:natural_query_max_length]) if params[:qn]

      # Validate pagination parameters (only if provided)
      if params[:limit]
        validated[:limit] =
          validate_positive_integer(params[:limit], "limit", min_value: 1, max_value: config.validation_limits[:limit_max_value])
      end
      if params[:offset]
        validated[:offset] =
          validate_positive_integer(params[:offset], "offset", min_value: 0, max_value: config.validation_limits[:offset_max_value])
      end

      # Validate highlighting parameters (only if provided)
      # pre_tag and post_tag must be provided together
      if params[:pre_tag] || params[:post_tag]
        unless params[:pre_tag] && params[:post_tag]
          raise Errors::ValidationError,
                "Both pre_tag and post_tag must be provided together for highlighting"
        end

        validated[:pre_tag] =
          validate_string_or_array(params[:pre_tag], "pre_tag", max_length: config.validation_limits[:pre_tag_max_length], max_size: config.validation_limits[:pre_tag_max_size])
        validated[:post_tag] =
          validate_string_or_array(params[:post_tag], "post_tag", max_length: config.validation_limits[:post_tag_max_length], max_size: config.validation_limits[:post_tag_max_size])
      end

      # Validate highlight parameter (complex object for advanced highlighting)
      validated[:highlight] = validate_hash(params[:highlight], "highlight") if params[:highlight]

      # Validate sort parameter (only if provided)
      validated[:sort] = validate_sort_parameter(params[:sort]) if params[:sort]

      # Validate group_by parameter (only if provided)
      if params[:group_by]
        validated[:group_by] = validate_string_enum(params[:group_by], %w[family:docdb family:dwpi], "group_by")
      end

      # Validate boolean parameters (only if provided)
      if params.key?(:include_facets)
        value = params[:include_facets]
        # Convert various representations to boolean
        validated[:include_facets] = case value
                                     when nil then nil
                                     when true, "true", "1", 1, "yes", "on" then true
                                     when false, "false", "0", 0, "no", "off", "" then false
                                     else !!value # For any other truthy values
                                     end
      end

      # Validate filter parameter
      validated[:filter] = validate_filter(params[:filter], "filter") if params[:filter]

      # Validate datasets parameter
      if params[:datasets]
        validated[:datasets] = validate_array(params[:datasets], "datasets", max_size: config.validation_limits[:array_max_size]) do |dataset|
          validate_string(dataset, "dataset")
        end
      end

      validated.compact
    end

    # Build the search payload
    # @param params [Hash] Validated search parameters
    # @return [Hash] Search request payload
    def build_payload(**params)
      payload = {}

      # Add query parameters (required)
      payload[:q] = params[:q] if params[:q]
      payload[:qn] = params[:qn] if params[:qn]

      # Add pagination parameters (only if explicitly provided)
      payload[:limit] = params[:limit] if params[:limit]
      payload[:offset] = params[:offset] if params[:offset]

      # Add highlighting tags (only if both are provided)
      if params[:pre_tag] && params[:post_tag]
        payload[:pre_tag] = params[:pre_tag]
        payload[:post_tag] = params[:post_tag]
      end

      # Add advanced highlight parameter (independent of tags)
      payload[:highlight] = params[:highlight] if params[:highlight]

      # Add sort parameter (only if explicitly provided)
      payload[:sort] = params[:sort] if params[:sort]

      # Add grouping parameter (only if explicitly provided)
      payload[:group_by] = params[:group_by] if params[:group_by]

      # Add other parameters (only if explicitly provided)
      # Convert boolean to numeric format for API (true → 1, false → 0)
      if params.key?(:include_facets)
        payload[:include_facets] = params[:include_facets] ? 1 : 0
      end
      payload[:filter] = params[:filter] if params[:filter]
      payload[:datasets] = params[:datasets] if params[:datasets]

      payload
    end

    # Validate and normalize sort parameter according to API documentation
    # @param sort_value [String, Symbol] Sort parameter value
    # @return [String] Normalized sort parameter
    # @raise [Rospatent::Errors::ValidationError] If sort parameter is invalid
    def validate_sort_parameter(sort_value)
      return nil unless sort_value

      # Allowed values according to API documentation
      allowed_values = [
        "relevance",
        "publication_date:asc",
        "publication_date:desc",
        "filing_date:asc",
        "filing_date:desc"
      ]

      # Convert and normalize the sort parameter
      normalized = case sort_value.to_s
                   when "relevance" then "relevance"
                   when "pub_date" then "publication_date:desc"    # Default to desc for backward compatibility
                   when "filing_date" then "filing_date:desc"      # Default to desc for backward compatibility
                   when "publication_date:asc", "publication_date:desc",
                        "filing_date:asc", "filing_date:desc"
                     sort_value.to_s
                   else
                     sort_value.to_s
                   end

      # Validate against allowed values
      unless allowed_values.include?(normalized)
        raise Errors::ValidationError,
              "Invalid sort parameter. Allowed values: #{allowed_values.join(', ')}"
      end

      normalized
    end
  end
end
