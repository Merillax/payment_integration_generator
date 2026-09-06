# frozen_string_literal: true

module PaymentIntegrationGenerator
  # Ищет в OpenAPI-спеке эндпоинт, соответствующий созданию платежа/выплаты
  # (метод create_request в сгенерированном клиенте).
  class CreateRequestSearcher < BaseSearcher
    # Поля операции, по которым считается score при автоматическом поиске.
    FIELDS_TO_CHECK = %i[tags operation_id summary properties]

    # Ключевые слова для operationId — глаголы создания в любой раскладке
    # (post/init/create/register/add/new) плюс корни ресурса (payout/payment).
    OPERATION_ID_KEYWORDS = %w[post init create register add new payout payouts payment payments]

    # Ключевые слова для tags — только существительные-ресурсы, без глаголов.
    TAGS_KEYWORDS = %w[payment payments payout payouts charge charge платеж выплата платежи выплаты]

    # Ключевые слова для summary/description.
    SUMMARY_KEYWORDS = %w[create register init initiate add создать создание инициировать инициирование
      payment payout charge payments payouts charges выплата платеж выплат платежей выплаты платежи]

    # Приоритет content-type при поиске схемы тела запроса.
    PREFERRED_CONTENT_TYPES = [
      "application/json",
      "application/x-www-form-urlencoded",
      "multipart/form-data"
    ].freeze

    # Ключевые слова для полей тела запроса (properties).
    PROPERTIES_KEYWORDS = %w[amount currency destination receiver recipient_type]

    def initialize(document:)
      super(document: document)
    end


    def payload_schema
      _, path_item = @pattern_search_result || @automatic_search_result
      return nil unless path_item

      path_schema(path_item.post)
    end

    # Ручной способ указать конкретный эндпоинт напрямую, минуя автоматический поиск
    # @param pattern [String] строка вида "POST /payouts"
    # @raise [ArgumentError] если по указанному пути и методу POST не найден
    # @return [void] результат сохраняется в @pattern_search_result
    def complete_pattern_search(pattern)
      method, endpoint = pattern.split(' ')

      unless @document.paths[endpoint]&.post
        raise ArgumentError, "Метод #{method} ендпойнта #{endpoint} не найден!"
      end
      @pattern_search_result = [endpoint, @document.paths[endpoint]]
    end

    # Считает score для конкретной пары (путь, path_item) как кандидата на роль "create_request"
    # @param uri [String] путь эндпоинта
    # @param path_item [Openapi3Parser::Node::PathItem] объект пути из спеки
    # @return [Hash, void] {} если эндпоинт не подходит по базовым условиям
    def calculate_automatic_search_result(uri, path_item)
      return unless path_item.post
      return if uri.include?("{")

      operations = path_item.post
      score = 0
      FIELDS_TO_CHECK.each do |field|
        field_value = field == :properties ? path_schema(operations)&.properties&.keys : operations.send(field)
        next unless field_value

        formatted_field_value = if field_value.is_a?(Openapi3Parser::Node::Array) || field_value.is_a?(Array)
          new_set = Set.new
          field_value.each do |el|
            new_set << el.downcase
          end
        else
          field_value.downcase
        end
        self.class.const_get("#{field.upcase}_KEYWORDS").each { |keyword| score += 1 if formatted_field_value.include?(keyword) }
      end

      if score > @expected_score
        @expected_score = score
        @automatic_search_result = [uri, path_item]
      end
    end

    private

    # @param operations [Openapi3Parser::Node::Operation] операция (path_item.post)
    # @return [Openapi3Parser::Node::Schema, nil] схема тела запроса, либо nil,
    #   если у операции нет requestBody вообще
    def path_schema(operations)
      content = operations.request_body&.content
      return nil unless content

      content_type = PREFERRED_CONTENT_TYPES.find { |ct| content.keys.include?(ct) }
      content_type ||= content.keys.first 

      content[content_type]&.schema
    end
  end
end