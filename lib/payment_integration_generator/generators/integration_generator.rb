# frozen_string_literal: true

module PaymentIntegrationGenerator
  class IntegrationGenerator < BaseGenerator
    DEFAULT_OUTPUT_PATH = "lib/integrations"
    PARTIAL_INDENT_SIZE = 4

    SUPPORTED_HTTP_METHODS = %i[get post put delete].freeze

    PROVIDER_PUBLIC_METHODS = %i[create_request fetch_status process_callback check_conditions].freeze
    PROVIDER_PRIVATE_METHODS = %i[build_payout_payload errors_mapping status_mapping].freeze

    SEARCHERS = %i[create_request_searcher fetch_status_searcher process_callback_searcher check_conditions_searcher]
    SEARCHERS_TO_INITIALIZE = %i[create_request_searcher fetch_status_searcher process_callback_searcher]
    SEARCHER_FROM_TAKE_PAYLOAD_SCHEMA = :create_request_searcher
      
    METHODS_TO_GENERATE_EXCEPTIONS_BLOCK = %i[create_request]
    def initialize(openapi_document:, integration_name:, output_folder_path: nil)
      super(openapi_document:, integration_name:, output_folder_path:)
    end

    def call
      initialize_methods_exceptions_blocks
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

      self.class.define_method(:payload_schema) do
        send(SEARCHER_FROM_TAKE_PAYLOAD_SCHEMA).payload_schema
      end
    end

    def initialize_methods_exceptions_blocks
      all_errors = []
      METHODS_TO_GENERATE_EXCEPTIONS_BLOCK.each do |method_name|
        next unless self.class.method_defined?("#{method_name}_searcher".to_sym)
        error_generator_data = PaymentIntegrationGenerator::ErrorBlockGenerator.call(send("#{method_name}_searcher".to_sym).search_result[1])
        all_errors << error_generator_data
        self.class.define_method("#{method_name.to_s}_exceptions_block".to_sym) do
          error_generator_data
        end
      end

      self.class.define_method(:errors_mapping_exceptions_block) do
        PaymentIntegrationGenerator::ErrorBlockGenerator.combined_error_map(all_errors)
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
