# frozen_string_literal: true

require_relative "lib/rospatent/version"

Gem::Specification.new do |spec|
  spec.name = "rospatent"
  spec.version = Rospatent::VERSION
  spec.authors = ["Aleksandr Dryzhuk"]
  spec.email = ["dev@ad-it.pro"]

  spec.summary = "Ruby client for Rospatent API with caching and validation"
  spec.description = "A comprehensive Ruby client for interacting with the Rospatent patent search API. " \
                     "Features include automatic caching, request validation, structured logging, " \
                     "error handling, and batch operations for efficient patent data retrieval."
  spec.homepage = "https://github.com/amdest/rospatent"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/master/README.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["wiki_uri"] = "#{spec.homepage}/wiki"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.13"
  spec.add_dependency "faraday-follow_redirects", "~> 0.3"
  spec.add_dependency "faraday-retry", "~> 2.3"

  spec.add_development_dependency "minitest", "~> 5.20"
  spec.add_development_dependency "rubocop", "~> 1.76"
  spec.add_development_dependency "rubocop-minitest", "~> 0.38"
  spec.add_development_dependency "rubocop-rake", "~> 0.7"

  spec.metadata["rubygems_mfa_required"] = "true"
end
