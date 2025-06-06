# frozen_string_literal: true

require "test_helper"

class SearchResultTest < Minitest::Test
  def test_initialization_with_valid_response
    # Arrange
    response = {
      "total" => 100,
      "available" => 50,
      "hits" => [
        { "id" => "1", "common" => { "document_number" => "123" } },
        { "id" => "2", "common" => { "document_number" => "456" } }
      ]
    }

    # Act
    result = Rospatent::SearchResult.new(response)

    # Assert
    assert_equal 100, result.total, "Should store total count"
    assert_equal 50, result.available, "Should store available count"
    assert_equal 2, result.hits.size, "Should store hits array"
    assert_equal "123", result.hits[0]["common"]["document_number"], "Should preserve hit structure"
    assert_equal response, result.raw_response, "Should store raw response"
  end

  def test_any_method
    # Arrange
    result_with_hits = Rospatent::SearchResult.new({ "hits" => [{ "id" => "1" }] })
    result_without_hits = Rospatent::SearchResult.new({ "hits" => [] })
    result_with_nil_hits = Rospatent::SearchResult.new({})

    # Act & Assert
    assert result_with_hits.any?, "Should return true when hits exist"
    refute result_without_hits.any?, "Should return false when hits array is empty"
    refute result_with_nil_hits.any?, "Should handle nil hits gracefully"
  end

  def test_count_method
    # Arrange
    result = Rospatent::SearchResult.new({
                                           "hits" => [
                                             { "id" => "1" },
                                             { "id" => "2" },
                                             { "id" => "3" }
                                           ]
                                         })

    # Act & Assert
    assert_equal 3, result.count, "Should return the number of hits"
  end
end

class SearchTest < Minitest::Test
  def setup
    super
    @client_mock = Minitest::Mock.new
    @search = Rospatent::Search.new(@client_mock)
  end

  def test_execute_with_minimal_params
    # Arrange
    expected_payload = { q: "test" }

    response_data = { "total" => 10, "available" => 10, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    result = @search.execute(q: "test")

    # Assert
    assert_instance_of Rospatent::SearchResult, result, "Should return a SearchResult instance"
    @client_mock.verify
  end

  def test_execute_with_all_params
    # Arrange
    filter = { "classification.ipc_group" => { "values" => ["F02K9"] } }
    datasets = ["ru_since_1994"]
    highlight = { "profiles" => [{ "q" => "космическая", "pre_tag" => "<b>", "post_tag" => "</b>" }] }

    expected_payload = {
      q: "test",
      qn: "natural language query",
      limit: 20,
      offset: 30,
      pre_tag: "<mark>",
      post_tag: "</mark>",
      sort: "publication_date:desc",
      group_by: "family:dwpi",
      include_facets: 1,
      filter: filter,
      datasets: datasets,
      highlight: highlight
    }

    response_data = { "total" => 5, "available" => 5, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    result = @search.execute(
      q: "test",
      qn: "natural language query",
      limit: 20,
      offset: 30,
      pre_tag: "<mark>",
      post_tag: "</mark>",
      sort: :pub_date,
      group_by: "family:dwpi",
      include_facets: true,
      filter: filter,
      datasets: datasets,
      highlight: highlight
    )

    # Assert
    @client_mock.verify
    assert_instance_of Rospatent::SearchResult, result
  end

  def test_validation_requires_query
    # Act & Assert
    error = assert_raises(Rospatent::Errors::InvalidRequestError) do
      @search.execute
    end

    assert_equal "Either 'q' or 'qn' parameter must be provided for search", error.message,
                 "Should raise error when neither q nor qn is provided"
  end

  def test_execute_with_no_highlight
    # Arrange
    expected_payload = { q: "test" }

    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", highlight: false)

    # Assert
    @client_mock.verify
  end

  def test_execute_with_detailed_sort_parameters
    # Arrange
    expected_payload = { q: "test", sort: "publication_date:asc" }
    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", sort: "publication_date:asc")

    # Assert
    @client_mock.verify
  end

  def test_execute_with_publication_date_desc_sort
    # Arrange
    expected_payload = { q: "test", sort: "publication_date:desc" }
    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", sort: "publication_date:desc")

    # Assert
    @client_mock.verify
  end

  def test_execute_with_filing_date_sort
    # Arrange
    expected_payload = { q: "test", sort: "filing_date:asc" }
    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", sort: "filing_date:asc")

    # Assert
    @client_mock.verify
  end

  def test_execute_with_backward_compatible_sort_symbols
    # Arrange - backward compatibility with :pub_date should convert to publication_date:desc
    expected_payload = { q: "test", sort: "publication_date:desc" }
    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", sort: :pub_date)

    # Assert
    @client_mock.verify
  end

  def test_execute_with_backward_compatible_filing_date_symbol
    # Arrange - backward compatibility with :filing_date should convert to filing_date:desc
    expected_payload = { q: "test", sort: "filing_date:desc" }
    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", sort: :filing_date)

    # Assert
    @client_mock.verify
  end

  def test_execute_with_invalid_sort_parameter
    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      @search.execute(q: "test", sort: "invalid_sort")
    end

    assert_match(/Invalid sort parameter/, error.message,
                 "Should raise validation error for invalid sort")
  end

  def test_validate_sort_parameter_with_valid_values
    # Test valid sort parameters
    valid_sorts = [
      "relevance",
      "publication_date:asc",
      "publication_date:desc",
      "filing_date:asc",
      "filing_date:desc"
    ]

    valid_sorts.each do |sort_value|
      result = @search.send(:validate_sort_parameter, sort_value)
      assert_equal sort_value, result, "Should accept valid sort parameter: #{sort_value}"
    end
  end

  def test_validate_sort_parameter_with_backward_compatibility
    # Test backward compatibility
    result = @search.send(:validate_sort_parameter, :pub_date)
    assert_equal "publication_date:desc", result,
                 "Should convert :pub_date to publication_date:desc"

    result = @search.send(:validate_sort_parameter, :filing_date)
    assert_equal "filing_date:desc", result, "Should convert :filing_date to filing_date:desc"

    result = @search.send(:validate_sort_parameter, :relevance)
    assert_equal "relevance", result, "Should handle :relevance correctly"
  end

  def test_validate_sort_parameter_with_nil
    result = @search.send(:validate_sort_parameter, nil)
    assert_nil result, "Should return nil for nil input"
  end

  def test_validate_sort_parameter_with_invalid_values
    invalid_sorts = [
      "invalid",
      "publication_date:invalid",
      "random_field:asc",
      "filing_date:wrong"
    ]

    invalid_sorts.each do |invalid_sort|
      error = assert_raises(Rospatent::Errors::ValidationError) do
        @search.send(:validate_sort_parameter, invalid_sort)
      end

      assert_match(/Invalid sort parameter/, error.message,
                   "Should reject invalid sort parameter: #{invalid_sort}")
    end
  end

  def test_execute_with_array_highlight_tags
    # Arrange
    expected_payload = {
      q: "test",
      pre_tag: ["<b>", "<i>"],
      post_tag: ["</b>", "</i>"]
    }

    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", pre_tag: ["<b>", "<i>"], post_tag: ["</b>", "</i>"])

    # Assert
    @client_mock.verify
  end

  def test_execute_with_only_pre_tag_raises_error
    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      @search.execute(q: "test", pre_tag: "<mark>")
    end

    assert_equal "Both pre_tag and post_tag must be provided together for highlighting", error.message
  end

  def test_execute_with_only_post_tag_raises_error
    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      @search.execute(q: "test", post_tag: "</mark>")
    end

    assert_equal "Both pre_tag and post_tag must be provided together for highlighting", error.message
  end

  def test_execute_with_complex_highlight_object
    # Arrange
    highlight = {
      "profiles" => [
        { "q" => "космическая", "pre_tag" => "<b>", "post_tag" => "</b>" },
        "_searchquery_"
      ]
    }

    expected_payload = {
      q: "test",
      highlight: highlight
    }

    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", highlight: highlight)

    # Assert
    @client_mock.verify
  end

  def test_execute_with_highlight_and_tags_independent
    # Arrange - highlight parameter and tags should be independent
    highlight = { "profiles" => ["_searchquery_"] }

    expected_payload = {
      q: "test",
      pre_tag: "<mark>",
      post_tag: "</mark>",
      highlight: highlight
    }

    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", pre_tag: "<mark>", post_tag: "</mark>", highlight: highlight)

    # Assert
    @client_mock.verify
  end

  def test_execute_with_family_docdb_grouping
    # Arrange
    expected_payload = {
      q: "test",
      group_by: "family:docdb"
    }

    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", group_by: "family:docdb")

    # Assert
    @client_mock.verify
  end

  def test_execute_with_family_dwpi_grouping
    # Arrange
    expected_payload = {
      q: "test",
      group_by: "family:dwpi"
    }

    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", group_by: "family:dwpi")

    # Assert
    @client_mock.verify
  end

  def test_execute_with_invalid_group_by_raises_error
    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      @search.execute(q: "test", group_by: "invalid_grouping")
    end

    assert_match(/Invalid group_by/, error.message)
    assert_match(/family:docdb, family:dwpi/, error.message)
  end

  def test_group_by_validation_with_invalid_family_value
    # Arrange
    search = Rospatent::Search.new(@client)

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      search.execute(q: "test", group_by: "family:invalid")
    end

    assert_includes error.message, "Invalid group_by. Allowed values: family:docdb, family:dwpi"
  end

  def test_execute_with_include_facets_true
    # Arrange - include_facets: true should convert to include_facets: 1 in API payload
    expected_payload = {
      q: "test",
      include_facets: 1
    }

    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", include_facets: true)

    # Assert
    @client_mock.verify
  end

  def test_execute_with_include_facets_false
    # Arrange - include_facets: false should convert to include_facets: 0 in API payload
    expected_payload = {
      q: "test",
      include_facets: 0
    }

    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", include_facets: false)

    # Assert
    @client_mock.verify
  end

  def test_include_facets_validation_with_truthy_string_values
    # Arrange - string "true" should convert to 1
    expected_payload = {
      q: "test",
      include_facets: 1
    }

    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", include_facets: "true")

    # Assert
    @client_mock.verify
  end

  def test_include_facets_validation_with_numeric_one
    # Arrange - numeric 1 should convert to 1
    expected_payload = {
      q: "test",
      include_facets: 1
    }

    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", include_facets: 1)

    # Assert
    @client_mock.verify
  end

  def test_include_facets_validation_with_string_false
    # Arrange - string "false" should convert to 0
    expected_payload = {
      q: "test",
      include_facets: 0
    }

    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", include_facets: "false")

    # Assert
    @client_mock.verify
  end

  def test_include_facets_validation_with_numeric_zero
    # Arrange - numeric 0 should convert to 0
    expected_payload = {
      q: "test",
      include_facets: 0
    }

    response_data = { "total" => 0, "available" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    @search.execute(q: "test", include_facets: 0)

    # Assert
    @client_mock.verify
  end

  def test_filter_validation_with_valid_authors_filter
    # Arrange
    filter = { "authors" => { "values" => ["Гультяев Александр Михайлович (RU)"] } }
    expected_payload = {
      q: "test",
      filter: { "authors" => { "values" => ["Гультяев Александр Михайлович (RU)"] } }
    }
    response_data = { "total" => 0, "available" => 0, "count" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    result = @search.execute(q: "test", filter: filter)

    # Assert
    assert_instance_of Rospatent::SearchResult, result
    @client_mock.verify
  end

  def test_filter_validation_with_valid_country_filter
    # Arrange
    filter = { "country" => { "values" => %w[RU SU] } }
    expected_payload = {
      q: "test",
      filter: { "country" => { "values" => %w[RU SU] } }
    }
    response_data = { "total" => 0, "available" => 0, "count" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    result = @search.execute(q: "test", filter: filter)

    # Assert
    assert_instance_of Rospatent::SearchResult, result
    @client_mock.verify
  end

  def test_filter_validation_with_valid_classification_ipc_filter
    # Arrange
    filter = { "classification.ipc" => { "values" => ["F02K9/00"] } }
    expected_payload = {
      q: "test",
      filter: { "classification.ipc" => { "values" => ["F02K9/00"] } }
    }
    response_data = { "total" => 0, "available" => 0, "count" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    result = @search.execute(q: "test", filter: filter)

    # Assert
    assert_instance_of Rospatent::SearchResult, result
    @client_mock.verify
  end

  def test_filter_validation_with_valid_date_published_range
    # Arrange
    filter = { "date_published" => { "range" => { "gt" => "20000101" } } }
    expected_payload = {
      q: "test",
      filter: { "date_published" => { "range" => { "gt" => "20000101" } } }
    }
    response_data = { "total" => 0, "available" => 0, "count" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    result = @search.execute(q: "test", filter: filter)

    # Assert
    assert_instance_of Rospatent::SearchResult, result
    @client_mock.verify
  end

  def test_filter_validation_with_valid_application_filing_date_range
    # Arrange
    filter = { "application.filing_date" => { "range" => { "lte" => "20000101" } } }
    expected_payload = {
      q: "test",
      filter: { "application.filing_date" => { "range" => { "lte" => "20000101" } } }
    }
    response_data = { "total" => 0, "available" => 0, "count" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    result = @search.execute(q: "test", filter: filter)

    # Assert
    assert_instance_of Rospatent::SearchResult, result
    @client_mock.verify
  end

  def test_filter_validation_converts_date_formats_in_search
    # Arrange
    filter = { "date_published" => { "range" => { "gte" => "2020-01-01" } } }
    expected_payload = {
      q: "test",
      filter: { "date_published" => { "range" => { "gte" => "20200101" } } }
    }
    response_data = { "total" => 0, "available" => 0, "count" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    result = @search.execute(q: "test", filter: filter)

    # Assert
    assert_instance_of Rospatent::SearchResult, result
    @client_mock.verify
  end

  def test_filter_validation_with_complex_multi_field_filter
    # Arrange
    filter = {
      "country" => { "values" => %w[RU SU] },
      "classification.ipc" => { "values" => ["F02K9/00"] },
      "date_published" => { "range" => { "gte" => "20000101", "lt" => "20201231" } }
    }
    expected_payload = {
      q: "test",
      filter: {
        "country" => { "values" => %w[RU SU] },
        "classification.ipc" => { "values" => ["F02K9/00"] },
        "date_published" => { "range" => { "gte" => "20000101", "lt" => "20201231" } }
      }
    }
    response_data = { "total" => 0, "available" => 0, "count" => 0, "hits" => [] }

    # Mock expectations
    @client_mock.expect :post, response_data, ["/patsearch/v0.2/search", expected_payload]

    # Act
    result = @search.execute(q: "test", filter: filter)

    # Assert
    assert_instance_of Rospatent::SearchResult, result
    @client_mock.verify
  end

  def test_filter_validation_rejects_invalid_field
    # Arrange
    filter = { "invalid_field" => { "values" => ["test"] } }

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      @search.execute(q: "test", filter: filter)
    end

    assert_includes error.message, "Invalid filter field 'invalid_field'"
    assert_includes error.message, "Allowed fields:"
  end

  def test_filter_validation_rejects_missing_values_key
    # Arrange
    filter = { "authors" => { "data" => ["test"] } }

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      @search.execute(q: "test", filter: filter)
    end

    assert_includes error.message, "Missing required 'values' key in authors filter"
  end

  def test_filter_validation_rejects_empty_values_array
    # Arrange
    filter = { "country" => { "values" => [] } }

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      @search.execute(q: "test", filter: filter)
    end

    assert_includes error.message, "Empty 'values' array in country filter"
  end

  def test_filter_validation_rejects_missing_range_key
    # Arrange
    filter = { "date_published" => { "from" => "20200101" } } # OLD WRONG FORMAT

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      @search.execute(q: "test", filter: filter)
    end

    assert_includes error.message, "Missing required 'range' key in date_published filter"
  end

  def test_filter_validation_rejects_invalid_range_operator
    # Arrange
    filter = { "date_published" => { "range" => { "from" => "20200101" } } } # WRONG OPERATOR

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      @search.execute(q: "test", filter: filter)
    end

    assert_includes error.message, "Invalid range operator 'from' in date_published filter"
    assert_includes error.message, "Allowed operators: gt, gte, lt, lte"
  end

  def test_filter_validation_rejects_invalid_date_format
    # Arrange
    filter = { "date_published" => { "range" => { "gt" => "invalid-date" } } }

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      @search.execute(q: "test", filter: filter)
    end

    assert_includes error.message, "Invalid date format 'invalid-date'"
  end

  def test_filter_validation_rejects_invalid_date_value
    # Arrange
    filter = { "date_published" => { "range" => { "gt" => "20200230" } } } # February 30th

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      @search.execute(q: "test", filter: filter)
    end

    assert_includes error.message, "Invalid date '20200230'"
  end
end
