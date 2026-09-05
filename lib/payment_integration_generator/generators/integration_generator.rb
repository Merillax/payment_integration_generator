# frozen_string_literal: true

module PaymentIntegrationGenerator
  class IntegrationGenerator < BaseGenerator
    DEFAULT_OUTPUT_PATH = "lib/integrations"
    PARTIAL_INDENT_SIZE = 4

    SUPPORTED_HTTP_METHODS = %i[get post put delete].freeze

    PROVIDER_PUBLIC_METHODS = %i[create_request fetch_status process_callback check_conditions].freeze
    PROVIDER_PRIVATE_METHODS = %i[build_payout_payload errors_mapping status_mapping].freeze

    SEARCHERS = %i[create_request_searcher fetch_status_searcher process_callback_searcher check_conditions_searcher]
    SEARCHERS_TO_INITIALIZE = %i[create_request_searcher]
    def initialize(openapi_document:, integration_name:, output_folder_path: nil)
      super(openapi_document:, integration_name:, output_folder_path:)
    end

    def call
      # TODO: create output folder if doesn't exist
      generate_integration_class
    end

    def initialize_searchers
      SEARCHERS.each do |searcher|
        camelized_name = camelize(searcher.to_s)
        searcher_class = PaymentIntegrationGenerator.const_get(camelized_name)
        instance_variable_set("@#{searcher.to_s}", searcher_class.new(document: @openapi_document))
        self.class.define_method(searcher) do
          instance_variable_get("@#{searcher.to_s}")
        end
      end

      SEARCHERS_TO_INITIALIZE.each do |searcher|
        send(searcher).automatic_search_result
      end
    end

    def available_searchers
      SEARCHERS_TO_INITIALIZE
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

    def camelize(str)
      str.split('_').map(&:capitalize).join
    end
  end
end
