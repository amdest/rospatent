# frozen_string_literal: true

require "rails/railtie"

module Rospatent
  class Railtie < ::Rails::Railtie
    # Ensure generators are loaded when Rails loads
    generators do
      require "generators/rospatent/install/install_generator"
    end

    # Configure Rails integration
    config.before_configuration do
      # Ensure generators are discoverable
    end

    # Add Rails-specific initializer
    initializer "rospatent.configure" do
      # Set Rails-friendly defaults
      if defined?(::Rails.logger) && Rospatent.configuration.log_level == :debug
        # Use Rails logger in development
        Rospatent.configuration.instance_variable_set(:@rails_integration, true)
      end
    end
  end
end
