# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

begin
  require "yard"
  yard_available = true
rescue LoadError
  yard_available = false
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

RuboCop::RakeTask.new

# YARD documentation task (optional)
if yard_available
  YARD::Rake::YardocTask.new(:doc) do |t|
    t.files = ["lib/**/*.rb"]
    t.options = ["--markup=markdown", "--readme=README.md"]
  end
else
  desc "Generate documentation (YARD not available)"
  task :doc do
    puts "YARD is not available. Install it with: gem install yard"
  end
end

# Integration tests (requires ROSPATENT_INTEGRATION_TESTS env var)
Rake::TestTask.new(:test_integration) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/integration/**/*_test.rb"]
  t.warning = false
end

# Performance benchmarks
task :benchmark do
  puts "Running performance benchmarks..."
  ruby "test/benchmark/client_benchmark.rb"
end

# Cache statistics and cleanup
namespace :cache do
  desc "Display cache statistics for shared resources"
  task :stats do
    require_relative "lib/rospatent"

    if Rospatent.instance_variable_get(:@shared_cache)
      stats = Rospatent.shared_cache.statistics
      puts "Cache Statistics:"
      puts "  Size: #{stats[:size]} entries"
      puts "  Hits: #{stats[:hits]}"
      puts "  Misses: #{stats[:misses]}"
      puts "  Hit Rate: #{stats[:hit_rate_percent]}%"
      puts "  Evictions: #{stats[:evictions]}"
      puts "  Expired: #{stats[:expired]}"
    else
      puts "No shared cache initialized"
    end
  end

  desc "Clear shared cache"
  task :clear do
    require_relative "lib/rospatent"
    Rospatent.clear_shared_resources
    puts "Shared cache cleared"
  end
end

# Validation task
desc "Validate current configuration"
task :validate do
  require_relative "lib/rospatent"

  errors = Rospatent.validate_configuration
  if errors.empty?
    puts "✓ Configuration is valid"
  else
    puts "✗ Configuration errors:"
    errors.each { |error| puts "  - #{error}" }
    exit 1
  end
end

# Coverage report
desc "Generate test coverage report"
task :coverage do
  ENV["COVERAGE"] = "true"
  Rake::Task[:test].invoke
end

# Clean task
desc "Clean generated files"
task :clean do
  FileUtils.rm_rf("doc")
  FileUtils.rm_rf("coverage")
  FileUtils.rm_rf("pkg")
end

# Setup task for development
desc "Setup development environment"
task :setup do
  puts "Installing dependencies..."
  system("bundle install") || abort("Failed to install dependencies")

  puts "Running initial tests..."
  Rake::Task[:test].invoke

  puts "✓ Development environment ready"
end

task default: %i[test rubocop]
task ci: %i[test rubocop validate]
task release_check: %i[clean test rubocop validate doc]
