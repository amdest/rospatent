# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
