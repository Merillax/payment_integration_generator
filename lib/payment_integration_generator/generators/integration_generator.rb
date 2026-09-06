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
    # @param openapi_document [Openapi3Parser::Node::Document] parsed OpenAPI document
    # @param integration_name [String] generated integration name
    # @param output_folder_path [String, nil] generated files destination
    # @param payload_mapping_resolver [Class<PayloadMappingResolver>] mapping resolver class
    def initialize(
      openapi_document:,
      integration_name:,
      output_folder_path: nil,
      payload_mapping_resolver: PayloadMappingResolver
    )
      @payload_mapping_resolver = payload_mapping_resolver
      @searchers_initialized = false
      super(openapi_document:, integration_name:, output_folder_path:)
    end

    def call
      initialize_searchers unless @searchers_initialized
      generate_integration_class
    end

    def initialize_searchers
      return if @searchers_initialized

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

      @searchers_initialized = true
    end

    def available_searchers
      SEARCHERS_TO_INITIALIZE
    end

    # @return [Array<Hash>] payload mapping for the selected request schema
    def payload_mapping
      initialize_searchers unless @searchers_initialized
      return [] if @create_request_searcher.todo_option

      @payload_mapping ||= @payload_mapping_resolver.new(
        payload_schema: @create_request_searcher.payload_schema
      ).call
    end

    # @return [String] generated build_payout_payload method source
    def payload_method_source
      initialize_searchers unless @searchers_initialized

      @payload_method_source ||= build_payload_method_source
    end

    private

    # @return [String] generated payload method source
    def build_payload_method_source
      return PayloadBuilder.new(mapping: payload_mapping).call unless @create_request_searcher.todo_option

      <<~RUBY.chomp
        def build_payout_payload(operation)
          # TODO: implement payload mapping manually
          {}
        end
      RUBY
    end

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
