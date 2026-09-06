# frozen_string_literal: true

module PaymentIntegrationGenerator
  class ErrorMapper
    # Стандартные HTTP-коды -> символ. Покрывает коды провайдеров
    
    STATUS_TO_SYMBOL = {
      400 => :bad_request,
      401 => :unauthorized,
      403 => :forbidden,
      404 => :not_found,
      409 => :conflict,
      422 => :unprocessable_entity,
      429 => :too_many_requests,
      500 => :internal_server_error,
      502 => :bad_gateway,
      503 => :service_unavailable
    }.freeze

    # Слева — одно каноническое имя на всю систему, справа — известные
    # варианты написания у разных провайдеров (сравниваются в нижнем регистре).
    CANONICAL_BUSINESS_ERRORS = {
      "insufficient_funds" => %w[insufficient_balance low_balance not_enough_funds insufficient_funds insufficientfunds],
      "card_declined" => %w[card_declined generic_decline do_not_honor declined transaction_not_permitted],
      "card_expired" => %w[expired_card cardexpired card_expired],
      "invalid_card" => %w[incorrect_cvc invalid_card_number invalidcardnumber invalid_card],
      "invalid_recipient" => %w[recipient_not_found invalid_recipient bad_recipient account_not_found],
      "bank_unavailable" => %w[bank_unavailable bank_timeout bank_error issuer_unavailable],
      "limit_exceeded" => %w[amount_limit_exceeded limit_exceeded max_amount_exceeded amount_too_low amount_too_high],
      "duplicate_request" => %w[duplicate idempotency_conflict already_exists duplicate_batch_payout_request_id duplicate_order],
      "validation_error" => %w[validation_error invalid_request bad_request invalid_resource_id invalid_amount],
      "insufficient_scope" => %w[invalid_scope insufficient_scope]
    }.freeze

    CANONICAL_FAILURE_SYMBOLS = {
      "insufficient_funds" => :payment_required,
      "card_declined" => :payment_required,
      "card_expired" => :payment_required,
      "invalid_card" => :unprocessable_entity,
      "invalid_recipient" => :not_found,
      "bank_unavailable" => :service_unavailable,
      "limit_exceeded" => :unprocessable_entity,
      "duplicate_request" => :conflict,
      "validation_error" => :unprocessable_entity,
      "insufficient_scope" => :forbidden
    }.freeze

    # @param parsed [Hash] результат ErrorStatusParser.call(operation),
    #   то есть { via_status: [...], via_body: {...} | nil }
    # @return [Hash] { resolved:, unresolved:, via_body:, todo: }
    #   resolved   — [{ status:, key:, failure_symbol: }, ...] из via_status
    #   unresolved — [{ status:, raw_code: }, ...] — код есть, но не сопоставлен
    #   via_body   — то, что пришло от парсера, без изменений
    #   todo       — true, только если resolved и via_body ОБА пустые
    #                (нет вообще ни одного способа понять, что случилось)
    def self.call(parsed)
      resolved, unresolved = map_via_status(parsed[:via_status] || [])

      {
        resolved: resolved,
        unresolved: unresolved,
        via_body: parsed[:via_body],
        todo: resolved.empty? && parsed[:via_body].nil?
      }
    end

    # @param parsed [Hash] результат ErrorStatusParser.call(operation)
    # @return [Hash{Integer => String}] готовый ERROR_MAP, например
    #   { 401 => "unauthorized", 402 => "insufficient_funds" }.
    #   Строится только из via_status — у via_body нет HTTP-кода, который
    #   можно было бы использовать как ключ такой таблицы.
    def self.error_map(parsed)
      call(parsed)[:resolved].each_with_object({}) { |entry, map| map[entry[:status].to_i] = entry[:key] }
    end

    def self.map_via_status(entries)
      resolved = []
      unresolved = []

      entries.each do |entry|
        if entry[:universal]
          symbol = STATUS_TO_SYMBOL[entry[:status].to_i] || :internal_server_error
          resolved << { status: entry[:status], key: symbol.to_s, failure_symbol: symbol }
          next
        end

        canonical = entry[:raw_code] && find_canonical(entry[:raw_code])

        if canonical
          resolved << { status: entry[:status], key: canonical, failure_symbol: CANONICAL_FAILURE_SYMBOLS[canonical] }
        else
          unresolved << { status: entry[:status], raw_code: entry[:raw_code] }
        end
      end

      [resolved, unresolved]
    end

    def self.find_canonical(raw_code)
      normalized = raw_code.to_s.downcase
      CANONICAL_BUSINESS_ERRORS.each { |canonical, variants| return canonical if variants.include?(normalized) }
      nil
    end

    private_class_method :map_via_status, :find_canonical
  end
end