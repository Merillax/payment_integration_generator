# frozen_string_literal: true

module PaymentIntegrationGenerator
  class BaseSearcher
    def initialize(document:)
      @document = document
      @search_matcher = nil
    end

    # @return <Array> returns uri and path_item of create_request method
    def call
      @document.paths.find do |uri, path|
        search_matcher.call(uri, path)
      end
    end

    private

    def search_matcher
      raise NotImplementedError if @search_matcher.nil?

      @search_matcher
    end
  end
end
