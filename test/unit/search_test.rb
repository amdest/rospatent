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

    expected_payload = {
      q: "test",
      qn: "natural language query",
      limit: 20,
      offset: 30,
      highlight: true,
      pre_tag: "<mark>",
      post_tag: "</mark>",
      sort: "publication_date:desc",
      group_by: "patent_family",
      include_facets: true,
      filter: filter,
      datasets: datasets
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
      group_by: :patent_family,
      include_facets: true,
      filter: filter,
      datasets: datasets,
      highlight: true
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
    expected_payload = { q: "test", highlight: false }

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
end
