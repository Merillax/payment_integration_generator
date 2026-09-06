# frozen_string_literal: true

module PaymentIntegrationGenerator
  class BaseGenerator
    DEFAULT_OUTPUT_PATH = "lib/integrations"
    PARTIAL_INDENT_SIZE = 2

    SUPPORTED_HTTP_METHODS = %i[get post put delete].freeze

    # @param openapi_document <Openapi3Parser::Document> обработанная спецификация интеграции
    # @param integration_name <String> имя интеграции
    # @param output_folder_path <String> директория для генерации файлов
    def initialize(openapi_document:, integration_name:, output_folder_path: nil)
      @openapi_document = openapi_document
      @integration_name = integration_name
      @output_folder_path = output_folder_path
    end

    def call
      raise NotImplementedError
    end

    private

    # Заполнение .erb шаблона данными с передачей текущего контекста
    # @param template <Sting> .erb шаблон
    # @param output_path <String> директория для генерации файлов
    # @param binding_context <Binding> текущий контекст возвращаемый методом #binding
    # @return <Void> в результате будет создан заполненный файл на основе шаблона
    def render_template(template, output_path, binding_context = binding)
      erb = ERB.new(template, trim_mode: "-")
      content = erb.result(binding_context)

      FileUtils.mkdir_p(File.dirname(output_path))
      File.write(output_path, content)
    end

    # Заполнение встраемоевого шаблона .erb с передачей текущего контекста
    # @param partial_name <Sting> название .erb шаблон
    # @param locals <Hash> передаваемые в шаблон параметры
    # @param binding_context <Binding> текущий контекст возвращаемый методом #binding
    # @return <String> заполненный шаблон
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

    # @return <String> путь до результирующей директории
    def output_path
      @output_folder_path || DEFAULT_OUTPUT_PATH
    end

    # @param str <String>
    # @return <String> строка в snake case
    def snake_case(str)
      str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
         .gsub(/([a-z\d])([A-Z])/, '\1_\2')
         .tr("-", "_")
         .gsub(/\s+/, "_")
         .downcase
    end
  end
end
