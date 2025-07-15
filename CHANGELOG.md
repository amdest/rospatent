# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.2] - 2025-07-15

## Fixed
Updated the maximum length for the q and qn query parameters from 1000 to 2000 to accommodate larger input values in `Rospatent::Client#validate_search_params`.

## [1.4.1] - 2025-07-15

## Fixed
Updated the maximum length for the q and qn query parameters from 1000 to 2000 to accommodate larger input values in `Rospatent::Search#validate_and_normalize_params`.

## [1.4.0] - 2025-06-09

### Added
- **Optional Filename Parameter**: Enhanced `patent_media` and `patent_media_by_id` methods with optional filename parameter
  - Auto-generated filenames using formatted publication number + ".pdf" extension (e.g., "0000134694.pdf")
  - Leverages existing `format_publication_number` logic for reliable API compatibility
  - Provides convenient default behavior while maintaining full backward compatibility
- **Safe Binary File Handling**: New `save_binary_file` method for proper encoding of binary data
  - Ensures binary data (PDFs, images, etc.) is written correctly with ASCII-8BIT encoding
  - Prevents encoding conversion errors when saving media files
  - Includes comprehensive documentation and examples

### Fixed
- **Binary Data Encoding Issues**: Enhanced `handle_binary_response` method to properly handle binary data encoding
  - Forces ASCII-8BIT encoding to prevent UTF-8 conversion errors
  - Resolves `Encoding::UndefinedConversionError` when saving PDF and image files
  - Maintains proper binary data integrity throughout the request lifecycle

### Changed
- **Enhanced Media Method Documentation**: Updated documentation with auto-generated filename examples
  - Added examples showing both convenience (auto-filename) and explicit filename approaches
  - Enhanced code examples in both English and Russian README sections
  - Improved documentation structure with clear usage recommendations
- **Comprehensive Test Coverage**: Enhanced test suite with auto-generated filename functionality
  - Added specific tests for optional filename parameter behavior
  - Updated existing tests to accommodate new method signatures
  - Enhanced integration tests with fallback filename strategies
- **README Improvements**: Updated Key Features section to remove hardcoded test counts
  - Replaced specific numbers with qualitative descriptions of testing coverage
  - Improved maintainability by removing numbers that become outdated quickly
  - Enhanced focus on testing quality rather than raw metrics

## [1.3.2] - 2025-06-07

### Added
- Notes about logger `formatter` parameter behavior when using `Rails.logger` as `output`

## [1.3.1] - 2025-06-06

### Fixed
- **Include Facets Parameter Handling**: Fixed critical bug in `include_facets` parameter validation and API format conversion
  - Fixed boolean validation logic that incorrectly converted `false` values to `true`
  - Added proper boolean-to-numeric conversion for API compliance (true → 1, false → 0)
  - Enhanced validation to handle various input formats ("true", "false", 0, 1, etc.)
  - Updated documentation with conversion behavior notes
- **Rails Logger Compatibility**: Fixed TypeError when using `Rails.logger` with `Rospatent::Logger`
  - Added intelligent duck typing to detect existing logger instances vs IO objects
  - `Rails.logger` can now be passed directly without creating wrapper Logger instances
  - Maintains full compatibility with file paths, IO objects, and custom loggers
  - Added comprehensive test coverage for Rails integration scenarios

### Changed
- Enhanced `Rospatent::Logger` to accept existing logger instances (Rails.logger, custom loggers) in addition to IO objects
- Improved boolean parameter validation across the gem with better edge case handling
- Updated README documentation with Rails.logger usage examples and boolean parameter conversion notes

### Added
- New comprehensive test suite for Logger class covering Rails integration scenarios
- Test coverage for include_facets boolean-to-numeric conversion with various input types

## [1.3.0] - 2025-01-02

### Added
- **Complete Filter Parameter Validation System**: Comprehensive overhaul of filter parameter handling with API compliance
  - New `validate_filter()`, `validate_filter_values()`, `validate_filter_range()`, and `validate_filter_date()` methods
  - Field validation for all supported filter fields (authors, patent_holders, country, kind, ids, classification codes, dates)
  - Structure validation requiring `{"values": [...]}` format for list filters and `{"range": {"operator": "YYYYMMDD"}}` for date filters
  - Automatic date format conversion from "YYYY-MM-DD" and Date objects to "YYYYMMDD" API format
  - Comprehensive error messages for invalid filter structures and unsupported fields
- **Enhanced Highlight Parameter Support**: Complete rewrite according to API specification
  - New `validate_string_or_array()` method for tag validation
  - Support for independent `pre_tag` and `post_tag` parameters (both required together)
  - Support for string or array tag values for multi-color highlighting
  - Advanced `highlight` parameter for profile-based highlighting configuration
- **Improved Error Message Extraction**: Enhanced error handling for Rospatent API responses
  - Error parsing now checks `"result"` field (Rospatent API format) in addition to standard `"error"` and `"message"` fields
  - Updated `extract_validation_errors()` to check `"details"` field for validation errors
  - Applied improvements to both `handle_response()` and `handle_binary_response()` methods
- **String Enum Validation**: New `validate_string_enum()` method preserving string types for API compliance
- **Comprehensive Test Coverage**: Added 49+ new tests covering filter validation, highlight functionality, error handling scenarios
- **Enhanced Rails Integration**: Improved Rails initializer with proper environment variable priority handling

### Fixed
- **Group_by Parameter API Compliance**: Fixed to use correct API values `"family:docdb"` and `"family:dwpi"` instead of symbol conversion
- **Environment Variable Priority Issues**: Fixed Rails initializer to prevent DEBUG logs in production when `ROSPATENT_LOG_LEVEL=debug` is set
- **Filter Parameter Missing Issue**: Added missing `filter` parameter to `validate_search_params` validation rules
- **Token Configuration Priority**: Improved token loading priority (Rails credentials → `ROSPATENT_TOKEN` → `ROSPATENT_API_TOKEN`)
- **Configuration Environment Conflicts**: Fixed `load_environment_config` to only override values not explicitly set by environment variables

### Changed
- **Input Validation Type System**: Extended to support `:string_enum`, `:string_or_array`, and `:hash` validation types
- **Search Parameter Validation**: Updated client validation to use correct API-compliant parameter types and values
- **Test Suite Growth**: Expanded from 170 to 219 tests with 465 assertions, all passing with comprehensive integration testing
- **Documentation Overhaul**: Major README updates with comprehensive filter examples, environment variable documentation, and Rails integration guides
- **Configuration Management**: Enhanced environment variable handling with clear priority documentation and troubleshooting guides

### Security
- **Input Validation Strengthening**: Stricter validation prevents invalid requests from reaching API endpoints
- **Environment Configuration Hardening**: Improved handling of sensitive configuration in different environments

## [1.2.0] - 2025-06-04

### Added
- Binary data support for `patent_media` and `patent_media_by_id` methods to properly handle PDF, image, and other media files
- New `binary` parameter for `get` method to distinguish between JSON and binary responses
- New `handle_binary_response` method for processing binary API responses with proper error handling
- Russian patent number formatting with automatic zero-padding to 10 digits
- New `format_publication_number` private method for consistent number formatting across media methods

### Fixed
- API endpoint paths for `classification_search` and `classification_code` methods now include trailing slashes to prevent 404 errors
- Binary data corruption issue when downloading patent media files (PDFs, images) through media endpoints

### Changed
- Enhanced test coverage for binary data handling and publication number formatting
- Updated README documentation for classification search examples and dataset display conventions
- Improved error handling consistency for binary vs JSON responses

## [1.1.0] - 2025-06-04

### Added
- Word count validation for `similar_patents_by_text` method (minimum 50 words required)
- New `validate_text_with_word_count` validation method with configurable minimum word requirements
- Staging environment configuration documentation and examples
- Enhanced Russian documentation sections

### Changed
- Improved error handling for insufficient word count with descriptive messages showing current vs required count
- Error type changed from `InvalidRequestError` to `ValidationError` for text validation consistency

### Fixed
- Documentation clarifications for similar patents API response format (`data` vs `hits` naming)
- Updated README examples to use correct API response structure
- Corrected minimum word requirements documentation for text-based similarity search

## [1.0.0] - 2025-06-03

### Added
- Initial release with full search functionality
- Support for all Rospatent API search parameters
- Configurable client with token-based authentication
- Error handling for API requests
- Rails initializer generator
- Comprehensive test suite
