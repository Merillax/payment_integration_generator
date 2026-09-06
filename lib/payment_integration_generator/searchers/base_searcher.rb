# frozen_string_literal: true

module PaymentIntegrationGenerator
  class BaseSearcher
    def initialize(document:)
      @document = document
      @automatic_search_result = nil
      @pattern_search_result = nil
      @search_result = nil
      @expected_score = 0
      @todo_option = false
    end

    def automatic_search_result
      return @automatic_search_result if @automatic_search_result

      @document.paths.each { |uri, path| calculate_automatic_search_result(uri, path) }
      @automatic_search_result
    end

    def pattern_search_result(pattern)
      return @pattern_search_result if @pattern_search_result

      complete_pattern_search(pattern)
    end

    def search_result
      return nil if todo_option
      return @automatic_search_result if @pattern_search_result.nil?

      @pattern_search_result
    end

    # Релизовать этот метод в серчере откуда будет браться схема payload. Добавить этот серчер в константу IntegrationGenerator
    def payload_schema
      raise NotImplementedError
    end

    def enable_todo_option
      @todo_option = true
    end

    def todo_option
      @todo_option
    end

    def todo_message
      "TODO: не удалось однозначно определить эндпоинт создания выплаты в спеке — настройте вручную"
    end

    private

    def calculate_automatic_search_result(uri, path_item)
      raise NotImplementedError
    end

    def complete_pattern_search(pattern)
      raise NotImplementedError
    end
  end
end
