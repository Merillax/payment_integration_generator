# frozen_string_literal: true

module PaymentIntegrationGenerator
  class IntegrationGenerator < BaseGenerator
    DEFAULT_OUTPUT_PATH = "lib/integrations"
    PARTIAL_INDENT_SIZE = 4

    SUPPORTED_HTTP_METHODS = %i[get post put delete].freeze

    PROVIDER_PUBLIC_METHODS = %i[create_request fetch_status process_callback check_conditions].freeze
    PROVIDER_PRIVATE_METHODS = %i[build_payout_payload errors_mapping status_mapping].freeze

    def initialize(openapi_document:, integration_name:, output_folder_path: nil)
      super(openapi_document:, integration_name:, output_folder_path:)
    end

    def call
      # TODO: create output folder if doesn't exist
      generate_integration_class
    end

    private

    def generate_integration_class
      template = File.read(File.join(TEMPLATES_DIR, "class.erb"))
      render_template(template, output_path + "/#{snake_case(@integration_name)}_service.rb", binding)
    end

    # @param operation_item <Openapi3Parser::Node::Operation>
    # @return <String> method name for operation
    def collect_method_name(operation_item)
      snake_case(operation_item.operation_id)
    end

    def provider_default_url
      @openapi_document.servers.first.url
    end
  end
end
