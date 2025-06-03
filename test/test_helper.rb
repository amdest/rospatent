# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rospatent"
require "rospatent/input_validator"
require "rospatent/cache"
require "rospatent/logger"

require "minitest/autorun"
require "minitest/pride"

# Reset configuration between tests
module Minitest
  class Test
    def setup
      Rospatent.reset
      Rospatent.configure do |config|
        config.token = ENV.fetch("ROSPATENT_TEST_TOKEN", "test_token")
        config.environment = "development"
        config.cache_enabled = false  # Disable cache for predictable tests
        config.log_level = :error     # Reduce test noise
      end
    end
  end
end
