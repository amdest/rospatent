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
- 🧪 **Comprehensive Testing** - 96% test coverage with integration tests
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
# Basic configuration
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

### Environment Variables

Configure via environment variables:

```bash
ROSPATENT_ENV=production
ROSPATENT_CACHE_ENABLED=true
ROSPATENT_CACHE_TTL=600
ROSPATENT_LOG_LEVEL=info
ROSPATENT_POOL_SIZE=10
```

### Environment-Specific Defaults

The gem automatically adjusts settings based on environment:

- **Development**: Fast timeouts, verbose logging, short cache TTL
- **Staging**: Moderate settings for testing
- **Production**: Longer timeouts, optimized for reliability

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
  limit: 20,
  offset: 0,
  filter: {
    "classification.ipc_group": { "values": ["F02K9"] },
    "biblio.application_date": { "from": "2020-01-01" }
  },
  sort: :pub_date,
  group_by: :patent_family,
  include_facets: true,
  highlight: true,
  pre_tag: "<mark>",
  post_tag: "</mark>"
)

# Process results
puts "Found #{results.total} total results (#{results.available} available)"
puts "Showing #{results.count} results"

results.hits.each do |hit|
  puts "ID: #{hit['id']}"
  puts "Title: #{hit.dig('biblio', 'ru', 'title')}"
  puts "Date: #{hit.dig('biblio', 'publication_date')}"
  puts "IPC: #{hit.dig('classification', 'ipc')}"
  puts "---"
end
```

### Retrieving Patent Documents

```ruby
# Get patent by document ID
patent_doc = client.patent("RU134694U1_20131120")

# Get patent by components
patent_doc = client.patent_by_components(
  "RU",                    # country_code
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

### Media and Documents

```ruby
# Download patent PDF
pdf_data = client.patent_media(
  "National",        # collection_id
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

# Get available datasets
datasets.each do |category|
  puts "Category: #{category['name_en']}"
  category.children.each do |dataset|
    puts "  #{dataset['id']}: #{dataset['name_en']}"
  end
end
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

### Error Handling

Comprehensive error handling with specific error types:

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

## Environment Configuration

### Development Environment

```ruby
# Optimized for development
Rospatent.configure do |config|
  config.environment = "development"
  config.token = ENV['ROSPATENT_DEV_TOKEN']
  config.log_level = :debug
  config.log_requests = true
  config.log_responses = true
  config.cache_ttl = 60          # Short cache for development
  config.timeout = 10            # Fast timeouts for quick feedback
end
```

### Staging Environment

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

### Production Environment

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

## Rails Integration

### Generator

```bash
$ rails generate rospatent:install
```

This creates `config/initializers/rospatent.rb`:

```ruby
Rospatent.configure do |config|
  config.token = Rails.application.credentials.rospatent_token
  config.environment = Rails.env
  config.cache_enabled = Rails.env.production?
  config.log_level = Rails.env.production? ? :warn : :debug
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
$ bundle exec rake test_integration

# Performance benchmarks
$ bundle exec rake benchmark

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
- 🧪 **Комплексное тестирование** - 96% покрытие тестами с интеграционными тестами
- 📚 **Отличная документация** - подробные примеры и документация API

## Быстрый старт

### Установка

Добавьте в ваш Gemfile:

```ruby
gem 'rospatent'
```

Или установите напрямую:

```bash
$ gem install rospatent
```

### Базовая настройка

```ruby
require 'rospatent'

# Настройка клиента
Rospatent.configure do |config|
  config.token = "ваш_jwt_токен"
end

# Создание клиента
client = Rospatent.client
```

## Основное использование

### Поиск патентов

```ruby
# Простой поиск
results = client.search(q: "солнечная батарея")

# Расширенный поиск с фильтрами
results = client.search(
  q: "искусственный интеллект",
  limit: 50,
  offset: 100,
  datasets: ["ru_since_1994"],
  sort: "pub_date:desc",
  highlight: true
)

# Обработка результатов
puts "Найдено: #{results.total} патентов"
results.hits.each do |patent|
  puts "#{patent['id']}: #{patent['title']}"
end
```

### Получение документов патентов

```ruby
# По идентификатору документа
patent = client.patent("RU134694U1_20131120")

# Парсинг содержимого
abstract = client.parse_abstract(patent)
description = client.parse_description(patent, format: :text)

puts "Реферат: #{abstract}"
puts "Описание: #{description}"
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

### Медиафайлы и документы

```ruby
# Скачивание PDF патента
pdf_data = client.patent_media(
  "National",        # collection_id
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

# Получение доступных датасетов
datasets = client.datasets_tree
datasets.each do |category|
  puts "Категория: #{category['name_ru']}"
  category.children.each do |dataset|
    puts "  #{dataset['id']}: #{dataset['name_ru']}"
  end
end
```

## Расширенные возможности

### Пакетные операции

```ruby
patent_ids = ["RU134694U1_20131120", "RU2358138C1_20090610"]

client.batch_patents(patent_ids) do |patent|
  puts "Обработка: #{patent['id']}"
  # Ваша логика обработки
end
```

### Кеширование

```ruby
# Конфигурация кеша
Rospatent.configure do |config|
  config.cache_enabled = true
  config.cache_ttl = 600        # 10 минут
  config.cache_max_size = 1000  # Максимум элементов
end

# Статистика кеша
stats = client.statistics
puts "Попаданий в кеш: #{stats[:cache_stats][:hits]}"
```

### Обработка ошибок

```ruby
begin
  results = client.search(q: "поисковый запрос")
rescue Rospatent::Errors::AuthenticationError => e
  puts "Ошибка аутентификации: #{e.message}"
rescue Rospatent::Errors::RateLimitError => e
  puts "Превышен лимит запросов: #{e.message}"
rescue Rospatent::Errors::ApiError => e
  puts "Ошибка API: #{e.message}"
end
```

## Настройка окружения

### Разработка

```ruby
# Оптимизировано для разработки
Rospatent.configure do |config|
  config.environment = "development"
  config.token = ENV['ROSPATENT_DEV_TOKEN']
  config.log_level = :debug
  config.log_requests = true
  config.log_responses = true
  config.cache_ttl = 60          # Короткий кеш для разработки
  config.timeout = 10            # Быстрые таймауты для быстрой обратной связи
end
```

### Staging

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

### Продакшн

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

## Интеграция с Rails

```ruby
# config/initializers/rospatent.rb
Rospatent.configure do |config|
  config.token = Rails.application.credentials.rospatent_token
  config.environment = Rails.env
  config.cache_enabled = Rails.env.production?
  config.log_level = Rails.env.production? ? :warn : :debug
end

# В контроллере или сервисе
class PatentService
  def initialize
    @client = Rospatent.client
  end

  def search_patents(query, **options)
    @client.search(q: query, **options)
  end
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

## Тестирование

### Запуск тестов

```bash
# Все тесты
$ bundle exec rake test

# Конкретный тестовый файл
$ bundle exec ruby -Itest test/unit/client_test.rb

# Интеграционные тесты (требуется API токен)
$ ROSPATENT_INTEGRATION_TESTS=true ROSPATENT_TEST_TOKEN=ваш_токен bundle exec rake test_integration

# Запуск с покрытием
$ bundle exec rake coverage
```

### Настройка тестов

```ruby
# test/test_helper.rb
module Minitest
  class Test
    def setup
      Rospatent.reset
      Rospatent.configure do |config|
        config.token = ENV.fetch("ROSPATENT_TEST_TOKEN", "test_token")
        config.environment = "development"
        config.cache_enabled = false
        config.log_level = :error
      end
    end
  end
end
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
