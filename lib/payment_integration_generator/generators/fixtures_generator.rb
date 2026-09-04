# frozen_string_literal: true

module PaymentIntegrationGenerator
  module Generators
    class FixturesGenerator < BaseGenerator
      def initialize(openapi_document:, integration_name:, output_folder_path: nil)
        super
        @catalog = OpenApiOperationCatalog.new(document: openapi_document)
      end

      def call
        file_path = File.join(output_path, "fixtures.json")
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, JSON.pretty_generate(fixtures_data))
        file_path
      end

      private

      def fixtures_data
        return legacy_payout_fixtures if @catalog.payout_api?
        { operations: operation_fixtures, webhooks: webhook_fixtures }
      end

      def operation_fixtures
        @catalog.operations.each_with_object({}) do |operation, result|
          result[operation_key(operation)] = {
            method: operation[:verb], path: operation[:path],
            request: @catalog.request_example(operation),
            responses: @catalog.response_examples(operation)
          }
        end
      end

      def webhook_fixtures
        @catalog.webhook_operations.each_with_object({}) do |operation, result|
          result[operation_key(operation)] = {
            method: operation[:verb], path: operation[:path],
            payload: @catalog.request_example(operation),
            responses: @catalog.response_examples(operation)
          }
        end
      end

      def legacy_payout_fixtures
        create = @catalog.payout_operations.find { |item| create_operation?(item) } || @catalog.payout_operations.first
        status = @catalog.payout_operations.find { |item| status_operation?(item) }
        callback = @catalog.webhook_operations.first
        responses = @catalog.response_examples(create)
        {
          create_request: { request: @catalog.request_example(create), response_201: first_success_response(responses), response_422: response_for(responses, /422|validation|invalid/) },
          fetch_status: { response_200: first_success_response(@catalog.response_examples(status)) },
          callback: callback_fixture(callback, /completed|success|paid/),
          callback_failed: callback_fixture(callback, /failed|cancelled|rejected/)
        }
      end

      def callback_fixture(operation, pattern)
        status = matching_status(pattern)
        payload = @catalog.request_example(operation, status: status)
        payload = deep_replace_status(payload, status) if payload
        { payload: payload, expected_operation_status: @catalog.local_status(status) }
      end

      def create_operation?(operation)
        "#{operation[:id]} #{operation[:path]}".downcase.match?(/create|init|charge|payment|pay|deposit|order/)
      end

      def status_operation?(operation)
        "#{operation[:id]} #{operation[:path]}".downcase.match?(/status|check|state|info/)
      end

      def operation_key(operation)
        snake_case(operation[:id].to_s)
      end

      def first_success_response(responses)
        response_for(responses, /\A2\d\d\z/) || responses.values.first
      end

      def response_for(responses, pattern)
        responses.find { |code, _value| code.to_s.match?(pattern) }&.last
      end

      def matching_status(pattern)
        @catalog.status_values.find { |status| status.match?(pattern) } || @catalog.status_values.first || "completed"
      end

      def deep_replace_status(value, status)
        case value
        when Hash
          value.each_with_object({}) { |(key, item), result| result[key] = key.to_s.downcase.match?(/status|state/) ? status : deep_replace_status(item, status) }
        when Array then value.map { |item| deep_replace_status(item, status) }
        else value
        end
      end

      def snake_case(value)
        value.to_s.gsub(/([A-Z]+)([A-Z][a-z])/, '\\1_\\2').gsub(/([a-z\d])([A-Z])/, '\\1_\\2').tr("-", "_").gsub(/\s+/, "_").downcase
      end
    end
  end
end
