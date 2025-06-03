# frozen_string_literal: true

require "rails/generators"

module Rospatent
  module Generators
    # Generator for installing Rospatent configuration into a Rails application
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Creates a Rospatent initializer for a Rails application"

      def create_initializer_file
        template "initializer.rb", "config/initializers/rospatent.rb"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end
