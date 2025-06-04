# frozen_string_literal: true

require_relative "../test_helper"

class InputValidatorTest < Minitest::Test
  include Rospatent::InputValidator

  def test_validate_date_with_date_object
    date = Date.new(2023, 1, 15)
    result = validate_date(date, "test_date")
    assert_equal date, result
  end

  def test_validate_date_with_valid_string
    result = validate_date("2023-01-15", "test_date")
    assert_equal Date.new(2023, 1, 15), result
  end

  def test_validate_date_with_nil
    result = validate_date(nil, "test_date")
    assert_nil result
  end

  def test_validate_date_with_invalid_string
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_date("invalid-date", "test_date")
    end
  end

  def test_validate_date_with_wrong_type
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_date(12_345, "test_date")
    end
  end

  def test_validate_positive_integer_with_valid_integer
    result = validate_positive_integer(42, "test_field")
    assert_equal 42, result
  end

  def test_validate_positive_integer_with_string
    result = validate_positive_integer("42", "test_field")
    assert_equal 42, result
  end

  def test_validate_positive_integer_with_nil
    result = validate_positive_integer(nil, "test_field")
    assert_nil result
  end

  def test_validate_positive_integer_with_zero
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_positive_integer(0, "test_field")
    end
  end

  def test_validate_positive_integer_with_negative
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_positive_integer(-5, "test_field")
    end
  end

  def test_validate_positive_integer_with_max_value
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_positive_integer(150, "test_field", max_value: 100)
    end
  end

  def test_validate_positive_integer_with_custom_min_value
    result = validate_positive_integer(5, "test_field", min_value: 5)
    assert_equal 5, result
  end

  def test_validate_positive_integer_with_non_numeric_string
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_positive_integer("abc", "test_field")
    end
  end

  def test_validate_string_with_valid_string
    result = validate_string("hello world", "test_field")
    assert_equal "hello world", result
  end

  def test_validate_string_with_whitespace_trimming
    result = validate_string("  hello world  ", "test_field")
    assert_equal "hello world", result
  end

  def test_validate_string_with_nil
    result = validate_string(nil, "test_field")
    assert_nil result
  end

  def test_validate_string_with_empty_string
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_string("", "test_field")
    end
  end

  def test_validate_string_with_max_length
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_string("this is too long", "test_field", max_length: 5)
    end
  end

  def test_validate_string_with_wrong_type
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_string(12_345, "test_field")
    end
  end

  def test_validate_enum_with_valid_symbol
    result = validate_enum(:option1, %i[option1 option2], "test_field")
    assert_equal :option1, result
  end

  def test_validate_enum_with_valid_string
    result = validate_enum("option1", %i[option1 option2], "test_field")
    assert_equal :option1, result
  end

  def test_validate_enum_with_nil
    result = validate_enum(nil, %i[option1 option2], "test_field")
    assert_nil result
  end

  def test_validate_enum_with_invalid_value
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_enum(:invalid, %i[option1 option2], "test_field")
    end
  end

  def test_validate_array_with_valid_array
    array = %w[item1 item2]
    result = validate_array(array, "test_field")
    assert_equal array, result
  end

  def test_validate_array_with_nil
    result = validate_array(nil, "test_field")
    assert_nil result
  end

  def test_validate_array_with_empty_array
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_array([], "test_field")
    end
  end

  def test_validate_array_with_max_size
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_array([1, 2, 3], "test_field", max_size: 2)
    end
  end

  def test_validate_array_with_element_validator
    validator = lambda { |element|
      raise Rospatent::Errors::ValidationError unless element.is_a?(String)
    }

    result = validate_array(%w[a b], "test_field", element_validator: validator)
    assert_equal %w[a b], result

    assert_raises(Rospatent::Errors::ValidationError) do
      validate_array(["a", 1], "test_field", element_validator: validator)
    end
  end

  def test_validate_array_with_wrong_type
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_array("not an array", "test_field")
    end
  end

  def test_validate_hash_with_valid_hash
    hash = { key1: "value1", key2: "value2" }
    result = validate_hash(hash, "test_field")
    assert_equal hash, result
  end

  def test_validate_hash_with_nil
    result = validate_hash(nil, "test_field")
    assert_nil result
  end

  def test_validate_hash_with_required_keys
    hash = { key1: "value1", key2: "value2" }
    result = validate_hash(hash, "test_field", required_keys: [:key1])
    assert_equal hash, result
  end

  def test_validate_hash_with_missing_required_keys
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_hash({ key1: "value1" }, "test_field", required_keys: %i[key1 key2])
    end
  end

  def test_validate_hash_with_allowed_keys
    hash = { key1: "value1" }
    result = validate_hash(hash, "test_field", allowed_keys: %i[key1 key2])
    assert_equal hash, result
  end

  def test_validate_hash_with_invalid_keys
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_hash({ invalid_key: "value" }, "test_field", allowed_keys: %i[key1 key2])
    end
  end

  def test_validate_hash_with_wrong_type
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_hash("not a hash", "test_field")
    end
  end

  def test_validate_patent_id_with_valid_format
    valid_id = "RU134694U1_20131120"
    result = validate_patent_id(valid_id)
    assert_equal valid_id, result
  end

  def test_validate_patent_id_with_invalid_format
    invalid_ids = %w[
      INVALID
      RU123
      RU134694U1
      RU134694U1_2013
      123RU134694U1_20131120
    ]

    invalid_ids.each do |invalid_id|
      assert_raises(Rospatent::Errors::ValidationError) do
        validate_patent_id(invalid_id)
      end
    end
  end

  def test_validate_patent_id_with_nil_or_empty
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_patent_id(nil)
    end

    assert_raises(Rospatent::Errors::ValidationError) do
      validate_patent_id("")
    end
  end

  def test_validate_params_with_valid_parameters
    params = { limit: "10", offset: "0", q: "test query" }
    validations = {
      limit: { type: :positive_integer, max_value: 100 },
      offset: { type: :positive_integer, min_value: 0 },
      q: { type: :string, max_length: 1000 }
    }

    result = validate_params(params, validations)

    assert_equal 10, result[:limit]
    assert_equal 0, result[:offset]
    assert_equal "test query", result[:q]
  end

  def test_validate_params_with_invalid_parameters
    params = { limit: "invalid", offset: "-1" }
    validations = {
      limit: { type: :positive_integer },
      offset: { type: :positive_integer, min_value: 0 }
    }

    assert_raises(Rospatent::Errors::ValidationError) do
      validate_params(params, validations)
    end
  end

  def test_validate_params_with_enum_validation
    params = { sort: "relevance" }
    validations = {
      sort: { type: :enum, allowed_values: %i[relevance pub_date] }
    }

    result = validate_params(params, validations)
    assert_equal :relevance, result[:sort]
  end

  def test_validate_params_with_date_validation
    params = { date: "2023-01-15" }
    validations = {
      date: { type: :date }
    }

    result = validate_params(params, validations)
    assert_equal Date.new(2023, 1, 15), result[:date]
  end

  def test_validate_params_with_array_validation
    params = { datasets: %w[dataset1 dataset2] }
    validations = {
      datasets: { type: :array, max_size: 10 }
    }

    result = validate_params(params, validations)
    assert_equal %w[dataset1 dataset2], result[:datasets]
  end

  def test_validate_params_with_hash_validation
    params = { filter: { field: "value" } }
    validations = {
      filter: { type: :hash, required_keys: [:field] }
    }

    result = validate_params(params, validations)
    assert_equal({ field: "value" }, result[:filter])
  end

  def test_validate_params_filters_nil_values
    params = { limit: 10, offset: nil, q: "test" }
    validations = {
      limit: { type: :positive_integer },
      offset: { type: :positive_integer },
      q: { type: :string }
    }

    result = validate_params(params, validations)

    assert_equal 10, result[:limit]
    assert_equal "test", result[:q]
    refute_includes result.keys, :offset
  end

  def test_validate_text_with_word_count_with_sufficient_words
    text = "This is a test text with exactly ten words for validation."
    result = validate_text_with_word_count(text, "test_field", min_words: 5)
    assert_equal text.strip, result
  end

  def test_validate_text_with_word_count_with_exact_minimum
    text = "One two three four five"
    result = validate_text_with_word_count(text, "test_field", min_words: 5)
    assert_equal text, result
  end

  def test_validate_text_with_word_count_with_insufficient_words
    text = "Only four words here"
    error = assert_raises(Rospatent::Errors::ValidationError) do
      validate_text_with_word_count(text, "test_field", min_words: 5)
    end
    assert_match(/must contain at least 5 words/, error.message)
    assert_match(/currently has 4/, error.message)
  end

  def test_validate_text_with_word_count_with_nil
    result = validate_text_with_word_count(nil, "test_field", min_words: 5)
    assert_nil result
  end

  def test_validate_text_with_word_count_with_empty_string
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_text_with_word_count("", "test_field", min_words: 5)
    end
  end

  def test_validate_text_with_word_count_with_max_length
    # Text with enough words but too long
    text = "word " * 100 # 100 words, 500 characters
    assert_raises(Rospatent::Errors::ValidationError) do
      validate_text_with_word_count(text, "test_field", min_words: 50, max_length: 400)
    end
  end

  def test_validate_text_with_word_count_with_multiple_spaces
    text = "These    words   have    multiple     spaces    between    them    for    testing    purposes"
    result = validate_text_with_word_count(text, "test_field", min_words: 10)
    assert_equal text.strip, result
  end

  def test_validate_text_with_word_count_with_50_words_for_similar_patents
    # Test the specific case for similar_patents_by_text
    words = %w[
      Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod
      tempor incididunt ut labore et dolore magna aliqua Ut enim ad minim
      veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea
      commodo consequat Duis aute irure dolor in reprehenderit in voluptate
      velit esse cillum dolore eu fugiat nulla pariatur Excepteur sint
    ]
    text = words.join(" ")
    result = validate_text_with_word_count(text, "search_text", min_words: 50)
    assert_equal text, result
  end

  def test_validate_text_with_word_count_with_49_words_fails
    # Test that 49 words fails the 50-word requirement
    words = (1..49).map { |i| "word#{i}" }
    text = words.join(" ")
    error = assert_raises(Rospatent::Errors::ValidationError) do
      validate_text_with_word_count(text, "search_text", min_words: 50)
    end
    assert_match(/must contain at least 50 words/, error.message)
    assert_match(/currently has 49/, error.message)
  end
end
