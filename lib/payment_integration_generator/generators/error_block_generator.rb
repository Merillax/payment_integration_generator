# frozen_string_literal: true

module PaymentIntegrationGenerator
  # Форматирует уже готовые данные от ErrorMapper.call(parsed) в текст кода:
  #   - rescue-блоки для create_request (по resolved)
  #   - TODO-комментарии по кодам, которые не удалось распознать (unresolved)
  #   - общий TODO на весь метод, если result[:todo] == true
  #   - константу ERROR_MAP
  #
  # Ничего не анализирует заново — только форматирует.
  class ErrorBlockGenerator
    # failure_symbol -> имя класса исключения. Список ограничен стандартными
    # HTTP-статусами, как и должно быть (не выдумываем :novapay_whatever).
    EXCEPTION_CLASS_MAP = {
      bad_request: "BadRequestError",
      unauthorized: "UnauthorizedError",
      forbidden: "ForbiddenError",
      not_found: "NotFoundError",
      unprocessable_entity: "ValidationError",
      too_many_requests: "RateLimitError",
      internal_server_error: "ServerError",
      service_unavailable: "ServiceUnavailableError",
      payment_required: "PaymentRequiredError",
      conflict: "ConflictError"
    }.freeze

    # @param resolved [Array<Hash>] result[:resolved] из ErrorMapper.call
    # @return [String] rescue-блоки, каждый на отдельных строках, без отступа
    #   (отступ добавляется уже в ERB-шаблоне)
    def self.rescue_block(resolved)
      return "" if resolved.empty?

      resolved.map { |entry| rescue_line(entry) }.join("\n")
    end

    # @param unresolved [Array<Hash>] result[:unresolved] из ErrorMapper.call
    #   (каждый элемент — { status:, raw_code: })
    # @return [String] один TODO-комментарий на каждый нераспознанный код,
    #   пустая строка, если unresolved пуст
    def self.todo_comments(unresolved)
      return "" if unresolved.empty?

      unresolved.map { |entry| todo_line(entry) }.join("\n")
    end

    # @param result [Hash] result из ErrorMapper.call (нужен только result[:todo])
    # @return [String] TODO + raise NotImplementedError на весь метод,
    #   если result[:todo] == true (ни один способ определить ошибки не сработал);
    #   пустая строка, если todo == false
    def self.method_level_todo(result)
      return "" unless result[:todo]

      "# TODO: не удалось определить обработку ошибок ни через статусы, ни через тело ответа — настройте вручную\n" \
        "raise NotImplementedError, \"create_request: обработка ошибок не определена\""
    end

    # @param parsed [Hash] результат ErrorStatusParser.call(operation)
    # @return [String] текст константы ERROR_MAP как Ruby-код, готовый к вставке
    def self.error_map(parsed)
      hash = ErrorMapper.error_map(parsed)
      return "ERROR_MAP = {}.freeze" if hash.empty?

      lines = hash.map { |status, key| "  #{status} => '#{key}'" }
      "ERROR_MAP = {\n#{lines.join(",\n")}\n}.freeze"
    end

    def self.rescue_line(entry)
      exception_class = EXCEPTION_CLASS_MAP.fetch(entry[:failure_symbol], "UnknownError")
      "rescue Provider::#{exception_class}\n  failure(:#{entry[:failure_symbol]}, '#{entry[:key]}')"
    end

    def self.todo_line(entry)
      code_hint = entry[:raw_code] ? " (код провайдера: \"#{entry[:raw_code]}\")" : ""
      "# TODO: статус #{entry[:status]}#{code_hint} — не удалось сопоставить с известной ошибкой, настройте вручную"
    end

    private_class_method :rescue_line, :todo_line
  end
end