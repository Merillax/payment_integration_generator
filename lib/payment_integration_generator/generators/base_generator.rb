# frozen_string_literal: true

module PaymentIntegrationGenerator
  class BaseGenerator
    DEFAULT_OUTPUT_PATH = "lib/integrations"
    PARTIAL_INDENT_SIZE = 2

    def initialize(openapi_document:, integration_name:, output_folder_path: nil)
      @openapi_document = openapi_document
      @integration_name = integration_name
      @output_folder_path = output_folder_path
    end

    def call
      raise NotImplementedError
    end

    private

    def render_template(template, output_path, binding_context = binding)
      erb = ERB.new(template, trim_mode: "-")
      content = erb.result(binding_context)

      FileUtils.mkdir_p(File.dirname(output_path))
      File.write(output_path, content)
    end

    def render_partial(partial_name, locals = {}, binding_context = binding)
      template_path = File.join(TEMPLATES_DIR, "#{partial_name}.erb")
      template = File.read(template_path)

      context = OpenStruct.new(locals).instance_eval { binding }
      content = ERB.new(template, trim_mode: "-").result(context)

      indent = " " * 4
      content.lines.each_with_index.map do |line, i|
        i.zero? ? line : indent + line
      end.join
    end

    def output_path
      # TODO: default path should look for a Gemfile and then goes to DEFAULT_OUTPUT_PATH
      @output_folder_path || DEFAULT_OUTPUT_PATH
    end

    def snake_case(str)
      str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
         .gsub(/([a-z\d])([A-Z])/, '\1_\2')
         .tr("-", "_")
         .gsub(/\s+/, "_")
         .downcase
    end
  end
end
