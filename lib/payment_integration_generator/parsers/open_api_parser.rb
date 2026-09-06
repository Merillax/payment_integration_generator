# frozen_string_literal: true

# require_relative "../service_result_object/failure_result_object"
# require_relative "../service_result_object/success_result_object"

module PaymentIntegrationGenerator
  class OpenApiParser

    # @param url <String> адрес на OpenAPI спецификацию платежного сервиса
    # @param file_path <String> путь до файла с OpenAPI спецификацией платежного сервиса
    # @return <Void>
    def initialize(url: nil, file_path: nil)
      @url = url
      @file_path = file_path
    end

    # @return <Openapi3Parser::Document> спаршенный документ OpenAPI спецификации
    def parse
      validate

      document = if @file_path
                   Openapi3Parser.load_file(@file_path)
                 else
                   Openapi3Parser.load_url(@url)
                 end

      raise "OpenApi document parsing error (#{document.errors.map(&:message).join(", ")})" unless document.valid?

      document
    end

    private

    def validate
      return if @file_path.nil? || File.exist?(@file_path)

      raise "File #{@file_path} does not exist"
    end
  end
end
