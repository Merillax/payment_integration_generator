# frozen_string_literal: true

module PaymentIntegrationGenerator
  class CreateRequestSearcher < BaseSearcher
    def initialize(document:)
      super(document: document)

      @search_matcher = proc do |_uri, path_item|
        path_item&.post&.operation_id == "createPayout"
      end
    end
  end
end
