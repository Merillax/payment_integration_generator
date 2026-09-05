# frozen_string_literal: true

module PaymentIntegrationGenerator
  class BaseSearcher
    def initialize(document:)
      @document = document
      @expected_result = nil
      @expected_score = 0
    end

    # @return <Array> returns uri and path_item of create_request method
    def call
      return @expected_result unless
      @document.paths.each { |uri, path| calculate_expected_result(uri, path) }
      @expected_result
    end

    private

    def calculate_expected_result
      raise NotImplementedError
    end
  end
end
