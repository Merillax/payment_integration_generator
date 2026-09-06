# frozen_string_literal: true

module PaymentIntegrationGenerator
  class ErrorBlockGenerator
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

    # @param operation [Openapi3Parser::Node::Operation] найденная create-операция
    # @return [Hash] { rescue_block:, todo_comments:, method_level_todo:,
    #                  error_map:, raw_error_map:, todo: }.
    def self.call(operation)
      parsed = ErrorStatusParser.call(operation)
      result = ErrorMapper.call(parsed)
      raw_error_map = ErrorMapper.error_map(parsed)

      {
        rescue_block: rescue_block(result[:resolved]),
        todo_comments: todo_comments(result[:unresolved]),
        method_level_todo: method_level_todo(result),
        error_map: error_map_text(raw_error_map),
        raw_error_map: raw_error_map,
        todo: result[:todo]
      }
    end
    
    # @param results [Array<Hash>] массив результатов call(operation),
    #   вызванных ранее для каждого метода клиента
    # @return [String] текст константы ERROR_MAP, готовый к вставке
    def self.combined_error_map(results)
      merged = results.each_with_object({}) do |result, acc|
        acc.merge!(result[:raw_error_map]) { |_status, existing, _new| existing }
      end
 
      todo = results.map { |result| result[:todo_comments] }.reject(&:empty?).join("\n")
 
      { todo: todo, error_map: error_map_text(merged) }
    end

    def self.rescue_block(resolved)
      return "" if resolved.empty?

      resolved.map { |entry| rescue_line(entry) }.join("\n")
    end

    def self.todo_comments(unresolved)
      return "" if unresolved.empty?

      unresolved.map { |entry| todo_line(entry) }.join("\n")
    end

    def self.method_level_todo(result)
      return "" unless result[:todo]

      "# TODO: не удалось определить обработку ошибок ни через статусы, ни через тело ответа — настройте вручную\n" \
        "raise NotImplementedError, \"create_request: обработка ошибок не определена\""
    end

    def self.error_map_text(hash)
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

    private_class_method :rescue_line, :todo_line, :error_map_text
  end
end