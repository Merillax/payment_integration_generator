# frozen_string_literal: true

module PaymentIntegrationGenerator
  module Generators
    class DocumentationGenerator < BaseGenerator
      def initialize(openapi_document:, integration_name:, output_folder_path: nil, searchers:)
        super(openapi_document:, integration_name:, output_folder_path:)
        @catalog = OpenApiOperationCatalog.new(document: openapi_document, searchers: searchers)
      end

      def call
        template = File.read(File.join(TEMPLATES_DIR, "integration_md.erb"))
        render_template(template, File.join(output_path, "INTEGRATION.md"), binding)
      end

      private

      def api_title = @catalog.api_title || "#{@integration_name} API"
      def api_description = @catalog.api_description || "Документация платёжной интеграции."
      def environments = @catalog.environments
      def extract_auth_info = @catalog.auth_info
      def operations = @catalog.operations
      def statuses = @catalog.statuses
      def errors = @catalog.errors
      def webhook_operations = @catalog.webhook_operations

      def pretty_example(value)
        return nil if value.nil?
        JSON.pretty_generate(value)
      rescue TypeError
        value.to_s
      end

      def snake_case(value)
        value.to_s.gsub(/([A-Z]+)([A-Z][a-z])/, '\\1_\\2').gsub(/([a-z\d])([A-Z])/, '\\1_\\2').tr("-", "_").gsub(/\s+/, "_").downcase
      end
    end
  end
end
