# frozen_string_literal: true

require "erb"

module PaymentIntegrationGenerator
  class IntegrationGenerator
    DEFAULT_OUTPUT_PATH = "lib/integrations"
    SUPPORTED_HTTP_METHODS = %i[get post put delete].freeze

    def initialize(openapi_document:, integration_name:, output_folder_path: nil)
      @openapi_document = openapi_document
      @integration_name = integration_name
      @output_folder_path = output_folder_path
    end

    def call
      # TODO: create output folder if doesn't exist
      generate_integration_class
    end

    private

    def render_template(template, output_path)
      erb = ERB.new(template, trim_mode: "-")
      content = erb.result(binding)

      FileUtils.mkdir_p(File.dirname(output_path))
      File.write(output_path, content)
    end

    def generate_integration_class
      template = File.read(File.join(TEMPLATES_DIR, "class.erb"))
      render_template(template, output_path + "/#{snake_case(@integration_name)}.rb")
    end

    def output_path
      # TODO: default path should look for a Gemfile and then goes to DEFAULT_OUTPUT_PATH
      @output_folder_path || DEFAULT_OUTPUT_PATH
    end

    # @param operation_item <Openapi3Parser::Node::Operation>
    # @return <String> method name for operation
    def collect_method_name(operation_item)
      snake_case(operation_item.operation_id)
    end

    def snake_case(str)
      str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
         .gsub(/([a-z\d])([A-Z])/, '\1_\2')
         .tr("-", "_")
         .gsub(/\s+/, "_")
         .downcase
    end

    # @param operation_item <Openapi3Parser::Node::Operation>
    # @return <String> args string for method. Example: "(id, order="desc")"
    def collect_method_args(operation_item)
      # TODO: collect args string
      ""
    end
  end
end
