# frozen_string_literal: true

module PaymentIntegrationGenerator
  # Ищет эндпоинт получения статуса платежа/выплаты (GET, путь с {id}).
  # Данные для scoring и status_field берутся из схемы ОТВЕТА, а не запроса.
  class FetchStatusSearcher < BaseSearcher
    # Поля операции, по которым считается score при автоматическом поиске.
    FIELDS_TO_CHECK = %i[tags operation_id summary properties].freeze

    # Ключевые слова, указывающие на fetch_status-эндпоинт, — для operationId.
    OPERATION_ID_KEYWORDS = %w[get show fetch retrieve status details].freeze

    # Ключевые слова для tags.
    TAGS_KEYWORDS = %w[payment payments payout payouts платеж выплата платежи выплаты].freeze

    # Ключевые слова для summary/description
    SUMMARY_KEYWORDS = %w[
      get show fetch retrieve status details получить показать статус детали
      payment payout payments payouts платеж выплата
    ].freeze

    # Ключевые слова для полей тела запроса (properties)
    PROPERTIES_KEYWORDS = %w[status state payout_status payment_status resultCode].freeze

    # Ключевые слова для поиска поля, содержащего тип/статус события,
    # среди свойств схемы тела запроса.
    STATUS_FIELD_KEYWORDS = %w[status state payout_status payment_status resultcode].freeze

    # content-type при поиске схемы тела запроса
    PREFERRED_CONTENT_TYPES = [
      "application/json",
      "application/x-www-form-urlencoded",
      "multipart/form-data"
    ].freeze

    # @param document [Openapi3Parser::Document] распарсенный OpenAPI-документ
    def initialize(document:)
      super(document: document)
    end

    # Ручной поиск по явно заданному пути, минуя автоматический scoring.
    # @param pattern [String] строка вида "GET /payouts/{payout_id}"
    # @return [void] результат сохраняется в @pattern_search_result
    def complete_pattern_search(pattern)
      method, endpoint = pattern.split(' ')

      unless @document.paths[endpoint]&.get
        raise ArgumentError, "Метод #{method} ендпойнта #{endpoint} не найден!"
      end

      @pattern_search_result = [endpoint, @document.paths[endpoint].get]
    end

    # Считает score операции как кандидата на роль "fetch_status".
    # @param uri [String] путь эндпоинта
    # @param path_item [Openapi3Parser::Node::PathItem] объект пути из спеки
    # @return [Hash, void] {} если эндпоинт не подходит по базовым условиям
    def calculate_automatic_search_result(uri, path_item)
      return unless path_item.get
      return unless uri.include?("{")   # тут параметр в пути обязателен, в отличие от create

      operation = path_item.get
      score = 0

      FIELDS_TO_CHECK.each do |field|
        field_value = field == :properties ? response_schema(operation)&.properties&.keys : operation.send(field)
        next unless field_value

        formatted_field_value = format_field_value(field_value)

        self.class.const_get("#{field.upcase}_KEYWORDS").each do |keyword|
          score += 1 if formatted_field_value.include?(keyword)
        end
      end

      if score > @expected_score
        @expected_score = score
        @automatic_search_result = [uri, path_item.get]
      end
    end

    # @param operation [Openapi3Parser::Node::Operation] найденная операция
    #   получения статуса (обычно path_item.get)
    # @return [Hash, nil] { name:, enum: }, где name — имя поля (String)
    def status_field(operation)
      schema = response_schema(operation)
      return nil unless schema&.properties

      enum_like = schema.properties.find { |name, prop| status_field_keyword?(name) && prop.enum }
      return { name: enum_like[0], enum: enum_like[1].enum } if enum_like

      field_name = schema.properties.keys.find { |name| status_field_keyword?(name) }
      return nil unless field_name

      { name: field_name, enum: schema.properties[field_name].enum }
    end

    private

    # @param field_value [String, Array<String>, Openapi3Parser::Node::Array]
    #   сырое значение поля операции (например tags или ключи properties)
    # @return [String, Set<String>] строка в нижнем регистре, если исходное
    #   значение было строкой; Set строк в нижнем регистре, если был массив
    def format_field_value(field_value)
      if field_value.is_a?(Openapi3Parser::Node::Array) || field_value.is_a?(Array)
        new_set = Set.new
        field_value.each { |el| new_set << el.downcase }
        new_set
      else
        field_value.downcase
      end
    end


    # @param name [String, Symbol] имя поля схемы
    # @return [Boolean]
    def status_field_keyword?(name)
      STATUS_FIELD_KEYWORDS.any? { |kw| name.to_s.downcase == kw }
    end

    # @param operation [Openapi3Parser::Node::Operation] операция, чей ответ анализируется
    # @return [Openapi3Parser::Node::Schema, nil] схема тела ответа, либо nil,
    #   если у операции нет ни 200, ни default ответа, либо у ответа нет content
    def response_schema(operation)
      response = operation.responses['200'] || operation.responses['default']
      return nil unless response

      content = response.content
      return nil unless content

      content_type = PREFERRED_CONTENT_TYPES.find { |ct| content.keys.include?(ct) } || content.keys.first
      content[content_type]&.schema
    end
  end
end
