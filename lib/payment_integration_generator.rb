# frozen_string_literal: true

# === Gems ===
require "erb"
require "openapi3_parser"
require "ostruct"
require "json"
require "set"

# === Modules ===
require_relative "payment_integration_generator/version"
require_relative "payment_integration_generator/parsers/open_api_parser"
require_relative "payment_integration_generator/generators/base_generator"
require_relative "payment_integration_generator/open_api_operation_catalog"
require_relative "payment_integration_generator/mappers/payload_mapping_resolver"
require_relative "payment_integration_generator/generators/payload_builder_generator"
require_relative "payment_integration_generator/generators/integration_generator"
require_relative "payment_integration_generator/generators/documentation_generator"
require_relative "payment_integration_generator/generators/fixtures_generator"
require_relative "payment_integration_generator/searchers/base_searcher"
require_relative "payment_integration_generator/searchers/create_request_searcher"
require_relative "payment_integration_generator/searchers/fetch_status_searcher"
require_relative "payment_integration_generator/searchers/process_callback_searcher"
require_relative "payment_integration_generator/searchers/check_conditions_searcher"
require_relative "payment_integration_generator/mappers/check_conditions_mapper"


require_relative "payment_integration_generator/cli"

module PaymentIntegrationGenerator
  TEMPLATES_DIR = "lib/templates"

  class Error < StandardError; end
  # Your code goes here...
end
