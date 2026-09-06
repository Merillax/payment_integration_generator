# frozen_string_literal: true

module PaymentIntegrationGenerator
  # Парсит спеку операции и достаёт "сырые" данные об ошибках
  #  - via_status — коды 4xx/5xx в responses.
  #  - via_body — поля-маркеры внутри схемы УСПЕШНОГО (200) ответа.
  class ErrorStatusParser
    UNIVERSAL_STATUSES = %w[401 403 429 500 503].freeze
    SUCCESS_FIELD_NAMES = %w[success ok].freeze
    ERROR_CODE_FIELD_NAMES = %w[error_code errorcode resultcode].freeze
    ERROR_MESSAGE_FIELD_NAMES = %w[message error_message errormessage msg].freeze
    FAILURE_ENUM_VALUES = %w[failed refused declined error].freeze

    # @param operation [Openapi3Parser::Node::Operation] найденная операция
    # @return [Hash] { via_status: [...], via_body: {...} | nil }
    #   via_status — массив вида [{ status:, universal:, raw_code: }, ...]
    #   via_body   — { success_field:, error_code_field:, error_message_field:,
    #                  status_field: } либо nil, если признаков не найдено
    def self.call(operation)
      { via_status: parse_via_status(operation), via_body: parse_via_body(operation) }
    end

    def self.parse_via_status(operation)
      return [] unless operation&.responses

      success_schema = response_schema(operation.responses["200"] || operation.responses["201"])

      operation.responses.each_with_object([]) do |(status, response), result|
        next unless status.to_s.start_with?("4", "5")

        schema = response_schema(response)
        next if same_shape?(schema, success_schema)

        if UNIVERSAL_STATUSES.include?(status.to_s)
          result << { status: status.to_s, universal: true, raw_code: nil }
        else
          result << { status: status.to_s, universal: false, raw_code: extract_raw_code_from_example(response) }
        end
      end
    end

    def self.parse_via_body(operation)
      schema = response_schema(operation&.responses&.[]("200") || operation&.responses&.[]("201"))
      return nil unless schema&.properties

      names = schema.properties.keys
      success_field = names.find { |n| SUCCESS_FIELD_NAMES.include?(n.to_s.downcase) }
      error_code_field = names.find { |n| ERROR_CODE_FIELD_NAMES.include?(n.to_s.downcase) }
      error_message_field = names.find { |n| ERROR_MESSAGE_FIELD_NAMES.include?(n.to_s.downcase) }
      status_field = schema.properties.find { |_n, p| p.enum&.any? { |v| FAILURE_ENUM_VALUES.include?(v.to_s.downcase) } }&.first

      return nil unless success_field || (error_code_field && error_message_field) || status_field

      { success_field: success_field, error_code_field: error_code_field,
        error_message_field: error_message_field, status_field: status_field }
    end

    def self.response_schema(response)
      return nil unless response&.content

      content_type = response.content.keys.first
      response.content[content_type]&.schema
    end

    def self.same_shape?(schema_a, schema_b)
      return false unless schema_a&.properties && schema_b&.properties

      schema_a.properties.keys.sort == schema_b.properties.keys.sort
    end

    def self.extract_raw_code_from_example(response)
      return nil unless response&.content

      content_type = response.content.keys.first
      example = response.content[content_type]&.example
      return nil unless example

      nested = example["error"]
      return nested["code"] if nested.respond_to?(:[]) && nested["code"]

      example["code"] || example["error_code"]
    end

    private_class_method :response_schema, :same_shape?, :extract_raw_code_from_example
  end
end