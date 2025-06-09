# frozen_string_literal: true

require "test_helper"

class ClientTest < Minitest::Test
  def test_initialization_with_token
    # Arrange
    custom_token = "custom_test_token"

    # Act
    client = Rospatent::Client.new(token: custom_token)

    # Assert - we can't directly test the token as it's a private instance variable,
    # but we can test that initialization succeeds without error
    assert client, "Client should initialize successfully with a valid token"
  end

  def test_initialization_with_config_token
    # Arrange & Act
    client = Rospatent::Client.new

    # Assert - using the test_helper setup which configures a token
    assert client, "Client should initialize successfully with configuration token"
  end

  def test_initialization_without_token_raises_error
    # Arrange
    Rospatent.reset # Clear the configuration token

    # Act & Assert
    error = assert_raises(Rospatent::Errors::MissingTokenError) do
      Rospatent::Client.new
    end

    assert_equal "API token is required", error.message, "Should raise appropriate error message"
  end

  def test_search_method_creates_search_instance
    # Arrange
    client = Rospatent::Client.new

    # Create a simple search class for testing
    test_search_class = Class.new do
      attr_reader :client, :execute_params

      def initialize(client)
        @client = client
      end

      def execute(**params)
        @execute_params = params
        "search result"
      end
    end

    original_search_class = Rospatent::Search
    Rospatent.send(:remove_const, :Search)
    Rospatent.const_set(:Search, test_search_class)

    # Act
    result = client.search(q: "test")

    # Assert
    assert_equal "search result", result, "Should return the search result"
    search_instance = Rospatent::Search.new(client)
    assert_equal client, search_instance.client, "Search should be initialized with the client"

    # Restore original class
    Rospatent.send(:remove_const, :Search)
    Rospatent.const_set(:Search, original_search_class)
  end

  def test_search_method_passes_filter_parameter
    # Arrange
    client = Rospatent::Client.new
    filter = { "application.filing_date" => { "range" => { "gte" => "20200101" } } }

    # Mock the Search class to capture the parameters
    original_search_class = Rospatent::Search

    # Create a mock search class
    mock_search_class = Class.new do
      def initialize(client)
        @client = client
      end

      def execute(**params)
        # This is what we want to test - that the filter gets through
        Thread.current[:captured_params] = params
        "search result"
      end
    end

    Rospatent.send(:remove_const, :Search)
    Rospatent.const_set(:Search, mock_search_class)

    # Act
    client.search(q: "test", filter: filter)

    # Assert
    captured_params = Thread.current[:captured_params]
    refute_nil captured_params, "Should have captured execute parameters"
    assert_equal filter, captured_params[:filter], "Should pass filter parameter to search execute method"
    assert_equal "test", captured_params[:q], "Should pass query parameter"

    # Restore original class
    Rospatent.send(:remove_const, :Search)
    Rospatent.const_set(:Search, original_search_class)
  end

  def test_post_with_connection_error
    # Arrange
    client = Rospatent::Client.new

    # Create a stub for connection that raises an error
    connection_stub = Object.new
    def connection_stub.post(*)
      raise Faraday::ConnectionFailed, "Connection error"
    end

    def connection_stub.headers
      {}
    end

    # Override the private connection method
    client.instance_variable_set(:@connection, connection_stub)

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ConnectionError) do
      client.post("/search", {})
    end

    assert_match(/Connection error/, error.message, "Should wrap Faraday errors in ConnectionError")
  end

  def test_patent_successful
    # Arrange
    client = Rospatent::Client.new
    document_id = "RU123456A1_20131120"
    expected_endpoint = "/patsearch/v0.2/docs/#{document_id}"
    expected_response = { "common" => { "document_number" => document_id } }

    # Mock the get method
    client.stub :get, lambda { |endpoint|
      assert_equal expected_endpoint, endpoint, "Should call the correct endpoint"
      expected_response
    } do
      # Act
      result = client.patent(document_id)

      # Assert
      assert_equal expected_response, result, "Should return the patent data"
    end
  end

  def test_patent_with_nil_id
    # Arrange
    client = Rospatent::Client.new

    # Act & Assert
    error = assert_raises(Rospatent::Errors::InvalidRequestError) do
      client.patent(nil)
    end

    assert_equal "Document_id is required", error.message, "Should raise appropriate error message"
  end

  def test_patent_with_empty_id
    # Arrange
    client = Rospatent::Client.new

    # Act & Assert
    error = assert_raises(Rospatent::Errors::InvalidRequestError) do
      client.patent("")
    end

    assert_equal "Document_id cannot be empty", error.message,
                 "Should raise appropriate error message"
  end

  def test_patent_with_invalid_format
    # Arrange
    client = Rospatent::Client.new
    invalid_ids = [
      "RU123", # Too short
      "RU12345",           # No doc type
      "RU12345A_123",      # Date too short
      "RU12345A_1234567",  # Date wrong format
      "12345A1_20220101",  # Missing country code
      "RU12345_20220101"   # Missing doc type
    ]

    # Act & Assert
    invalid_ids.each do |invalid_id|
      error = assert_raises(Rospatent::Errors::InvalidRequestError,
                            "Should reject #{invalid_id}") do
        client.patent(invalid_id)
      end

      assert_equal "Invalid patent ID format. Expected format: 'XX12345Y1_YYYYMMDD' (country code + alphanumeric publication number + document type + date)",
                   error.message
    end
  end

  def test_patent_by_components
    # Arrange
    client = Rospatent::Client.new
    country_code = "RU"
    number = "134694"
    doc_type = "U1"
    date = "2013-11-20"
    expected_response = { "title" => "Test Patent" }

    # Mock the get method that will be called by patent
    # Mock the get method
    client.stub :get, lambda { |endpoint|
      assert_equal "/patsearch/v0.2/docs/RU134694U1_20131120", endpoint, "Should construct correct ID and call endpoint"
      expected_response
    } do
      # Act
      result = client.patent_by_components(country_code, number, doc_type, date)

      # Assert
      assert_equal expected_response, result, "Should return the expected response"
    end
  end

  def test_patent_by_components_with_date_object
    # Arrange
    client = Rospatent::Client.new
    country_code = "RU"
    number = "134694"
    doc_type = "U1"
    date = Date.new(2013, 11, 20)
    expected_id = "RU134694U1_20131120"
    expected_response = { "title" => "Test Patent" }

    # Mock the get method that will be called by patent
    client.stub :get, lambda { |endpoint|
      assert_equal "/patsearch/v0.2/docs/#{expected_id}", endpoint, "Should format Date object correctly"
      expected_response
    } do
      # Act
      result = client.patent_by_components(country_code, number, doc_type, date)

      # Assert
      assert_equal expected_response, result, "Should return the expected response"
    end
  end

  def test_patent_api_error
    # Arrange
    client = Rospatent::Client.new
    document_id = "RU123456A1_20131120"

    # Stub the get method to simulate API error
    client.stub :get, ->(*) { raise Rospatent::Errors::ApiError.new("Document not found", 404) } do
      # Act & Assert
      error = assert_raises(Rospatent::Errors::ApiError) do
        client.patent(document_id)
      end

      assert_equal 404, error.status_code, "Should preserve status code"
      assert_equal "API Error (404): Document not found", error.to_s, "Should format error message"
    end
  end

  def test_similar_patents_by_id
    # Arrange
    client = Rospatent::Client.new
    document_id = "RU2358138C1_20090610"
    expected_payload = {
      type_search: "id_search",
      pat_id: document_id,
      count: 100
    }
    expected_response = { "total" => 5, "hits" => [] }

    # Mock the post method
    client.stub :post_with_redirects, lambda { |path, payload|
      assert_equal "/patsearch/v0.2/similar_search", path, "Should call correct endpoint"
      assert_equal expected_payload, payload, "Should create correct payload"
      expected_response
    } do
      # Act
      result = client.similar_patents_by_id(document_id)

      # Assert
      assert_equal expected_response, result, "Should return the similar search results"
    end
  end

  def test_similar_patents_by_id_with_custom_count
    # Arrange
    client = Rospatent::Client.new
    document_id = "RU2358138C1_20090610"
    count = 50
    expected_payload = {
      type_search: "id_search",
      pat_id: document_id,
      count: count
    }
    expected_response = { "total" => 5, "hits" => [] }

    # Mock the post method
    client.stub :post_with_redirects, lambda { |path, payload|
      assert_equal "/patsearch/v0.2/similar_search", path, "Should call correct endpoint"
      assert_equal expected_payload, payload, "Should create correct payload"
      expected_response
    } do
      # Act
      result = client.similar_patents_by_id(document_id, count: count)

      # Assert
      assert_equal expected_response, result, "Should return the similar search results"
    end
  end

  def test_similar_patents_by_text
    # Arrange
    client = Rospatent::Client.new
    # Text with at least 50 words for the API requirement
    text = "Двигатель внутреннего сгорания содержит турбокомпрессор с компрессором и турбиной, " \
           "которые соединены валом, причем компрессор имеет рабочее колесо с лопатками переменной " \
           "геометрии, а турбина выполнена с возможностью регулирования угла установки лопаток " \
           "направляющего аппарата, при этом система управления двигателем включает электронный " \
           "блок управления, датчики температуры и давления, исполнительные механизмы для изменения " \
           "положения лопаток компрессора и турбины, а также систему охлаждения наддувочного воздуха"
    expected_payload = {
      type_search: "text_search",
      pat_text: text,
      count: 100
    }
    expected_response = { "total" => 5, "hits" => [] }

    # Mock the post method
    client.stub :post_with_redirects, lambda { |path, payload|
      assert_equal "/patsearch/v0.2/similar_search", path, "Should call correct endpoint"
      assert_equal expected_payload, payload, "Should create correct payload"
      expected_response
    } do
      # Act
      result = client.similar_patents_by_text(text)

      # Assert
      assert_equal expected_response, result, "Should return the similar search results"
    end
  end

  def test_similar_patents_by_text_with_custom_count
    # Arrange
    client = Rospatent::Client.new
    # Text with at least 50 words for the API requirement
    text = "Двигатель внутреннего сгорания содержит турбокомпрессор с компрессором и турбиной, " \
           "которые соединены валом, причем компрессор имеет рабочее колесо с лопатками переменной " \
           "геометрии, а турбина выполнена с возможностью регулирования угла установки лопаток " \
           "направляющего аппарата, при этом система управления двигателем включает электронный " \
           "блок управления, датчики температуры и давления, исполнительные механизмы для изменения " \
           "положения лопаток компрессора и турбины, а также систему охлаждения наддувочного воздуха"
    count = 50
    expected_payload = {
      type_search: "text_search",
      pat_text: text,
      count: count
    }
    expected_response = { "total" => 5, "hits" => [] }

    # Mock the post method
    client.stub :post_with_redirects, lambda { |path, payload|
      assert_equal "/patsearch/v0.2/similar_search", path, "Should call correct endpoint"
      assert_equal expected_payload, payload, "Should create correct payload"
      expected_response
    } do
      # Act
      result = client.similar_patents_by_text(text, count: count)

      # Assert
      assert_equal expected_response, result, "Should return the similar search results"
    end
  end

  def test_similar_patents_by_id_with_empty_id
    # Arrange
    client = Rospatent::Client.new

    # Act & Assert
    error = assert_raises(Rospatent::Errors::InvalidRequestError) do
      client.similar_patents_by_id("")
    end

    assert_equal "Document_id cannot be empty", error.message,
                 "Should raise appropriate error message"
  end

  def test_similar_patents_by_text_with_empty_text
    # Arrange
    client = Rospatent::Client.new

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      client.similar_patents_by_text("")
    end

    assert_equal "Search_text cannot be empty", error.message,
                 "Should raise appropriate error message"
  end

  def test_similar_patents_by_text_with_insufficient_words
    # Arrange
    client = Rospatent::Client.new
    short_text = "This text has only seven words total here"

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      client.similar_patents_by_text(short_text)
    end

    assert_match(/must contain at least 50 words/, error.message,
                 "Should require at least 50 words")
    assert_match(/currently has 8/, error.message,
                 "Should show current word count")
  end

  def test_datasets_tree
    # Arrange
    client = Rospatent::Client.new
    expected_response = [
      {
        "id" => "ru",
        "title" => "Российские документы",
        "children" => [
          { "id" => "ru_A", "title" => "Заявки на изобретения" },
          { "id" => "ru_C", "title" => "Патенты на изобретения" }
        ]
      },
      {
        "id" => "foreign",
        "title" => "Зарубежные документы"
      }
    ]

    # Mock the get method
    client.stub :get, lambda { |path, params = {}, binary: false|
      assert_equal "/patsearch/v0.2/datasets/tree", path, "Should call correct endpoint"
      assert_equal({}, params, "Should pass empty params")
      refute binary, "Should request JSON data for datasets"
      expected_response
    } do
      # Act
      result = client.datasets_tree

      # Assert
      assert_equal expected_response, result, "Should return the datasets tree structure"
    end
  end

  def test_patent_media_with_string_date
    # Arrange
    client = Rospatent::Client.new
    collection_id = "National"
    country_code = "RU"
    doc_type = "U1"
    pub_date = "2013/11/20"
    pub_number = "0000134694"
    filename = "document.pdf"
    expected_pdf_content = "PDF binary content"
    expected_path = "/media/National/RU/U1/2013/11/20/0000134694/document.pdf"

    # Mock the get method
    client.stub :get, lambda { |endpoint, params = {}, binary: false|
      assert_equal expected_path, endpoint, "Should construct the correct path with string date"
      assert_equal({}, params, "Should pass empty params")
      assert binary, "Should request binary data for media"
      expected_pdf_content
    } do
      # Act
      result = client.patent_media(collection_id, country_code, doc_type, pub_date, pub_number,
                                   filename)

      # Assert
      assert_equal expected_pdf_content, result, "Should return the PDF content"
    end
  end

  def test_patent_media_with_date_object
    # Arrange
    client = Rospatent::Client.new
    collection_id = "National"
    country_code = "RU"
    doc_type = "U1"
    pub_date = Date.new(2013, 11, 20)
    pub_number = "0000134694"
    filename = "document.pdf"
    expected_pdf_content = "PDF binary content"
    expected_path = "/media/National/RU/U1/2013/11/20/0000134694/document.pdf"

    # Mock the get method
    client.stub :get, lambda { |endpoint, params = {}, binary: false|
      assert_equal expected_path, endpoint, "Should correctly format Date object to string path"
      assert_equal({}, params, "Should pass empty params")
      assert binary, "Should request binary data for media"
      expected_pdf_content
    } do
      # Act
      result = client.patent_media(collection_id, country_code, doc_type, pub_date, pub_number,
                                   filename)

      # Assert
      assert_equal expected_pdf_content, result, "Should return the PDF content"
    end
  end

  def test_patent_media_with_different_file_types
    # Arrange
    client = Rospatent::Client.new
    collection_id = "National"
    country_code = "RU"
    doc_type = "U1"
    pub_date = "2013/11/20"
    pub_number = "0000134694"
    filename = "figure1.jpg"
    expected_content = "JPEG binary content"
    expected_path = "/media/National/RU/U1/2013/11/20/0000134694/figure1.jpg"

    # Mock the get method
    client.stub :get, lambda { |endpoint, params = {}, binary: false|
      assert_equal expected_path, endpoint, "Should construct the correct path for different file types"
      assert_equal({}, params, "Should pass empty params")
      assert binary, "Should request binary data for media"
      expected_content
    } do
      # Act
      result = client.patent_media(collection_id, country_code, doc_type, pub_date, pub_number,
                                   filename)

      # Assert
      assert_equal expected_content, result, "Should return the image content"
    end
  end

  def test_patent_media_with_missing_parameters
    # Arrange
    client = Rospatent::Client.new

    # Act & Assert - Test each required parameter with nil values
    assert_raises(Rospatent::Errors::ValidationError, "Should validate collection_id") do
      client.patent_media(nil, "RU", "U1", "2013/11/20", "134694", "document.pdf")
    end

    assert_raises(Rospatent::Errors::ValidationError, "Should validate country_code") do
      client.patent_media("National", nil, "U1", "2013/11/20", "134694", "document.pdf")
    end

    assert_raises(Rospatent::Errors::ValidationError, "Should validate doc_type") do
      client.patent_media("National", "RU", nil, "2013/11/20", "134694", "document.pdf")
    end

    assert_raises(Rospatent::Errors::ValidationError, "Should validate pub_date") do
      client.patent_media("National", "RU", "U1", nil, "134694", "document.pdf")
    end

    assert_raises(Rospatent::Errors::ValidationError, "Should validate pub_number") do
      client.patent_media("National", "RU", "U1", "2013/11/20", nil, "document.pdf")
    end

    # Filename is now optional, so we test validation when explicitly providing empty string
    assert_raises(Rospatent::Errors::ValidationError, "Should validate filename when provided as empty string") do
      client.patent_media("National", "RU", "U1", "2013/11/20", "134694", "")
    end
  end

  def test_patent_media_by_id
    # Arrange
    client = Rospatent::Client.new
    document_id = "RU134694U1_20131120"
    collection_id = "National"
    filename = "document.pdf"
    expected_content = "PDF binary content"
    expected_path = "/media/National/RU/U1/2013/11/20/0000134694/document.pdf"

    # Mock the get method
    client.stub :get, lambda { |endpoint, params = {}, binary: false|
      assert_equal expected_path, endpoint, "Should construct the correct path from patent ID with padded number"
      assert_equal({}, params, "Should pass empty params")
      assert binary, "Should request binary data for media"
      expected_content
    } do
      # Act
      result = client.patent_media_by_id(document_id, collection_id, filename)

      # Assert
      assert_equal expected_content, result, "Should return the media content"
    end
  end

  def test_patent_media_by_id_with_invalid_id
    # Arrange
    client = Rospatent::Client.new
    invalid_id = "RU12345_20220101" # Missing doc type code
    collection_id = "National"
    filename = "document.pdf"

    # Act & Assert
    error = assert_raises(Rospatent::Errors::InvalidRequestError) do
      client.patent_media_by_id(invalid_id, collection_id, filename)
    end

    assert_equal "Invalid patent ID format. Expected format: 'XX12345Y1_YYYYMMDD' (country code + alphanumeric publication number + document type + date)",
                 error.message
  end

  def test_patent_media_by_id_with_missing_parameters
    # Arrange
    client = Rospatent::Client.new
    document_id = "RU134694U1_20131120"

    # Act & Assert
    assert_raises(Rospatent::Errors::ValidationError, "Should validate collection_id") do
      client.patent_media_by_id(document_id, nil, "document.pdf")
    end

    # Filename is now optional, so we test validation when explicitly providing empty string
    assert_raises(Rospatent::Errors::ValidationError, "Should validate filename when provided as empty string") do
      client.patent_media_by_id(document_id, "National", "")
    end

    assert_raises(Rospatent::Errors::ValidationError, "Should validate document_id") do
      client.patent_media_by_id("", "National", "document.pdf")
    end
  end

  def test_patent_media_with_auto_generated_filename
    # Arrange
    client = Rospatent::Client.new
    collection_id = "National"
    country_code = "RU"
    doc_type = "U1"
    pub_date = "2013/11/20"
    pub_number = "134694"
    expected_pdf_content = "PDF binary content"
    # Auto-generated filename should be the formatted number + .pdf
    expected_path = "/media/National/RU/U1/2013/11/20/0000134694/0000134694.pdf"

    # Mock the get method
    client.stub :get, lambda { |endpoint, params = {}, binary: false|
      assert_equal expected_path, endpoint, "Should construct path with auto-generated filename"
      assert_equal({}, params, "Should pass empty params")
      assert binary, "Should request binary data for media"
      expected_pdf_content
    } do
      # Act - Call without filename parameter
      result = client.patent_media(collection_id, country_code, doc_type, pub_date, pub_number)

      # Assert
      assert_equal expected_pdf_content, result, "Should return the PDF content"
    end
  end

  def test_patent_media_by_id_with_auto_generated_filename
    # Arrange
    client = Rospatent::Client.new
    document_id = "RU134694U1_20131120"
    collection_id = "National"
    expected_content = "PDF binary content"
    # Auto-generated filename should be the formatted number + .pdf
    expected_path = "/media/National/RU/U1/2013/11/20/0000134694/0000134694.pdf"

    # Mock the get method
    client.stub :get, lambda { |endpoint, params = {}, binary: false|
      assert_equal expected_path, endpoint, "Should construct path with auto-generated filename from patent ID"
      assert_equal({}, params, "Should pass empty params")
      assert binary, "Should request binary data for media"
      expected_content
    } do
      # Act - Call without filename parameter
      result = client.patent_media_by_id(document_id, collection_id)

      # Assert
      assert_equal expected_content, result, "Should return the media content"
    end
  end

  def test_classification_search_with_ipc
    # Arrange
    client = Rospatent::Client.new
    classifier_id = "ipc"
    query = "ракета"
    lang = "ru"
    expected_payload = {
      query: query,
      lang: lang
    }
    expected_response = {
      "total" => 5,
      "hits" => [
        { "code" => "F02K9/00", "description" => "Ракетные двигатели" }
      ]
    }

    # Mock the post method to verify the endpoint and payload
    client.stub :post, lambda { |endpoint, payload|
      assert_equal "/patsearch/v0.2/classification/ipc/search/", endpoint, "Should call the correct endpoint"
      assert_equal expected_payload, payload, "Should send correct payload"
      expected_response
    } do
      # Act
      result = client.classification_search(classifier_id, query: query, lang: lang)

      # Assert
      assert_equal expected_response, result, "Should return the classification search results"
    end
  end

  def test_classification_search_with_cpc
    # Arrange
    client = Rospatent::Client.new
    classifier_id = "cpc"
    query = "rocket"
    lang = "en"
    expected_payload = {
      query: query,
      lang: lang
    }
    expected_response = {
      "total" => 3,
      "hits" => [
        { "code" => "B63H11/00", "description" => "Rocket engines" }
      ]
    }

    # Mock the post method to verify the endpoint and payload
    client.stub :post, lambda { |endpoint, payload|
      assert_equal "/patsearch/v0.2/classification/cpc/search/", endpoint, "Should call the correct endpoint"
      assert_equal expected_payload, payload, "Should send correct payload"
      expected_response
    } do
      # Act
      result = client.classification_search(classifier_id, query: query, lang: lang)

      # Assert
      assert_equal expected_response, result, "Should return the classification search results"
    end
  end

  def test_classification_search_with_invalid_classifier
    # Arrange
    client = Rospatent::Client.new

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      client.classification_search("invalid", query: "test")
    end

    assert_match(/Invalid classifier_id/, error.message, "Should validate classifier_id")
  end

  def test_classification_search_with_invalid_language
    # Arrange
    client = Rospatent::Client.new

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      client.classification_search("ipc", query: "test", lang: "invalid")
    end

    assert_match(/Invalid lang/, error.message, "Should validate language")
  end

  def test_classification_search_with_empty_query
    # Arrange
    client = Rospatent::Client.new

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      client.classification_search("ipc", query: "")
    end

    assert_match(/Query cannot be empty/, error.message, "Should validate query")
  end

  def test_classification_code_with_ipc
    # Arrange
    client = Rospatent::Client.new
    classifier_id = "ipc"
    code = "F02K9/00"
    lang = "ru"
    expected_payload = {
      code: code,
      lang: lang
    }
    expected_response = {
      "code" => "F02K9/00",
      "description" => "Ракетные двигатели",
      "hierarchy" => ["F", "F02", "F02K", "F02K9", "F02K9/00"]
    }

    # Mock the post method
    client.stub :post, lambda { |endpoint, payload|
      assert_equal "/patsearch/v0.2/classification/ipc/code/", endpoint, "Should call the correct endpoint"
      assert_equal expected_payload, payload, "Should create correct payload"
      expected_response
    } do
      # Act
      result = client.classification_code(classifier_id, code: code, lang: lang)

      # Assert
      assert_equal expected_response, result, "Should return the classification code information"
    end
  end

  def test_classification_code_with_cpc
    # Arrange
    client = Rospatent::Client.new
    classifier_id = "cpc"
    code = "B63H11/00"
    lang = "en"
    expected_payload = {
      code: code,
      lang: lang
    }
    expected_response = {
      "code" => "B63H11/00",
      "description" => "Rocket engines",
      "hierarchy" => ["B", "B63", "B63H", "B63H11", "B63H11/00"]
    }

    # Mock the post method
    client.stub :post, lambda { |endpoint, payload|
      assert_equal "/patsearch/v0.2/classification/cpc/code/", endpoint, "Should call the correct endpoint"
      assert_equal expected_payload, payload, "Should create correct payload"
      expected_response
    } do
      # Act
      result = client.classification_code(classifier_id, code: code, lang: lang)

      # Assert
      assert_equal expected_response, result, "Should return the classification code information"
    end
  end

  def test_classification_code_with_invalid_classifier
    # Arrange
    client = Rospatent::Client.new

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      client.classification_code("invalid", code: "F02K9/00")
    end

    assert_match(/Invalid classifier_id/, error.message, "Should validate classifier_id")
  end

  def test_classification_code_with_empty_code
    # Arrange
    client = Rospatent::Client.new

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      client.classification_code("ipc", code: "")
    end

    assert_match(/Code cannot be empty/, error.message, "Should validate code")
  end

  def test_classification_code_with_invalid_language
    # Arrange
    client = Rospatent::Client.new

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ValidationError) do
      client.classification_code("ipc", code: "F02K9/00", lang: "invalid")
    end

    assert_match(/Invalid lang/, error.message, "Should validate language")
  end

  def test_format_publication_number_with_russian_short_number
    # Arrange
    client = Rospatent::Client.new

    # Act - Access private method for testing
    result = client.send(:format_publication_number, "134694", "RU")

    # Assert
    assert_equal "0000134694", result, "Should pad Russian numbers to 10 digits"
  end

  def test_format_publication_number_with_russian_long_number
    # Arrange
    client = Rospatent::Client.new

    # Act - Access private method for testing
    result = client.send(:format_publication_number, "1234567890", "RU")

    # Assert
    assert_equal "1234567890", result, "Should not modify Russian numbers that are already 10+ digits"
  end

  def test_format_publication_number_with_non_russian_number
    # Arrange
    client = Rospatent::Client.new

    # Act - Access private method for testing
    result = client.send(:format_publication_number, "123456", "US")

    # Assert
    assert_equal "123456", result, "Should not pad non-Russian patent numbers"
  end

  def test_get_with_binary_flag_returns_raw_data
    # Arrange
    client = Rospatent::Client.new
    binary_data = "\x25\x50\x44\x46\x2D\x31\x2E\x34" # PDF header bytes
    endpoint = "/media/test.pdf"

    # Test by directly stubbing the get method to verify binary flag is passed correctly
    get_called_with_binary = false

    client.define_singleton_method(:get) do |_path, _params = {}, binary: false|
      get_called_with_binary = binary
      binary_data
    end

    # Act
    result = client.send(:get, endpoint, {}, binary: true)

    # Assert
    assert_equal binary_data, result, "Should return binary data unchanged"
    assert get_called_with_binary, "Should call get with binary: true"
  end

  def test_patent_media_returns_binary_data
    # Arrange
    client = Rospatent::Client.new
    collection_id = "National"
    country_code = "RU"
    doc_type = "U1"
    pub_date = "2013/11/20"
    pub_number = "0000134694"
    filename = "document.pdf"
    pdf_binary_data = "\x25\x50\x44\x46\x2D\x31\x2E\x34\x0A" # PDF header
    expected_path = "/media/National/RU/U1/2013/11/20/0000134694/document.pdf"

    # Mock the get method to verify binary flag is used
    client.stub :get, lambda { |path, params = {}, binary: false|
      assert_equal expected_path, path, "Should construct correct path"
      assert_equal({}, params, "Should pass empty params")
      assert binary, "Should request binary data"
      pdf_binary_data
    } do
      # Act
      result = client.patent_media(collection_id, country_code, doc_type, pub_date, pub_number, filename)

      # Assert
      assert_equal pdf_binary_data, result, "Should return binary PDF data"
    end
  end

  def test_handle_response_extracts_rospatent_result_error
    # Arrange
    client = Rospatent::Client.new

    # Create a simple stub object with correct response interface
    mock_response = Struct.new(:success?, :status, :body, :headers).new(
      false, 400, '{"result":"Search on unknown dataset requested."}', {}
    )

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ApiError) do
      client.send(:handle_response, mock_response, "test_request_id")
    end

    assert_includes error.message, "Search on unknown dataset requested.",
                    "Should extract error message from 'result' field"
    assert_includes error.message, "test_request_id",
                    "Should include request ID in error message"
  end

  def test_handle_response_falls_back_to_error_field
    # Arrange
    client = Rospatent::Client.new

    mock_response = Struct.new(:success?, :status, :body, :headers).new(
      false, 400, '{"error":"Standard error message"}', {}
    )

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ApiError) do
      client.send(:handle_response, mock_response, "test_request_id")
    end

    assert_includes error.message, "Standard error message",
                    "Should extract error message from 'error' field as fallback"
  end

  def test_handle_response_falls_back_to_message_field
    # Arrange
    client = Rospatent::Client.new

    mock_response = Struct.new(:success?, :status, :body, :headers).new(
      false, 400, '{"message":"Standard message field"}', {}
    )

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ApiError) do
      client.send(:handle_response, mock_response, "test_request_id")
    end

    assert_includes error.message, "Standard message field",
                    "Should extract error message from 'message' field as fallback"
  end

  def test_handle_response_handles_non_json_response
    # Arrange
    client = Rospatent::Client.new

    mock_response = Struct.new(:success?, :status, :body, :headers).new(
      false, 500, "<html><body>Internal Server Error</body></html>", {}
    )

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ApiError) do
      client.send(:handle_response, mock_response, "test_request_id")
    end

    assert_includes error.message, "Internal Server Error",
                    "Should use raw response body for non-JSON responses"
  end

  def test_handle_response_handles_malformed_json
    # Arrange
    client = Rospatent::Client.new

    mock_response = Struct.new(:success?, :status, :body, :headers).new(
      false, 400, '{"incomplete": json', {}
    )

    # Act & Assert
    error = assert_raises(Rospatent::Errors::ApiError) do
      client.send(:handle_response, mock_response, "test_request_id")
    end

    assert_includes error.message, '{"incomplete": json',
                    "Should use raw response body for malformed JSON"
  end
end
