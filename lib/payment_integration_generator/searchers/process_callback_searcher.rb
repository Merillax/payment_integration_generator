# frozen_string_literal: true

module PaymentIntegrationGenerator
  # Ищет в OpenAPI-спеке (версия 3.0) эндпоинт, соответствующий обработке
  # входящего уведомления от платёжного провайдера (callback/webhook о смене
  # статуса платежа или выплаты).
  class ProcessCallbackSearcher < BaseSearcher
    # Поля операции, по которым считается score при автоматическом поиске.
    FIELDS_TO_CHECK = %i[tags operation_id summary properties].freeze

    # Ключевые слова, указывающие на callback/webhook-эндпоинт, — для operationId.
    OPERATION_ID_KEYWORDS = %w[webhook callback notify notification event].freeze

    # Ключевые слова для tags — только существительные-ресурсы, без глаголов.
    TAGS_KEYWORDS = %w[
      webhook webhooks callback callbacks notification notifications
      вебхук вебхуки коллбэк уведомление уведомления
    ].freeze

    # Ключевые слова для summary/description=.
    SUMMARY_KEYWORDS = %w[
      webhook callback notify notification event уведомление коллбэк вебхук
      payout payment платеж выплата
    ].freeze

    # Ключевые слова для полей тела запроса (properties) — то, что обычно
    # присутствует в теле входящего уведомления о платеже/выплате.
    PROPERTIES_KEYWORDS = %w[event event_type type status payout_id payment_id error].freeze

    # Приоритет content-type при поиске схемы тела запроса — сначала JSON,
    # затем form-urlencoded, если JSON не объявлен эндпоинтом вообще.
    PREFERRED_CONTENT_TYPES = [
      "application/json",
      "application/x-www-form-urlencoded"
    ].freeze

    # Ключевые слова для поиска параметра/схемы авторизации, содержащей
    # подпись тела запроса — используются и для имени securityScheme,
    # и для имени обычного header-параметра операции.
    SIGNATURE_PARAM_KEYWORDS = %w[signature sign hmac подпись].freeze

    # Ключевые слова для поиска поля, содержащего тип/статус события,
    # среди свойств схемы тела запроса.
    STATUS_FIELD_KEYWORDS = %w[event event_type type status].freeze

    def initialize(document:)
      super(document: document)
    end

    # Ручной способ указать конкретный эндпоинт напрямую, минуя автоматический расчет

    # @param pattern [String] строка вида "POST /webhooks/payout-status"
    # @raise [ArgumentError] если по указанному пути и методу POST не найден
    # @return [void] результат сохраняется в @pattern_search_result
    def complete_pattern_search(pattern)
      method, endpoint = pattern.split(' ')

      unless @document.paths[endpoint]&.post
        raise ArgumentError, "Метод #{method} ендпойнта #{endpoint} не найден!"
      end

      @pattern_search_result = [endpoint, @document.paths[endpoint].post]
    end

    # Считает score для конкретной пары (путь, path_item) как кандидата на роль "process_callback"
    # @param uri [String] путь эндпоинта
    # @param path_item [Openapi3Parser::Node::PathItem] объект пути из спеки
    # @return [Hash, void] {} если эндпоинт не подходит по базовым условиям
    def calculate_automatic_search_result(uri, path_item)
      return unless path_item.post

      operation = path_item.post
      score = 0

      FIELDS_TO_CHECK.each do |field|
        field_value = field == :properties ? request_schema(operation)&.properties&.keys : operation.send(field)
        next unless field_value

        formatted_field_value = format_field_value(field_value)

        self.class.const_get("#{field.upcase}_KEYWORDS").each do |keyword|
          score += 1 if formatted_field_value.include?(keyword)
        end
      end

      # "payout.completed"/"payout.failed" (составное имя события через точку).
      score += 3 if event_enum_present?(operation)

      if score > @expected_score
        @expected_score = score
        @automatic_search_result = [uri, path_item.post]
      end
    end

    # Находит заголовок, в котором провайдер передаёт подпись тела запроса
    # Проверяет два независимых источника, в порядке приоритета:
    #   1. components.securitySchemes — apiKey-схема с in: header, имя которой
    #      похоже на "подпись" (signature/sign/hmac).
    #   2. parameters самой операции — обычный header-параметр с похожим именем,
  
    # @param operation [Openapi3Parser::Node::Operation] найденная callback-операция
    # @return [Hash, nil] хэш вида { name:, description: }, либо nil, если
    #   подходящий заголовок не найден ни в одном из источников
    def signature_header_name(operation)
      from_security_schemes(operation) || from_parameters(operation)
    end

    # Находит поле в теле запроса, содержащее тип/статус события
    #
    # @param operation [Openapi3Parser::Node::Operation] найденная callback-операция
    # @return [Hash, nil] хэш вида { name:, enum: }, где enum — массив строк
    def status_field(operation)
      schema = request_schema(operation)
      return nil unless schema&.properties

      event_like = schema.properties.find { |_name, prop| composite_enum?(prop) }
      return { name: event_like[0], enum: event_like[1].enum } if event_like

      field_name = schema.properties.keys.find { |name| status_field_keyword?(name) }
      return nil unless field_name

      { name: field_name, enum: schema.properties[field_name].enum }
    end

    private

    # @param field_value [String, Array, Openapi3Parser::Node::Array]
    # @return [String, Set]
    def format_field_value(field_value)
      if field_value.is_a?(Openapi3Parser::Node::Array) || field_value.is_a?(Array)
        new_set = Set.new
        field_value.each { |el| new_set << el.downcase }
        new_set
      else
        field_value.downcase
      end
    end

    # @param operation [Openapi3Parser::Node::Operation]
    # @return [Hash, nil] хэш вида { name:, description: } либо nil
    def from_security_schemes(operation)
      scheme_names = operation.security&.flat_map(&:keys) || []

      scheme_names.each do |name|
        scheme = @document.components.security_schemes[name]
        next unless scheme&.type == "apiKey" && scheme.in == "header" && signature_keyword?(scheme.name)

        return { name: scheme.name, description: scheme.description }
      end

      nil
    end

    # @param operation [Openapi3Parser::Node::Operation]
    # @return [Hash, nil] хэш вида { name:, description: } либо nil
    def from_parameters(operation)
      params = operation.parameters || []
      header_param = params.find { |p| p.in == "header" && signature_keyword?(p.name) }
      return nil unless header_param

      { name: header_param.name, description: header_param.description }
    end

    # @param name [String, nil]
    # @return [Boolean]
    def signature_keyword?(name)
      return false unless name

      normalized = name.downcase
      SIGNATURE_PARAM_KEYWORDS.any? { |kw| normalized.include?(kw) }
    end


    # @param property [Openapi3Parser::Node::Schema]
    # @return [Boolean]
    def composite_enum?(property)
      property.enum&.any? { |v| v.to_s.include?(".") } || false
    end

    # @param operation [Openapi3Parser::Node::Operation]
    # @return [Boolean]
    def event_enum_present?(operation)
      schema = request_schema(operation)
      return false unless schema&.properties

      schema.properties.any? { |_name, prop| composite_enum?(prop) }
    end

    # @param name [String, Symbol]
    # @return [Boolean]
    def status_field_keyword?(name)
      STATUS_FIELD_KEYWORDS.any? { |kw| name.to_s.downcase == kw }
    end

    # @param operation [Openapi3Parser::Node::Operation]
    # @return [Openapi3Parser::Node::Schema, nil]
    def request_schema(operation)
      content = operation.request_body&.content
      return nil unless content

      content_type = PREFERRED_CONTENT_TYPES.find { |ct| content.keys.include?(ct) } || content.keys.first
      content[content_type]&.schema
    end
  end
end