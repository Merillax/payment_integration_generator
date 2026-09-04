# frozen_string_literal: true

# === Gems ===
require "erb"
require "openapi3_parser"
require "ostruct"

# === Modules ===
require_relative "payment_integration_generator/version"
require_relative "payment_integration_generator/parsers/open_api_parser"
require_relative "payment_integration_generator/generators/base_generator"
require_relative "payment_integration_generator/generators/integration_generator"
require_relative "payment_integration_generator/searchers/base_searcher"
require_relative "payment_integration_generator/searchers/create_request_searcher"
require_relative "payment_integration_generator/cli"

module PaymentIntegrationGenerator
  TEMPLATES_DIR = "lib/templates"

  class Error < StandardError; end
  # Your code goes here...
end
