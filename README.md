# Rospatent

[![Gem Version](https://badge.fury.io/rb/rospatent.svg)](https://badge.fury.io/rb/rospatent)

A comprehensive Ruby client for the Rospatent patent search API with advanced features including intelligent caching, input validation, structured logging, and robust error handling.

> 🇷🇺 **[Документация на русском языке](#-документация-на-русском-языке)** доступна ниже

## ✨ Key Features

- 🔍 **Complete API Coverage** - Search, retrieve patents, media files, and datasets
- 🛡️ **Robust Error Handling** - Comprehensive error types with detailed context
- ⚡ **Intelligent Caching** - In-memory caching with TTL and LRU eviction
- ✅ **Input Validation** - Automatic parameter validation with helpful error messages
- 📊 **Structured Logging** - JSON/text logging with request/response tracking
- 🚀 **Batch Operations** - Process multiple patents concurrently
- ⚙️ **Environment-Aware** - Different configurations for dev/staging/production
- 🧪 **Comprehensive Testing** - 232 tests with 483 assertions, comprehensive integration testing
- 📚 **Excellent Documentation** - Detailed examples and API documentation

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rospatent'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install rospatent
```

## Quick Start

```ruby
# Minimal configuration
Rospatent.configure do |config|
  config.token = "your_jwt_token"
end

# Create a client and search
client = Rospatent.client
results = client.search(q: "ракета", limit: 10)

puts "Found #{results.total} results"
results.hits.each do |hit|
  puts "Patent: #{hit['id']} - #{hit.dig('biblio', 'ru', 'title')}"
end
```

## Configuration

### Basic Configuration

```ruby
Rospatent.configure do |config|
  # Required
  config.token = "your_jwt_token"

  # API settings
  config.api_url = "https://searchplatform.rospatent.gov.ru/patsearch/v0.2"
  config.timeout = 30
  config.retry_count = 3

  # Environment (development, staging, production)
  config.environment = "production"
end
```

### Advanced Configuration

```ruby
Rospatent.configure do |config|
  config.token = "your_jwt_token"

  # Caching (enabled by default)
  config.cache_enabled = true
  config.cache_ttl = 300              # 5 minutes
  config.cache_max_size = 1000        # Maximum cached items

  # Logging
  config.log_level = :info             # :debug, :info, :warn, :error
  config.log_requests = true           # Log API requests
  config.log_responses = true          # Log API responses

  # Connection settings
  config.connection_pool_size = 5
  config.connection_keep_alive = true

  # Token management
  config.token_expires_at = Time.now + 3600
  config.token_refresh_callback = -> { refresh_token! }
end
```

### Environment-Specific Configuration

The gem automatically adjusts settings based on environment with sensible defaults:

#### Development Environment

```ruby
# Optimized for development
Rospatent.configure do |config|
  config.environment = "development"
  config.token = ENV['ROSPATENT_TOKEN']
  config.log_level = :debug
  config.log_requests = true
  config.log_responses = true
  config.cache_ttl = 60          # Short cache for development
  config.timeout = 10            # Fast timeouts for quick feedback
end
```

#### Staging Environment

```ruby
# Optimized for staging
Rospatent.configure do |config|
  config.environment = "staging"
  config.token = ENV['ROSPATENT_TOKEN']
  config.log_level = :info
  config.cache_ttl = 300         # Longer cache for performance
  config.timeout = 45            # Longer timeouts for reliability
  config.retry_count = 3         # More retries for resilience
end
```

#### Production Environment

```ruby
# Optimized for production
Rospatent.configure do |config|
  config.environment = "production"
  config.token = ENV['ROSPATENT_TOKEN']
  config.log_level = :warn
  config.cache_ttl = 600         # Longer cache for performance
  config.timeout = 60            # Longer timeouts for reliability
  config.retry_count = 5         # More retries for resilience
end
```

### Environment Variables & Rails Integration

⚠️ **CRITICAL**: Understanding environment variable priority is essential to avoid configuration issues, especially in Rails applications.

#### Token Configuration Priority

1. **Rails credentials**: `Rails.application.credentials.rospatent_token`
2. **Primary environment variable**: `ROSPATENT_TOKEN`
3. **Legacy environment variable**: `ROSPATENT_API_TOKEN`

```bash
# Recommended approach
export ROSPATENT_TOKEN="your_jwt_token"

# Legacy support (still works)
export ROSPATENT_API_TOKEN="your_jwt_token"
```

#### Log Level Configuration Priority

```ruby
# Environment variable takes precedence over Rails defaults
config.log_level = if ENV.key?("ROSPATENT_LOG_LEVEL")
                     ENV["ROSPATENT_LOG_LEVEL"].to_sym
                   else
                     Rails.env.production? ? :warn : :debug
                   end
```

⚠️ **Common Issue**: Setting `ROSPATENT_LOG_LEVEL=debug` in production will override Rails-specific logic and cause DEBUG logs to appear in production!

#### Complete Environment Variables Reference

```bash
# Core configuration
ROSPATENT_TOKEN="your_jwt_token"           # API authentication token
ROSPATENT_ENV="production"                 # Override Rails.env if needed
ROSPATENT_API_URL="custom_url"            # Override default API URL

# Logging configuration
ROSPATENT_LOG_LEVEL="warn"                # debug, info, warn, error
ROSPATENT_LOG_REQUESTS="false"            # Log API requests
ROSPATENT_LOG_RESPONSES="false"           # Log API responses

# Cache configuration
ROSPATENT_CACHE_ENABLED="true"            # Enable/disable caching
ROSPATENT_CACHE_TTL="300"                 # Cache TTL in seconds
ROSPATENT_CACHE_MAX_SIZE="1000"           # Maximum cache items

# Connection configuration
ROSPATENT_TIMEOUT="30"                    # Request timeout in seconds
ROSPATENT_RETRY_COUNT="3"                 # Number of retries
ROSPATENT_POOL_SIZE="5"                   # Connection pool size
ROSPATENT_KEEP_ALIVE="true"               # Keep-alive connections

# Environment-specific overrides
ROSPATENT_DEV_API_URL="dev_url"           # Development API URL
ROSPATENT_STAGING_API_URL="staging_url"   # Staging API URL
```

#### Best Practices for Rails

1. **Use Rails credentials for tokens**:
   ```bash
   rails credentials:edit
   # Add: rospatent_token: your_jwt_token
   ```

2. **Set environment-specific variables**:
   ```bash
   # config/environments/production.rb
   ENV["ROSPATENT_LOG_LEVEL"] ||= "warn"
   ENV["ROSPATENT_CACHE_ENABLED"] ||= "true"
   ```

3. **Avoid setting DEBUG level in production**:
   ```bash
   # ❌ DON'T DO THIS in production
   export ROSPATENT_LOG_LEVEL=debug
   
   # ✅ DO THIS instead
   export ROSPATENT_LOG_LEVEL=warn
   ```

### Configuration Validation

```ruby
# Validate current configuration
errors = Rospatent.validate_configuration
if errors.any?
  puts "Configuration errors:"
  errors.each { |error| puts "  - #{error}" }
else
  puts "Configuration is valid ✓"
end
```

## Basic Usage

### Searching Patents

```ruby
client = Rospatent.client

# Simple text search
results = client.search(q: "ракета")

# Natural language search
results = client.search(qn: "rocket engine design")

# Advanced search with all options
results = client.search(
  q: "ракета AND двигатель",
  limit: 50,
  offset: 100,
  datasets: ["ru_since_1994"],
  filter: {
    "classification.ipc_group": { "values": ["F02K9"] },
    "application.filing_date": { "range": { "gte": "20200101" } }
  },
  sort: "publication_date:desc", # same as 'sort: :pub_date'; see Search#validate_sort_parameter for other sort options
  group_by: "family:dwpi",         # Patent family grouping: "family:docdb" or "family:dwpi"
  include_facets: true,            # Boolean: true/false (automatically converted to 1/0 for API)
  pre_tag: "<mark>",           # Both pre_tag and post_tag must be provided together
  post_tag: "</mark>",         # Can be strings or arrays for multi-color highlighting
  highlight: {                 # Advanced highlight configuration (independent of pre_tag/post_tag)
    "profiles" => [
      { "q" => "космическая", "pre_tag" => "<b>", "post_tag" => "</b>" },
      "_searchquery_"
    ]
  }
)

# Simple highlighting with tags (both pre_tag and post_tag required)
results = client.search(
  q: "ракета",
  pre_tag: "<mark>",
  post_tag: "</mark>"
)

# Multi-color highlighting with arrays
results = client.search(
  q: "космическая ракета", 
  pre_tag: ["<b>", "<i>"],     # Round-robin highlighting
  post_tag: ["</b>", "</i>"]   # with different tags
)

# Advanced highlighting with profiles (independent of pre_tag/post_tag)
results = client.search(
  q: "ракета",
  highlight: {
    "profiles" => [
      { "q" => "космическая", "pre_tag" => "<b>", "post_tag" => "</b>" },
      "_searchquery_"  # References main search query highlighting
    ]
  }
)

# Patent family grouping (groups patents from the same invention)
results = client.search(
  q: "rocket",
  group_by: "family:docdb",    # DOCDB simple patent families
  datasets: ["dwpi"],
  limit: 10
)

results = client.search(
  q: "rocket",
  group_by: "family:dwpi",     # DWPI simple patent families  
  datasets: ["dwpi"],
  limit: 10
)

# Process results
puts "Found #{results.total} total results (#{results.available} available)"
puts "Showing #{results.count} results"

results.hits.each do |hit|
  puts "ID: #{hit['id']}"
  puts "Title: #{hit.dig('biblio', 'ru', 'title')}"
  puts "Date: #{hit.dig('common', 'publication_date')}"
  puts "IPC: #{hit.dig('common', 'classification', 'ipc')&.map {|c| c['fullname']}&.join('; ')}"
  puts "---"
end
```

### Advanced Filter Parameters

The `filter` parameter supports complex filtering with automatic validation and format conversion:

#### List Filters (require `{"values": [...]}` format)

```ruby
# Classification filters
results = client.search(
  q: "artificial intelligence",
  filter: {
    "classification.ipc_group": { "values": ["G06N", "G06F"] },
    "classification.cpc_group": { "values": ["G06N3/", "G06N20/"] }
  }
)

# Author and patent holder filters
results = client.search(
  q: "invention",
  filter: {
    "authors": { "values": ["Иванов И.И.", "Петров П.П."] },
    "patent_holders": { "values": ["ООО Компания"] },
    "country": { "values": ["RU", "US"] },
    "kind": { "values": ["A1", "U1"] }
  }
)

# Document ID filters
results = client.search(
  q: "device",
  filter: {
    "ids": { "values": ["RU134694U1_20131120", "RU2358138C1_20090610"] }
  }
)
```

#### Date Range Filters (require `{"range": {"operator": "YYYYMMDD"}}` format)

```ruby
# Automatic date format conversion
results = client.search(
  q: "innovation",
  filter: {
    "date_published": { "range": { "gte": "2020-01-01", "lte": "2023-12-31" } },
    "application.filing_date": { "range": { "gte": "2019-06-15" } }
  }
)

# Direct API format (YYYYMMDD)
results = client.search(
  q: "technology",
  filter: {
    "date_published": { "range": { "gte": "20200101", "lt": "20240101" } }
  }
)

# Using Date objects (automatically converted)
results = client.search(
  q: "patent",
  filter: {
    "application.filing_date": { 
      "range": { 
        "gte": Date.new(2020, 1, 1),
        "lte": Date.new(2023, 12, 31) 
      } 
    }
  }
)
```

**Supported date operators**: `gt`, `gte`, `lt`, `lte`

**Date format conversion**:
- `"2020-01-01"` → `"20200101"`
- `Date.new(2020, 1, 1)` → `"20200101"`
- `"20200101"` → `"20200101"` (no change)

#### Complex Multi-Field Filters

```ruby
# Comprehensive filter example
results = client.search(
  q: "машинное обучение",
  filter: {
    # List filters
    "classification.ipc_group": { "values": ["G06N", "G06F"] },
    "country": { "values": ["RU", "US", "CN"] },
    "kind": { "values": ["A1", "A2"] },
    "authors": { "values": ["Иванов И.И."] },
    
    # Date range filters  
    "date_published": { "range": { "gte": "2020-01-01", "lte": "2023-12-31" } },
    "application.filing_date": { "range": { "gte": "2019-01-01" } }
  },
  limit: 50
)
```

**Supported Filter Fields**:

*List filters (require `{"values": [...]}` format):*
- `authors` - Patent authors
- `patent_holders` - Patent holders/assignees  
- `country` - Country codes
- `kind` - Document types
- `ids` - Specific document IDs
- `classification.ipc*` - IPC classification codes
- `classification.cpc*` - CPC classification codes

*Date filters (require `{"range": {"operator": "YYYYMMDD"}}` format):*
- `date_published` - Publication date
- `application.filing_date` - Application filing date

**Filter Validation**:
- ✅ Automatic field name validation
- ✅ Structure validation (list vs range format)
- ✅ Date format conversion and validation
- ✅ Operator validation for ranges
- ✅ Helpful error messages for invalid filters

```ruby
# These will raise ValidationError with specific messages:
client.search(
  q: "test",
  filter: { "invalid_field": { "values": ["test"] } }
)
# Error: "Invalid filter field: invalid_field"

client.search(
  q: "test", 
  filter: { "authors": ["direct", "array"] }  # Missing {"values": [...]} wrapper
)
# Error: "Filter 'authors' requires format: {\"values\": [...]}"

client.search(
  q: "test",
  filter: { "date_published": { "range": { "invalid_op": "20200101" } } }
)
# Error: "Invalid range operator: invalid_op. Supported: gt, gte, lt, lte"
```

### Retrieving Patent Documents

```ruby
# Get patent by document ID
patent_doc = client.patent("RU134694U1_20131120")

# Get patent by components
patent_doc = client.patent_by_components(
  "RU",                   # country_code
  "134694",               # number
  "U1",                   # doc_type
  Date.new(2013, 11, 20)  # date (String or Date object)
)

# Access patent data
title = patent_doc.dig('biblio', 'ru', 'title')
abstract = patent_doc.dig('abstract', 'ru')
inventors = patent_doc.dig('biblio', 'ru', 'inventor')
```

### Parsing Patent Content

Extract clean text or structured content from patents:

```ruby
# Parse abstract
abstract_text = client.parse_abstract(patent_doc)
abstract_html = client.parse_abstract(patent_doc, format: :html)
abstract_en = client.parse_abstract(patent_doc, language: "en")

# Parse description
description_text = client.parse_description(patent_doc)
description_html = client.parse_description(patent_doc, format: :html)

# Get structured sections
sections = client.parse_description(patent_doc, format: :sections)
sections.each do |section|
  puts "Section #{section[:number]}: #{section[:content]}"
end
```

### Finding Similar Patents

```ruby
# Find similar patents by ID
similar = client.similar_patents_by_id("RU134694U1_20131120", count: 50)

# Find similar patents by text description
similar = client.similar_patents_by_text(
  "Ракетный двигатель с улучшенной тягой ...", # 50 words in request minimum
  count: 25
)

# Process similar patents
similar["data"]&.each do |patent|
  puts "Similar: #{patent['id']} (score: #{patent['similarity']} (#{patent['similarity_norm']}))"
end
```

### Classification Search

Search within patent classification systems (IPC and CPC) and get detailed information about classification codes:

```ruby
# Search for classification codes related to rockets in IPC
ipc_results = client.classification_search("ipc", query: "ракета", lang: "ru")
puts "Found #{ipc_results.size} IPC codes"

ipc_results&.each do |result|
  puts "#{result['Code']}: #{result['Description']}"
end

# Search for rocket-related codes in CPC using English
cpc_results = client.classification_search("cpc", query: "rocket", lang: "en")

# Get detailed information about a specific classification code
code, info = client.classification_code("ipc", code: "F02K9/00", lang: "ru")&.first
puts "Code: #{code}"
puts "Description: #{info&.first['Description']}"
puts "Hierarchy: #{info&.map{|level| level['Code']}&.join(' → ')}"

# Get CPC code information in English
cpc_info = client.classification_code("cpc", code: "B63H11/00", lang: "en")
```

**Supported Classification Systems:**
- `"ipc"` - International Patent Classification (МПК)
- `"cpc"` - Cooperative Patent Classification (СПК)

**Supported Languages:**
- `"ru"` - Russian
- `"en"` - English

### Available datasets list

```ruby
datasets = client.datasets_tree
datasets.each do |category|
  puts "Category: #{category['name_en']}"
  category.children.each do |dataset|
    puts "  #{dataset['id']}: #{dataset['name_en']}"
  end
end
```

### Media and Documents

```ruby
# Download patent PDF
pdf_data = client.patent_media(
  "National",       # collection_id
  "RU",             # country_code
  "U1",             # doc_type
  "2013/11/20",     # pub_date
  "134694",         # pub_number
  "document.pdf"    # filename
)
File.write("patent.pdf", pdf_data)

# Simplified method using patent ID
pdf_data = client.patent_media_by_id(
  "RU134694U1_20131120",
  "National",
  "document.pdf"
)
```

## Advanced Features

### Batch Operations

Process multiple patents efficiently with concurrent requests:

```ruby
document_ids = ["RU134694U1_20131120", "RU2358138C1_20090610", "RU2756123C1_20210927"]

# Process patents in batches
client.batch_patents(document_ids, batch_size: 5) do |patent_doc|
  if patent_doc[:error]
    puts "Error for #{patent_doc[:document_id]}: #{patent_doc[:error]}"
  else
    puts "Retrieved patent: #{patent_doc['id']}"
    # Process patent document
  end
end

# Or collect all results
patents = []
client.batch_patents(document_ids) { |doc| patents << doc }
```

### Caching

Automatic intelligent caching improves performance:

```ruby
# Caching is automatic and transparent
patent1 = client.patent("RU134694U1_20131120")  # API call
patent2 = client.patent("RU134694U1_20131120")  # Cached result

# Check cache statistics
stats = client.statistics
puts "Cache hit rate: #{stats[:cache_stats][:hit_rate_percent]}%"
puts "Total requests: #{stats[:requests_made]}"
puts "Average response time: #{stats[:average_request_time]}s"

# Use shared cache across clients
shared_cache = Rospatent.shared_cache
client1 = Rospatent.client(cache: shared_cache)
client2 = Rospatent.client(cache: shared_cache)

# Manual cache management
shared_cache.clear                    # Clear all cached data
expired_count = shared_cache.cleanup_expired  # Remove expired entries
cache_stats = shared_cache.statistics # Get detailed cache statistics
```

### Custom Logging

Configure detailed logging for monitoring and debugging:

```ruby
# Create custom logger
logger = Rospatent::Logger.new(
  output: Rails.logger,  # Or any IO object
  level: :info,
  formatter: :json      # :json or :text
)

client = Rospatent.client(logger: logger)

# Logs include:
# - API requests/responses with timing
# - Cache operations (hits/misses)
# - Error details with context
# - Performance metrics

# Access shared logger
shared_logger = Rospatent.shared_logger(level: :debug)
```

**Notes**:
- When using `Rails.logger`, formatting is controlled by Rails configuration, `formatter` parameter ignored
- When using IO objects, `formatter` parameter controls output format

### Error Handling

Comprehensive error handling with specific error types and improved error message extraction:

```ruby
begin
  patent = client.patent("INVALID_ID")
rescue Rospatent::Errors::ValidationError => e
  puts "Invalid input: #{e.message}"
  puts "Field errors: #{e.errors}" if e.errors.any?
rescue Rospatent::Errors::NotFoundError => e
  puts "Patent not found: #{e.message}"
rescue Rospatent::Errors::RateLimitError => e
  puts "Rate limited. Retry after: #{e.retry_after} seconds"
rescue Rospatent::Errors::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue Rospatent::Errors::ApiError => e
  puts "API error (#{e.status_code}): #{e.message}"
  puts "Request ID: #{e.request_id}" if e.request_id
  retry if e.retryable?
rescue Rospatent::Errors::ConnectionError => e
  puts "Connection error: #{e.message}"
  puts "Original error: #{e.original_error}"
end

# Enhanced error message extraction
# The client automatically extracts error messages from various API response formats:
# - {"result": "Error message"}           (Rospatent API format)
# - {"error": "Error message"}            (Standard format)
# - {"message": "Error message"}          (Alternative format)
# - {"details": "Validation details"}     (Validation errors)
```

### Input Validation

All inputs are automatically validated with helpful error messages:

```ruby
# These will raise ValidationError with specific messages:
client.search(limit: 0)                    # "Limit must be at least 1"
client.patent("")                          # "Document_id cannot be empty"
client.similar_patents_by_text("", count: -1)  # Multiple validation errors

# Validation includes:
# - Parameter types and formats
# - Patent ID format validation
# - Date format validation
# - Enum value validation
# - Required field validation
```

### Performance Monitoring

Track performance and usage statistics:

```ruby
# Client-specific statistics
stats = client.statistics
puts "Requests made: #{stats[:requests_made]}"
puts "Total duration: #{stats[:total_duration_seconds]}s"
puts "Average request time: #{stats[:average_request_time]}s"
puts "Cache hit rate: #{stats[:cache_stats][:hit_rate_percent]}%"

# Global statistics
global_stats = Rospatent.statistics
puts "Environment: #{global_stats[:configuration][:environment]}"
puts "Cache enabled: #{global_stats[:configuration][:cache_enabled]}"
puts "API URL: #{global_stats[:configuration][:api_url]}"
```

## Rails Integration

### Generator

```bash
$ rails generate rospatent:install
```

This creates `config/initializers/rospatent.rb`:

```ruby
Rospatent.configure do |config|
  # Token priority: Rails credentials > ROSPATENT_TOKEN > ROSPATENT_API_TOKEN
  config.token = Rails.application.credentials.rospatent_token || 
                 ENV["ROSPATENT_TOKEN"] || 
                 ENV["ROSPATENT_API_TOKEN"]
  
  # Environment configuration respects ROSPATENT_ENV
  config.environment = ENV.fetch("ROSPATENT_ENV", Rails.env)
  
  # CRITICAL: Environment variables take priority over Rails defaults
  # This prevents DEBUG logs appearing in production if ROSPATENT_LOG_LEVEL=debug is set
  config.log_level = if ENV.key?("ROSPATENT_LOG_LEVEL")
                       ENV["ROSPATENT_LOG_LEVEL"].to_sym
                     else
                       Rails.env.production? ? :warn : :debug
                     end
  
  config.cache_enabled = Rails.env.production?
end
```

### Using with Rails Logger

```ruby
# In config/initializers/rospatent.rb
Rospatent.configure do |config|
  config.token = Rails.application.credentials.rospatent_token
end

# Create client with Rails logger
logger = Rospatent::Logger.new(
  output: Rails.logger,
  level: Rails.env.production? ? :warn : :debug,
  formatter: :text
)

# Use in controllers/services
class PatentService
  def initialize
    @client = Rospatent.client(logger: logger)
  end

  def search_patents(query)
    @client.search(q: query, limit: 20)
  rescue Rospatent::Errors::ApiError => e
    Rails.logger.error "Patent search failed: #{e.message}"
    raise
  end
end
```

## Testing

### Running Tests

```bash
# Run all tests
$ bundle exec rake test

# Run specific test file
$ bundle exec ruby -Itest test/unit/client_test.rb

# Run integration tests (requires API token)
$ ROSPATENT_INTEGRATION_TESTS=true ROSPATENT_TEST_TOKEN=your_token bundle exec rake test_integration

# Run with coverage
$ bundle exec rake coverage
```

### Test Configuration

For testing, reset and configure in each test's setup method:

```ruby
# test/test_helper.rb - Base setup for unit tests
module Minitest
  class Test
    def setup
      Rospatent.reset  # Clean state between tests
      Rospatent.configure do |config|
        config.token = ENV.fetch("ROSPATENT_TEST_TOKEN", "test_token")
        config.environment = "development"
        config.cache_enabled = false  # Disable cache for predictable tests
        config.log_level = :error     # Reduce test noise
      end
    end
  end
end

# For integration tests - stable config, no reset needed
class IntegrationTest < Minitest::Test
  def setup
    skip unless ENV["ROSPATENT_INTEGRATION_TESTS"]

    @token = ENV.fetch("ROSPATENT_TEST_TOKEN", nil)
    skip "ROSPATENT_TEST_TOKEN not set" unless @token

    # No reset needed - integration tests use consistent configuration
    Rospatent.configure do |config|
      config.token = @token
      config.environment = "development"
      config.cache_enabled = true
      config.log_level = :debug
    end
  end
end
```

### Custom Assertions (Minitest)

```ruby
# test/test_helper.rb
module Minitest
  class Test
    def assert_valid_patent_id(patent_id, message = nil)
      message ||= "Expected #{patent_id} to be a valid patent ID (format: XX12345Y1_YYYYMMDD)"
      assert patent_id.match?(/^[A-Z]{2}[A-Z0-9]+[A-Z]\d*_\d{8}$/), message
    end
  end
end

# Usage in tests
def test_patent_id_validation
  assert_valid_patent_id("RU134694U1_20131120")
  assert_valid_patent_id("RU134694A_20131120")
end
```

## Known API Limitations

The library uses **Faraday** as the HTTP client with redirect support for all endpoints:

- **All endpoints** (`/search`, `/docs/{id}`, `/similar_search`, `/datasets/tree`, etc.) - ✅ Working perfectly with Faraday
- **Redirect handling**: Configured with `faraday-follow_redirects` middleware to handle server redirects automatically

⚠️ **Minor server-side limitations**:
- **Similar Patents by Text**: Occasionally returns `503 Service Unavailable` (a server-side issue, not a client implementation issue)

⚠️ **Documentation inconsistencies**:
- **Similar Patents**: According to the documentation, the array of hits is named `hits`, but the real implementation uses the name `data`
- **Available Datasets**: The `name` key in the real implementation has the localization suffix — `name_ru`, `name_en`

All core functionality works perfectly and is production-ready with a unified HTTP approach.

## Error Reference

### Error Hierarchy

```
Rospatent::Errors::Error (base)
├── MissingTokenError
├── ApiError
│   ├── AuthenticationError (401)
│   ├── NotFoundError (404)
│   ├── RateLimitError (429)
│   └── ServiceUnavailableError (503)
├── ConnectionError
│   └── TimeoutError
├── InvalidRequestError
└── ValidationError
```

### Common Error Scenarios

```ruby
# Missing or invalid token
Rospatent::Errors::MissingTokenError
Rospatent::Errors::AuthenticationError

# Invalid input parameters
Rospatent::Errors::ValidationError

# Resource not found
Rospatent::Errors::NotFoundError

# Rate limiting
Rospatent::Errors::RateLimitError  # Check retry_after

# Network issues
Rospatent::Errors::ConnectionError
Rospatent::Errors::TimeoutError

# Server problems
Rospatent::Errors::ServiceUnavailableError
```

## Rake Tasks

Useful development and maintenance tasks:

```bash
# Validate configuration
$ bundle exec rake validate

# Cache management
$ bundle exec rake cache:stats
$ bundle exec rake cache:clear

# Generate documentation
$ bundle exec rake doc

# Run integration tests
$ ROSPATENT_INTEGRATION_TESTS=true ROSPATENT_TEST_TOKEN='<your_jwt_token>' bundle exec rake test_integration

# Setup development environment
$ bundle exec rake setup

# Pre-release checks
$ bundle exec rake release_check
```

## Performance Tips

1. **Use Caching**: Enable caching for repeated requests
2. **Batch Operations**: Use `batch_patents` for multiple documents
3. **Appropriate Limits**: Don't request more data than needed
4. **Connection Reuse**: Use the same client instance when possible
5. **Environment Configuration**: Use production settings in production

```ruby
# Good: Reuse client instance
client = Rospatent.client
patents = patent_ids.map { |id| client.patent(id) }

# Better: Use batch operations
patents = []
client.batch_patents(patent_ids) { |doc| patents << doc }

# Best: Use caching with shared instance
shared_client = Rospatent.client(cache: Rospatent.shared_cache)
```

## Troubleshooting

### Common Issues

**Authentication Errors**:
```ruby
# Check token validity
errors = Rospatent.validate_configuration
puts errors if errors.any?
```

**Network Timeouts**:
```ruby
# Increase timeout for slow connections
Rospatent.configure do |config|
  config.timeout = 120
  config.retry_count = 5
end
```

**Memory Usage**:
```ruby
# Limit cache size for memory-constrained environments
Rospatent.configure do |config|
  config.cache_max_size = 100
  config.cache_ttl = 300
end
```

**Debug API Calls**:
```ruby
# Enable detailed logging
Rospatent.configure do |config|
  config.log_level = :debug
  config.log_requests = true
  config.log_responses = true
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests.

### Development Setup

```bash
$ git clone https://hub.mos.ru/ad/rospatent.git
$ cd rospatent
$ bundle install
$ bundle exec rake setup
```

### Running Tests

```bash
# Unit tests
$ bundle exec rake test

# Integration tests (requires API token)
$ ROSPATENT_INTEGRATION_TESTS=true ROSPATENT_TEST_TOKEN=your_token bundle exec rake test_integration

# Code style
$ bundle exec rubocop

# All checks
$ bundle exec rake ci
```

### Interactive Console

```bash
$ bin/console
```

## Contributing

Bug reports and pull requests are welcome on MosHub at https://hub.mos.ru/ad/rospatent.

### Development Guidelines

1. **Write Tests**: Ensure all new features have corresponding tests
2. **Follow Style**: Run `rubocop` and fix any style issues
3. **Document Changes**: Update README and CHANGELOG
4. **Validate Configuration**: Run `rake validate` before submitting

### Release Process

```bash
# Pre-release checks
$ bundle exec rake release_check

# Update version and release
$ bundle exec rake release
```

---

# 📖 Документация на русском языке

## Описание

**Rospatent** — это комплексный Ruby-клиент для взаимодействия с API поиска патентов Роспатента. Библиотека предоставляет удобный интерфейс для поиска, получения и анализа патентной информации с автоматическим кешированием, валидацией запросов и подробным логированием.

## ✨ Ключевые возможности

- 🔍 **Полное покрытие API** - поиск, получение патентов, медиафайлы и датасеты
- 🛡️ **Надежная обработка ошибок** - комплексные типы ошибок с детальным контекстом
- ⚡ **Интеллектуальное кеширование** - кеширование в памяти с TTL и LRU исключением
- ✅ **Валидация входных данных** - автоматическая валидация параметров с полезными сообщениями
- 📊 **Структурированное логирование** - JSON/текстовое логирование с отслеживанием запросов/ответов
- 🚀 **Пакетные операции** - параллельная обработка множества патентов
- ⚙️ **Адаптивные окружения** - различные конфигурации для development/staging/production
- 🧪 **Комплексное тестирование** - 232 теста с 483 проверками, комплексное интеграционное тестирование
- 📚 **Отличная документация** - подробные примеры и документация API

## Установка

Добавьте в ваш Gemfile:

```ruby
gem 'rospatent'
```

Затем выполните:

```bash
$ bundle install
```
Или установите напрямую:

```bash
$ gem install rospatent
```

## Быстрый старт

```ruby
# Минимальная конфигурация
Rospatent.configure do |config|
  config.token = "ваш_jwt_токен"
end

# Создание клиента и поиск
client = Rospatent.client
results = client.search(q: "ракета", limit: 10)

puts "Найдено #{results.total} результатов"
results.hits.each do |hit|
  puts "Патент: #{hit['id']} - #{hit.dig('biblio', 'ru', 'title')}"
end
```

## Конфигурация

### Базовая настройка

```ruby
Rospatent.configure do |config|
  # Обязательно
  config.token = "ваш_jwt_токен"

  # Настройки API
  config.api_url = "https://searchplatform.rospatent.gov.ru/patsearch/v0.2"
  config.timeout = 30
  config.retry_count = 3

  # Окружение (development, staging, production)
  config.environment = "production"
end
```

### Продвинутая настройка

```ruby
Rospatent.configure do |config|
  config.token = "ваш_jwt_токен"

  # Кеширование (включено по умолчанию)
  config.cache_enabled = true
  config.cache_ttl = 300              # 5 минут
  config.cache_max_size = 1000        # Максимум элементов кеша

  # Логирование
  config.log_level = :info             # :debug, :info, :warn, :error
  config.log_requests = true           # Логировать API запросы
  config.log_responses = true          # Логировать API ответы

  # Настройки соединения
  config.connection_pool_size = 5
  config.connection_keep_alive = true

  # Управление токенами
  config.token_expires_at = Time.now + 3600
  config.token_refresh_callback = -> { refresh_token! }
end
```

### Конфигурация для конкретных окружений

Gem автоматически настраивается под окружение с разумными значениями по умолчанию:

#### Окружение разработки

```ruby
# Оптимизировано для разработки
Rospatent.configure do |config|
  config.environment = "development"
  config.token = ENV['ROSPATENT_TOKEN']
  config.log_level = :debug
  config.log_requests = true
  config.log_responses = true
  config.cache_ttl = 60          # Короткий кеш для разработки
  config.timeout = 10            # Быстрые таймауты для быстрой обратной связи
end
```

#### Окружение Staging

```ruby
# Оптимизировано для staging
Rospatent.configure do |config|
  config.environment = "staging"
  config.token = ENV['ROSPATENT_TOKEN']
  config.log_level = :info
  config.cache_ttl = 300         # Более длительный кеш для производительности
  config.timeout = 45            # Более длительные таймауты для надежности
  config.retry_count = 3         # Больше повторов для устойчивости
end
```

#### Продакшн окружение

```ruby
# Оптимизировано для продакшна
Rospatent.configure do |config|
  config.environment = "production"
  config.token = ENV['ROSPATENT_TOKEN']
  config.log_level = :warn
  config.cache_ttl = 600         # Более длительный кеш для производительности
  config.timeout = 60            # Более длительные таймауты для надежности
  config.retry_count = 5         # Больше повторов для устойчивости
end
```

### Переменные окружения и интеграция с Rails

⚠️ **КРИТИЧНО**: Понимание приоритета переменных окружения необходимо для избежания проблем конфигурации, особенно в Rails приложениях.

#### Приоритет конфигурации токена

1. **Rails credentials**: `Rails.application.credentials.rospatent_token`
2. **Основная переменная окружения**: `ROSPATENT_TOKEN`
3. **Устаревшая переменная окружения**: `ROSPATENT_API_TOKEN`

```bash
# Рекомендуемый подход
export ROSPATENT_TOKEN="your_jwt_token"

# Поддержка устаревшего формата (все еще работает)
export ROSPATENT_API_TOKEN="your_jwt_token"
```

#### Приоритет конфигурации уровня логирования

```ruby
# Переменная окружения имеет приоритет над настройками Rails по умолчанию
config.log_level = if ENV.key?("ROSPATENT_LOG_LEVEL")
                     ENV["ROSPATENT_LOG_LEVEL"].to_sym
                   else
                     Rails.env.production? ? :warn : :debug
                   end
```

⚠️ **Частая проблема**: Установка `ROSPATENT_LOG_LEVEL=debug` в продакшне переопределит логику Rails и приведёт к появлению DEBUG логов в продакшне!

#### Полный справочник переменных окружения

```bash
# Основная конфигурация
ROSPATENT_TOKEN="your_jwt_token"           # Токен аутентификации API
ROSPATENT_ENV="production"                 # Переопределить Rails.env при необходимости
ROSPATENT_API_URL="custom_url"            # Переопределить URL API по умолчанию

# Конфигурация логирования
ROSPATENT_LOG_LEVEL="warn"                # debug, info, warn, error
ROSPATENT_LOG_REQUESTS="false"            # Логировать API запросы
ROSPATENT_LOG_RESPONSES="false"           # Логировать API ответы

# Конфигурация кеша
ROSPATENT_CACHE_ENABLED="true"            # Включить/отключить кеширование
ROSPATENT_CACHE_TTL="300"                 # TTL кеша в секундах
ROSPATENT_CACHE_MAX_SIZE="1000"           # Максимальное количество элементов кеша

# Конфигурация соединения
ROSPATENT_TIMEOUT="30"                    # Таймаут запроса в секундах
ROSPATENT_RETRY_COUNT="3"                 # Количество повторов
ROSPATENT_POOL_SIZE="5"                   # Размер пула соединений
ROSPATENT_KEEP_ALIVE="true"               # Keep-alive соединения

# Переопределения для конкретных окружений
ROSPATENT_DEV_API_URL="dev_url"           # URL API для разработки
ROSPATENT_STAGING_API_URL="staging_url"   # URL API для staging
```

#### Лучшие практики для Rails

1. **Используйте Rails credentials для токенов**:
   ```bash
   rails credentials:edit
   # Добавьте: rospatent_token: your_jwt_token
   ```

2. **Установите переменные для конкретных окружений**:
   ```bash
   # config/environments/production.rb
   ENV["ROSPATENT_LOG_LEVEL"] ||= "warn"
   ENV["ROSPATENT_CACHE_ENABLED"] ||= "true"
   ```

3. **Избегайте установки DEBUG уровня в продакшне**:
   ```bash
   # ❌ НЕ ДЕЛАЙТЕ ТАК в продакшне
   export ROSPATENT_LOG_LEVEL=debug
   
   # ✅ ДЕЛАЙТЕ ТАК
   export ROSPATENT_LOG_LEVEL=warn
   ```

### Валидация конфигурации

```ruby
# Валидация текущей конфигурации
errors = Rospatent.validate_configuration
if errors.any?
  puts "Ошибки конфигурации:"
  errors.each { |error| puts "  - #{error}" }
else
  puts "Конфигурация действительна ✓"
end
```

## Основное использование

### Поиск патентов

```ruby
# Простой поиск
results = client.search(q: "солнечная батарея")

# Поиск на естественном языке
results = client.search(qn: "конструкция ракетного двигателя")

# Расширенный поиск с всеми опциями
results = client.search(
  q: "искусственный интеллект AND нейронная сеть",
  limit: 50,
  offset: 100,
  datasets: ["ru_since_1994"],
  filter: {
    "classification.ipc_group": { "values": ["G06N"] },
    "application.filing_date": { "range": { "gte": "20200101" } }
  },
  sort: "publication_date:desc", # то же самое, что 'sort: :pub_date'; см. варианты параметров сортировки в Search#validate_sort_parameter
  group_by: "family:dwpi",       # Группировка по семействам: "family:docdb" или "family:dwpi"
  include_facets: true,          # Boolean: true/false (автоматически конвертируется в 1/0 для API)
  pre_tag: "<mark>",             # Оба тега должны быть указаны вместе
  post_tag: "</mark>",           # Могут быть строками или массивами
  highlight: {                   # Продвинутая настройка подсветки (независимо от тегов)
    "profiles" => [
      { "q" => "нейронная сеть", "pre_tag" => "<b>", "post_tag" => "</b>" },
      "_searchquery_"
    ]
  }
)

# Простая подсветка с тегами (оба тега обязательны)
results = client.search(
  q: "ракета",
  pre_tag: "<mark>",
  post_tag: "</mark>"
)

# Многоцветная подсветка с массивами
results = client.search(
  q: "космическая ракета", 
  pre_tag: ["<b>", "<i>"],     # Циклическая подсветка
  post_tag: ["</b>", "</i>"]   # разными тегами
)

# Продвинутая подсветка с использованием профилей (независимо от pre_tag/post_tag)
results = client.search(
  q: "ракета",
  highlight: {
    "profiles" => [
      { "q" => "космическая", "pre_tag" => "<b>", "post_tag" => "</b>" },
      "_searchquery_"  # Ссылка на параметры подсветки основного поискового запроса
    ]
  }
)

# Группировка по семействам патентов (группирует патенты одного изобретения)
results = client.search(
  q: "ракета",
  group_by: "family:docdb",    # Простые семейства патентов DOCDB
  datasets: ["dwpi"],
  limit: 10
)

results = client.search(
  q: "ракета",
  group_by: "family:dwpi",     # Простые семейства патентов DWPI
  datasets: ["dwpi"],
  limit: 10
)

# Обработка результатов
puts "Найдено: #{results.total} патентов (доступно #{results.available})"
puts "Показано: #{results.count}"

results.hits.each do |hit|
  puts "ID: #{hit['id']}"
  puts "Название: #{hit.dig('biblio', 'ru', 'title')}"
  puts "Дата: #{hit.dig('common', 'publication_date')}"
  puts "МПК: #{hit.dig('common', 'classification', 'ipc')&.map {|c| c['fullname']}&.join('; ')}"
  puts "---"
end
```

### Расширенные параметры фильтрации

Параметр `filter` поддерживает сложную фильтрацию с автоматической валидацией и преобразованием форматов:

#### Списочные фильтры (требуют формат `{"values": [...]}`)

```ruby
# Фильтры по классификации
results = client.search(
  q: "искусственный интеллект",
  filter: {
    "classification.ipc_group": { "values": ["G06N", "G06F"] },
    "classification.cpc_group": { "values": ["G06N3/", "G06N20/"] }
  }
)

# Фильтры по авторам и патентообладателям
results = client.search(
  q: "изобретение",
  filter: {
    "authors": { "values": ["Иванов И.И.", "Петров П.П."] },
    "patent_holders": { "values": ["ООО Компания"] },
    "country": { "values": ["RU", "US"] },
    "kind": { "values": ["A1", "U1"] }
  }
)

# Фильтры по ID документов
results = client.search(
  q: "устройство",
  filter: {
    "ids": { "values": ["RU134694U1_20131120", "RU2358138C1_20090610"] }
  }
)
```

#### Диапазонные фильтры по датам (требуют формат `{"range": {"operator": "YYYYMMDD"}}`)

```ruby
# Автоматическое преобразование формата дат
results = client.search(
  q: "инновация",
  filter: {
    "date_published": { "range": { "gte": "2020-01-01", "lte": "2023-12-31" } },
    "application.filing_date": { "range": { "gte": "2019-06-15" } }
  }
)

# Прямой формат API (YYYYMMDD)
results = client.search(
  q: "технология",
  filter: {
    "date_published": { "range": { "gte": "20200101", "lt": "20240101" } }
  }
)

# Использование объектов Date (автоматически конвертируются)
results = client.search(
  q: "патент",
  filter: {
    "application.filing_date": { 
      "range": { 
        "gte": Date.new(2020, 1, 1),
        "lte": Date.new(2023, 12, 31) 
      } 
    }
  }
)
```

**Поддерживаемые операторы дат**: `gt`, `gte`, `lt`, `lte`

**Преобразование формата дат**:
- `"2020-01-01"` → `"20200101"`
- `Date.new(2020, 1, 1)` → `"20200101"`
- `"20200101"` → `"20200101"` (без изменений)

#### Сложные составные фильтры

```ruby
# Комплексный пример фильтра
results = client.search(
  q: "машинное обучение",
  filter: {
    # Списочные фильтры
    "classification.ipc_group": { "values": ["G06N", "G06F"] },
    "country": { "values": ["RU", "US", "CN"] },
    "kind": { "values": ["A1", "A2"] },
    "authors": { "values": ["Иванов И.И."] },
    
    # Диапазонные фильтры по датам
    "date_published": { "range": { "gte": "2020-01-01", "lte": "2023-12-31" } },
    "application.filing_date": { "range": { "gte": "2019-01-01" } }
  },
  limit: 50
)
```

**Поддерживаемые поля фильтров**:

*Списочные фильтры (требуют формат `{"values": [...]}`)::*
- `authors` - Авторы патентов
- `patent_holders` - Патентообладатели/правопреемники
- `country` - Коды стран
- `kind` - Типы документов
- `ids` - Конкретные ID документов
- `classification.ipc*` - Коды классификации IPC
- `classification.cpc*` - Коды классификации CPC

*Фильтры по датам (требуют формат `{"range": {"operator": "YYYYMMDD"}}`)::*
- `date_published` - Дата публикации
- `application.filing_date` - Дата подачи заявки

**Валидация фильтров**:
- ✅ Автоматическая валидация названий полей
- ✅ Валидация структуры (списочный vs диапазонный формат)
- ✅ Преобразование и валидация формата дат
- ✅ Валидация операторов для диапазонов
- ✅ Полезные сообщения об ошибках для неверных фильтров

```ruby
# Эти примеры вызовут ValidationError с конкретными сообщениями:
client.search(
  q: "тест",
  filter: { "invalid_field": { "values": ["тест"] } }
)
# Ошибка: "Invalid filter field: invalid_field"

client.search(
  q: "тест", 
  filter: { "authors": ["прямой", "массив"] }  # Отсутствует обертка {"values": [...]}
)
# Ошибка: "Filter 'authors' requires format: {\"values\": [...]}"

client.search(
  q: "тест",
  filter: { "date_published": { "range": { "invalid_op": "20200101" } } }
)
# Ошибка: "Invalid range operator: invalid_op. Supported: gt, gte, lt, lte"
```

### Получение документов патентов

```ruby
# По идентификатору документа
patent = client.patent("RU134694U1_20131120")

# По компонентам идентификатора
patent_doc = client.patent_by_components(
  "RU",                   # country_code
  "134694",               # number
  "U1",                   # doc_type
  Date.new(2013, 11, 20)  # date (String или объект Date)
)

# Доступ к данным патента
title = patent_doc.dig('biblio', 'ru', 'title')
abstract = patent_doc.dig('abstract', 'ru')
inventors = patent_doc.dig('biblio', 'ru', 'inventor')
```
### Парсинг содержимого патента

Получение чистого текста или структурированного содержимого:

```ruby
# Парсинг аннотации
abstract_text = client.parse_abstract(patent_doc)
abstract_html = client.parse_abstract(patent_doc, format: :html)
abstract_ru = client.parse_abstract(patent_doc, language: "ru")

# Парсинг описания
description_text = client.parse_description(patent_doc)
description_html = client.parse_description(patent_doc, format: :html)

# Парсинг описания с разбивкой на секции
sections = client.parse_description(patent_doc, format: :sections)
sections.each do |section|
  puts "Секция #{section[:number]}: #{section[:content]}"
end
```

### Поиск похожих патентов

```ruby
# Поиск похожих патентов по ID
similar = client.similar_patents_by_id("RU134694U1_20131120", count: 50)

# Поиск похожих патентов по описанию текста
similar = client.similar_patents_by_text(
  "Ракетный двигатель с улучшенной тягой ...", # минимум 50 слов в запросе
  count: 25
)

# Обработка похожих патентов
similar["data"]&.each do |patent|
  puts "Похожий: #{patent['id']} (оценка: #{patent['similarity']} (#{patent['similarity_norm']}))"
end
```

### Поиск по классификаторам

Поиск в системах патентной классификации (IPC и CPC) и получение подробной информации о классификационных кодах:

```ruby
# Поиск классификационных кодов, связанных с ракетами в IPC
ipc_results = client.classification_search("ipc", query: "ракета", lang: "ru")
puts "Найдено #{ipc_results.size} кодов IPC"

ipc_results&.each do |result|
  puts "#{result['Code']}: #{result['Description']}"
end

# Поиск кодов, связанных с ракетами в CPC на английском
cpc_results = client.classification_search("cpc", query: "rocket", lang: "en")

# Получение подробной информации о конкретном классификационном коде
code, info = client.classification_code("ipc", code: "F02K9/00", lang: "ru")&.first
puts "Код: #{code}"
puts "Описание: #{info&.first['Description']}"
puts "Иерархия: #{info&.map{|level| level['Code']}&.join(' → ')}"

# Получение информации о коде CPC на английском
cpc_info = client.classification_code("cpc", code: "B63H11/00", lang: "en")
```

**Поддерживаемые системы классификации:**
- `"ipc"` - Международная патентная классификация (МПК)
- `"cpc"` - Совместная патентная классификация (СПК)

**Поддерживаемые языки:**
- `"ru"` - Русский
- `"en"` - Английский

### Список доступных датасетов

```ruby
datasets = client.datasets_tree
datasets.each do |category|
  puts "Категория: #{category['name_ru']}"
  category.children.each do |dataset|
    puts "  #{dataset['id']}: #{dataset['name_ru']}"
  end
end
```

### Медиафайлы и документы

```ruby
# Скачивание PDF патента
pdf_data = client.patent_media(
  "National",       # collection_id
  "RU",             # country_code
  "U1",             # doc_type
  "2013/11/20",     # pub_date
  "134694",         # pub_number
  "document.pdf"    # filename
)
File.write("patent.pdf", pdf_data)

# Упрощенный метод с использованием ID патента
pdf_data = client.patent_media_by_id(
  "RU134694U1_20131120",
  "National",
  "document.pdf"
)
```

## Расширенные возможности

### Пакетные операции

Эффективная обработка множества патентов с параллельными запросами:

```ruby
document_ids = ["RU134694U1_20131120", "RU2358138C1_20090610", "RU2756123C1_20210927"]

# Обработка патентов пакетами
client.batch_patents(document_ids, batch_size: 5) do |patent_doc|
  if patent_doc[:error]
    puts "Ошибка для #{patent_doc[:document_id]}: #{patent_doc[:error]}"
  else
    puts "Получен патент: #{patent_doc['id']}"
    # Обработка документа патента
  end
end

# Или сбор всех результатов
patents = []
client.batch_patents(document_ids) { |doc| patents << doc }
```

### Кеширование

Автоматическое интеллектуальное кеширование улучшает производительность:

```ruby
# Кеширование автоматическое и прозрачное
patent1 = client.patent("RU134694U1_20131120")  # API вызов
patent2 = client.patent("RU134694U1_20131120")  # Кешированный результат

# Проверка статистики кеша
stats = client.statistics
puts "Процент попаданий в кеш: #{stats[:cache_stats][:hit_rate_percent]}%"
puts "Всего запросов: #{stats[:requests_made]}"
puts "Среднее время ответа: #{stats[:average_request_time]}с"

# Использование общего кеша между клиентами
shared_cache = Rospatent.shared_cache
client1 = Rospatent.client(cache: shared_cache)
client2 = Rospatent.client(cache: shared_cache)

# Ручное управление кешем
shared_cache.clear                    # Очистить все кешированные данные
expired_count = shared_cache.cleanup_expired  # Удалить истекшие записи
cache_stats = shared_cache.statistics # Получить детальную статистику кеша
```

### Настройка логирования

Настройка детального логирования для мониторинга и отладки:

```ruby
# Создание собственного логгера
logger = Rospatent::Logger.new(
  output: Rails.logger,  # Или любой объект IO
  level: :info,
  formatter: :json      # :json или :text
)

client = Rospatent.client(logger: logger)

# Логи включают:
# - API запросы/ответы с временными метками
# - Операции кеша (попадания/промахи)
# - Детали ошибок с контекстом
# - Метрики производительности

# Доступ к общему логгеру
shared_logger = Rospatent.shared_logger(level: :debug)
```

**Комментарии**:
- При использовании `Rails.logger`, форматирование контролируется конфигурацией Rails, параметр `formatter` игнорируется
- При использовании IO объекта, формат определяется параметром `formatter`

### Обработка ошибок

Комплексная обработка ошибок с конкретными типами ошибок и улучшенным извлечением сообщений об ошибках:

```ruby
begin
  patent = client.patent("INVALID_ID")
rescue Rospatent::Errors::ValidationError => e
  puts "Неверный ввод: #{e.message}"
  puts "Ошибки полей: #{e.errors}" if e.errors.any?
rescue Rospatent::Errors::NotFoundError => e
  puts "Патент не найден: #{e.message}"
rescue Rospatent::Errors::RateLimitError => e
  puts "Ограничение скорости. Повторить через: #{e.retry_after} секунд"
rescue Rospatent::Errors::AuthenticationError => e
  puts "Ошибка аутентификации: #{e.message}"
rescue Rospatent::Errors::ApiError => e
  puts "Ошибка API (#{e.status_code}): #{e.message}"
  puts "ID запроса: #{e.request_id}" if e.request_id
  retry if e.retryable?
rescue Rospatent::Errors::ConnectionError => e
  puts "Ошибка соединения: #{e.message}"
  puts "Исходная ошибка: #{e.original_error}"
end

# Улучшенное извлечение сообщений об ошибках
# Клиент автоматически извлекает сообщения об ошибках из различных форматов ответов API:
# - {"result": "Сообщение об ошибке"}     (формат API Роспатента)
# - {"error": "Сообщение об ошибке"}      (стандартный формат)
# - {"message": "Сообщение об ошибке"}    (альтернативный формат)
# - {"details": "Детали валидации"}       (ошибки валидации)
```

### Валидация входных данных

Все входные данные автоматически валидируются с полезными сообщениями об ошибках:

```ruby
# Эти примеры вызовут ValidationError с конкретными сообщениями:
client.search(limit: 0)                    # "Limit must be at least 1"
client.patent("")                          # "Document_id cannot be empty"
client.similar_patents_by_text("", count: -1)  # Множественные ошибки валидации

# Валидация включает:
# - Типы и форматы параметров
# - Валидация формата ID патента
# - Валидация формата даты
# - Валидация значений перечислений
# - Валидация обязательных полей
```

### Мониторинг производительности

Отслеживание производительности и статистики использования:

```ruby
# Статистика конкретного клиента
stats = client.statistics
puts "Выполнено запросов: #{stats[:requests_made]}"
puts "Общая продолжительность: #{stats[:total_duration_seconds]}с"
puts "Среднее время запроса: #{stats[:average_request_time]}с"
puts "Процент попаданий в кеш: #{stats[:cache_stats][:hit_rate_percent]}%"

# Глобальная статистика
global_stats = Rospatent.statistics
puts "Окружение: #{global_stats[:configuration][:environment]}"
puts "Кеш включен: #{global_stats[:configuration][:cache_enabled]}"
puts "URL API: #{global_stats[:configuration][:api_url]}"
```

## Интеграция с Rails

### Генератор

```bash
$ rails generate rospatent:install
```

Это создает `config/initializers/rospatent.rb`:

```ruby
Rospatent.configure do |config|
  # Приоритет токена: Rails credentials > ROSPATENT_TOKEN > ROSPATENT_API_TOKEN
  config.token = Rails.application.credentials.rospatent_token || 
                 ENV["ROSPATENT_TOKEN"] || 
                 ENV["ROSPATENT_API_TOKEN"]
  
  # Конфигурация окружения учитывает ROSPATENT_ENV
  config.environment = ENV.fetch("ROSPATENT_ENV", Rails.env)
  
  # КРИТИЧНО: Переменные окружения имеют приоритет над настройками Rails
  # Это предотвращает появление DEBUG логов в продакшне при ROSPATENT_LOG_LEVEL=debug
  config.log_level = if ENV.key?("ROSPATENT_LOG_LEVEL")
                       ENV["ROSPATENT_LOG_LEVEL"].to_sym
                     else
                       Rails.env.production? ? :warn : :debug
                     end
  
  config.cache_enabled = Rails.env.production?
end
```

### Использование с логгером Rails

```ruby
# В config/initializers/rospatent.rb
Rospatent.configure do |config|
  config.token = Rails.application.credentials.rospatent_token
end

# Создание клиента с логгером Rails
logger = Rospatent::Logger.new(
  output: Rails.logger,
  level: Rails.env.production? ? :warn : :debug,
  formatter: :text
)

# Использование в контроллерах/сервисах
class PatentService
  def initialize
    @client = Rospatent.client(logger: logger)
  end

  def search_patents(query)
    @client.search(q: query, limit: 20)
  rescue Rospatent::Errors::ApiError => e
    Rails.logger.error "Поиск патентов не удался: #{e.message}"
    raise
  end
end
```

## Тестирование

### Запуск тестов

```bash
# Запуск всех тестов
$ bundle exec rake test

# Запуск конкретного тестового файла
$ bundle exec ruby -Itest test/unit/client_test.rb

# Запуск интеграционных тестов (требуется API токен)
$ ROSPATENT_INTEGRATION_TESTS=true ROSPATENT_TEST_TOKEN=ваш_токен bundle exec rake test_integration

# Запуск с покрытием
$ bundle exec rake coverage
```

### Настройка тестов

Для тестирования сбрасывайте и настраивайте в методе setup каждого теста:

```ruby
# test/test_helper.rb - Базовая настройка для модульных тестов
module Minitest
  class Test
    def setup
      Rospatent.reset  # Чистое состояние между тестами
      Rospatent.configure do |config|
        config.token = ENV.fetch("ROSPATENT_TEST_TOKEN", "test_token")
        config.environment = "development"
        config.cache_enabled = false  # Отключить кеш для предсказуемых тестов
        config.log_level = :error     # Уменьшить шум тестов
      end
    end
  end
end

# Для интеграционных тестов - стабильная конфигурация, сброс не нужен
class IntegrationTest < Minitest::Test
  def setup
    skip unless ENV["ROSPATENT_INTEGRATION_TESTS"]

    @token = ENV.fetch("ROSPATENT_TEST_TOKEN", nil)
    skip "ROSPATENT_TEST_TOKEN not set" unless @token

    # Сброс не нужен - интеграционные тесты используют согласованную конфигурацию
    Rospatent.configure do |config|
      config.token = @token
      config.environment = "development"
      config.cache_enabled = true
      config.log_level = :debug
    end
  end
end
```

### Пользовательские проверки (Minitest)

```ruby
# test/test_helper.rb
module Minitest
  class Test
    def assert_valid_patent_id(patent_id, message = nil)
      message ||= "Ожидается #{patent_id} как действительный ID патента (формат: XX12345Y1_YYYYMMDD)"
      assert patent_id.match?(/^[A-Z]{2}[A-Z0-9]+[A-Z]\d*_\d{8}$/), message
    end
  end
end

# Использование в тестах
def test_patent_id_validation
  assert_valid_patent_id("RU134694U1_20131120")
  assert_valid_patent_id("RU134694A_20131120")
end
```

## Известные ограничения API

Библиотека использует **Faraday** в качестве HTTP-клиента с поддержкой редиректов для всех endpoints:

- **Все endpoints** (`/search`, `/docs/{id}`, `/similar_search`, `/datasets/tree`, и т.д.) - ✅ Работают идеально с Faraday
- **Обработка редиректов**: Настроена с middleware `faraday-follow_redirects` для автоматической обработки серверных редиректов

⚠️ **Незначительные серверные ограничения**:
- **Поиск похожих патентов по тексту**: Иногда возвращает `503 Service Unavailable` (проблема сервера, не клиентской реализации)

⚠️ **Неточности документации**:
- **Поиск похожих патентов**: Массив совпадений в документации назван `hits`, фактическая реализация использует `data`
- **Перечень датасетов**: Ключ `name` в фактической реализации содержит признак локализации — `name_ru`, `name_en` 

Вся основная функциональность реализована и готова для продакшена.

## Справочник ошибок

### Иерархия ошибок

```
Rospatent::Errors::Error (базовая)
├── MissingTokenError
├── ApiError
│   ├── AuthenticationError (401)
│   ├── NotFoundError (404)
│   ├── RateLimitError (429)
│   └── ServiceUnavailableError (503)
├── ConnectionError
│   └── TimeoutError
├── InvalidRequestError
└── ValidationError
```

### Распространенные сценарии ошибок

```ruby
# Отсутствующий или недействительный токен
Rospatent::Errors::MissingTokenError
Rospatent::Errors::AuthenticationError

# Недействительные входные параметры
Rospatent::Errors::ValidationError

# Ресурс не найден
Rospatent::Errors::NotFoundError

# Ограничение скорости
Rospatent::Errors::RateLimitError  # Проверьте retry_after

# Проблемы с сетью
Rospatent::Errors::ConnectionError
Rospatent::Errors::TimeoutError

# Проблемы сервера
Rospatent::Errors::ServiceUnavailableError
```

## Rake задачи

Полезные задачи для разработки и обслуживания:

```bash
# Валидация конфигурации
$ bundle exec rake validate

# Управление кешем
$ bundle exec rake cache:stats
$ bundle exec rake cache:clear

# Генерация документации
$ bundle exec rake doc

# Запуск интеграционных тестов
$ ROSPATENT_INTEGRATION_TESTS=true ROSPATENT_TEST_TOKEN='<ваш_jwt_токен>' bundle exec rake test_integration

# Настройка среды разработки
$ bundle exec rake setup

# Проверки перед релизом
$ bundle exec rake release_check
```

## Советы по производительности

1. **Используйте кеширование**: Включите кеширование для повторяющихся запросов
2. **Пакетные операции**: Используйте `batch_patents` для множества документов
3. **Подходящие лимиты**: Не запрашивайте больше данных, чем необходимо
4. **Переиспользование соединений**: Используйте один экземпляр клиента когда возможно
5. **Конфигурация окружения**: Используйте продакшн настройки в продакшне

```ruby
# Хорошо: Переиспользование экземпляра клиента
client = Rospatent.client
patents = patent_ids.map { |id| client.patent(id) }

# Лучше: Использование пакетных операций
patents = []
client.batch_patents(patent_ids) { |doc| patents << doc }

# Отлично: Использование кеширования с общим экземпляром
shared_client = Rospatent.client(cache: Rospatent.shared_cache)
```

## Устранение неполадок

### Частые проблемы

**Ошибки аутентификации**:
```ruby
# Проверка валидности токена
errors = Rospatent.validate_configuration
puts errors if errors.any?
```

**Таймауты сети**:
```ruby
# Увеличение таймаута для медленных соединений
Rospatent.configure do |config|
  config.timeout = 120
  config.retry_count = 5
end
```

**Использование памяти**:
```ruby
# Ограничение размера кеша для окружений с ограниченной памятью
Rospatent.configure do |config|
  config.cache_max_size = 100
  config.cache_ttl = 300
end
```

**Отладка API вызовов**:
```ruby
# Включение подробного логирования
Rospatent.configure do |config|
  config.log_level = :debug
  config.log_requests = true
  config.log_responses = true
end
```

## Разработка

После клонирования репозитория выполните `bin/setup` для установки зависимостей. Затем запустите `rake test` для выполнения тестов.

### Настройка разработки

```bash
$ git clone https://hub.mos.ru/ad/rospatent.git
$ cd rospatent
$ bundle install
$ bundle exec rake setup
```

### Запуск тестов

```bash
# Модульные тесты
$ bundle exec rake test

# Интеграционные тесты (требуется API токен)
$ ROSPATENT_INTEGRATION_TESTS=true ROSPATENT_TEST_TOKEN=ваш_токен bundle exec rake test_integration

# Стиль кода
$ bundle exec rubocop

# Все проверки
$ bundle exec rake ci
```

### Интерактивная консоль

```bash
$ bin/console
```

## Содействие

Отчеты об ошибках и pull request приветствуются на MosHub по адресу https://hub.mos.ru/ad/rospatent.

### Руководство по разработке

1. **Пишите тесты**: Убедитесь, что все новые функции имеют соответствующие тесты
2. **Следуйте стилю**: Выполните `rubocop` и исправьте любые проблемы стиля
3. **Документируйте изменения**: Обновите README и CHANGELOG
4. **Валидируйте конфигурацию**: Запустите `rake validate` перед отправкой

### Процесс релиза

```bash
# Проверки перед релизом
$ bundle exec rake release_check

# Обновление версии и релиз
$ bundle exec rake release
```

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

---

## API Reference

For detailed API documentation, see the [generated documentation](https://rubydoc.info/gems/rospatent) or run:

```bash
$ bundle exec rake doc
$ open doc/index.html
```

**Key Classes**:
- `Rospatent::Client` - Main API client
- `Rospatent::Configuration` - Configuration management
- `Rospatent::Cache` - Caching system
- `Rospatent::Logger` - Structured logging
- `Rospatent::SearchResult` - Search result wrapper
- `Rospatent::PatentParser` - Patent content parsing

**Classification Features**:
- Classification system search (IPC/CPC)
- Detailed classification code information
- Multi-language support (Russian/English)
- Automatic caching of classification data

**Patent Features**:
- Patent search by text
- Patent details retrieval
- Patent classification retrieval
- Patent content parsing
- Patent media retrieval
- Patent similarity search by text
- Patent similarity search by ID

**Supported Ruby Versions**: Ruby 3.3.0+
