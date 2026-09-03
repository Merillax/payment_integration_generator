# frozen_string_literal: true

# === Gems ===
require "erb"
require "openapi3_parser"

# === Modules ===
require_relative "payment_integration_generator/version"
require_relative "payment_integration_generator/parsers/open_api_parser"
require_relative "payment_integration_generator/generators/integration_generator"
require_relative "payment_integration_generator/cli"

module PaymentIntegrationGenerator
  TEMPLATES_DIR = "lib/templates"

  class Error < StandardError; end
  # Your code goes here...
end
