# frozen_string_literal: true

require_relative "../test_helper"

class FullWorkflowTest < Minitest::Test
  def setup
    skip unless ENV["ROSPATENT_INTEGRATION_TESTS"]

    @token = ENV.fetch("ROSPATENT_TEST_TOKEN", nil)
    skip "ROSPATENT_TEST_TOKEN not set" unless @token

    # Configure with test settings
    Rospatent.configure do |config|
      config.token = @token
      config.environment = "development"
      config.cache_enabled = true
      config.cache_ttl = 60
      config.log_level = :debug
    end

    @client = Rospatent.client
  end

  def teardown
    # Clear shared resources after tests
    Rospatent.clear_shared_resources if ENV["ROSPATENT_INTEGRATION_TESTS"]
  end

  def test_full_search_and_retrieval_workflow
    # Step 1: Perform a search
    results = @client.search(q: "ракета", limit: 5)

    assert results.any?, "Search should return results"
    assert_operator results.count, :>, 0
    assert_operator results.total, :>, 0

    # Step 2: Get the first patent document
    first_hit = results.hits.first
    assert first_hit, "First hit should exist"

    doc_id = first_hit["id"]
    assert doc_id, "Document ID should be present"

    patent_doc = @client.patent(doc_id)
    assert patent_doc, "Patent document should be retrieved"

    # Step 3: Parse patent content
    abstract = @client.parse_abstract(patent_doc)
    description = @client.parse_description(patent_doc)

    # At least one should be present
    assert(abstract || description, "Either abstract or description should be present")

    # Step 4: Test caching - second request should be faster
    start_time = Time.now
    cached_patent = @client.patent(doc_id)
    cache_duration = Time.now - start_time

    assert_equal patent_doc, cached_patent, "Cached result should match original"
    assert_operator cache_duration, :<, 0.1, "Cached request should be fast"
  end

  def test_similar_patents_workflow
    # Use a known working patent ID for testing
    test_patent_id = "RU134694U1_20131120"

    # Test similar patents by ID
    begin
      similar_results = @client.similar_patents_by_id(test_patent_id, count: 10)
      assert similar_results, "Similar patents should be found"
      assert similar_results.key?("total"), "Response should have total count"
      assert similar_results.key?("data"), "Response should have data array"
      puts "✓ Similar patents by ID: found #{similar_results['total']} total results"
    rescue Rospatent::Errors::ApiError, Rospatent::Errors::ConnectionError => e
      skip "Similar patents by ID endpoint not available (#{e.message})"
    end

    # Test similar patents by text
    begin
      similar_by_text = @client.similar_patents_by_text("трансформатор тока", count: 5)
      assert similar_by_text, "Similar patents by text should be found"
      assert similar_by_text.key?("total"), "Response should have total count"
      assert similar_by_text.key?("data"), "Response should have data array"
      puts "✓ Similar patents by text: found #{similar_by_text['total']} total results"
    rescue Rospatent::Errors::ApiError, Rospatent::Errors::ConnectionError,
           Rospatent::Errors::ServiceUnavailableError => e
      skip "Similar patents by text endpoint not available (#{e.message})"
    end
  end

  def test_datasets_and_media_workflow
    # Test datasets retrieval

    datasets = @client.datasets_tree
    assert datasets, "Datasets should be retrieved"
    assert datasets.is_a?(Array), "Datasets should be an array"

    # Find a National collection for media testing
    national_collection = find_national_collection(datasets)

    return unless national_collection

    test_patent_id = find_valid_patent_id
    skip "No valid patent ID for media testing" unless test_patent_id

    begin
      # Try to get PDF document
      pdf_data = @client.patent_media_by_id(
        test_patent_id,
        "National",
        "document.pdf"
      )

      assert pdf_data, "PDF data should be retrieved"
      assert pdf_data.is_a?(String), "PDF data should be binary string"
      assert_operator pdf_data.length, :>, 0, "PDF should have content"
    rescue Rospatent::Errors::NotFoundError
      # Media file might not exist for this patent, which is acceptable
      puts "Note: Media file not found for patent #{test_patent_id}"
    end
  rescue JSON::ParserError, Rospatent::Errors::ApiError => e
    skip "Datasets endpoint not available or returns invalid response (#{e.class}: #{e.message})"
  end

  def test_batch_operations
    test_ids = find_multiple_patent_ids(3)
    skip "Not enough patent IDs for batch testing" if test_ids.length < 2

    results = []
    @client.batch_patents(test_ids) do |patent_doc|
      results << patent_doc
    end

    assert_equal test_ids.length, results.length, "Should get result for each ID"

    # Check that results are either valid patent docs or error hashes
    results.each do |result|
      assert(result.is_a?(Hash), "Each result should be a hash")
      # Either it's a patent document or an error
      assert(result.key?("id") || result.key?(:error), "Result should have ID or error")
    end
  end

  def test_error_handling_workflow
    # Test with invalid patent ID
    assert_raises(Rospatent::Errors::ValidationError) do
      @client.patent("INVALID_ID_FORMAT")
    end

    # Test with non-existent but valid format patent ID
    assert_raises(Rospatent::Errors::NotFoundError) do
      @client.patent("XX999999Z9_99999999")
    end

    # Test search with invalid parameters
    assert_raises(Rospatent::Errors::ValidationError) do
      @client.search(q: "", limit: 0)
    end
  end

  def test_caching_effectiveness
    test_patent_id = find_valid_patent_id
    skip "No valid patent ID for caching test" unless test_patent_id

    # Clear any existing cache
    @client.instance_variable_get(:@cache).clear

    # First request - should be cache miss
    start_time = Time.now
    first_result = @client.patent(test_patent_id)
    first_duration = Time.now - start_time

    # Second request - should be cache hit
    start_time = Time.now
    second_result = @client.patent(test_patent_id)
    second_duration = Time.now - start_time

    assert_equal first_result, second_result, "Results should be identical"
    assert_operator second_duration, :<, first_duration * 0.5, "Cache hit should be faster"

    # Check cache statistics
    stats = @client.statistics
    assert_operator stats[:cache_stats][:hits], :>, 0, "Should have cache hits"
  end

  def test_configuration_validation
    errors = Rospatent.validate_configuration
    assert_empty errors, "Configuration should be valid: #{errors.join(', ')}"
  end

  def test_logging_functionality
    # Create a custom logger to capture logs
    log_output = StringIO.new
    custom_logger = Rospatent::Logger.new(output: log_output, level: :debug)

    client_with_logger = Rospatent.client(logger: custom_logger)

    # Perform an operation that should generate logs
    client_with_logger.search(q: "test", limit: 1)

    log_content = log_output.string
    assert_match(/API Request/, log_content, "Should log API requests")
    assert_match(/API Response/, log_content, "Should log API responses")
  end

  def test_client_statistics
    stats = @client.statistics

    assert stats.key?(:requests_made), "Should track requests made"
    assert stats.key?(:total_duration_seconds), "Should track total duration"
    assert stats.key?(:average_request_time), "Should calculate average request time"
    assert stats.key?(:cache_stats), "Should include cache statistics"

    assert stats[:requests_made].is_a?(Integer), "Requests made should be integer"
    assert stats[:total_duration_seconds].is_a?(Numeric), "Duration should be numeric"
  end

  private

  def find_valid_patent_id
    # Try to find a valid patent ID by doing a search
    begin
      results = @client.search(q: "изобретение", limit: 1)
      return nil unless results.any?

      first_hit = results.hits.first
      return first_hit["id"] if first_hit && first_hit["id"]
    rescue StandardError => e
      puts "Warning: Could not find valid patent ID: #{e.message}"
    end

    nil
  end

  def find_multiple_patent_ids(count)
    results = @client.search(q: "устройство", limit: count)
    return [] unless results.any?

    results.hits.map { |hit| hit["id"] }.compact.first(count)
  rescue StandardError => e
    puts "Warning: Could not find multiple patent IDs: #{e.message}"
    []
  end

  def find_national_collection(datasets)
    datasets.find { |dataset| dataset["id"] == "National" }
  end
end
