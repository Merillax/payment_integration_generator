# frozen_string_literal: true

module PaymentIntegrationGenerator
  class PayloadMappingResolver
    DEFAULT_MAPPING_RULES = {
      "amount" => "(operation.amount * 100).to_i",
      "currency" => "operation.currency",
      "external_id" => "operation.id",
      "recipient.type" => "'sbp'",
      "recipient.phone" => "operation.payout_requisite.dig('sbp', 'phone')",
      "recipient.bank_code" => "operation.payout_requisite.dig('sbp', 'bank_code')",
      "recipient.bank_name" => "operation.payout_requisite.dig('sbp', 'bank_name')"
    }.freeze

    # @param payload_schema [Openapi3Parser::Node::Schema]
    def initialize(payload_schema:)
      @payload_schema = payload_schema
    end

    # @return [Array<Hash>] payload fields and their mapping expressions
    def call
      map_fields(properties(@payload_schema))
    end

    # @return [Hash<String, String>] field paths and Ruby expressions
    def mapping_rules
      DEFAULT_MAPPING_RULES
    end

    private

    # @param fields [Hash] schema properties
    # @param parent_path [Array<String>] path of the parent fields
    # @return [Array<Hash>] mapped fields
    def map_fields(fields, parent_path = [])
      fields.map do |name, schema|
        build_field(name, schema, parent_path)
      end
    end

    # @param name [String, Symbol] field name
    # @param schema [Openapi3Parser::Node::Schema] field schema
    # @param parent_path [Array<String>] path of the parent fields
    # @return [Hash] mapped field
    def build_field(name, schema, parent_path)
      path = parent_path + [name.to_s]
      children = map_fields(properties(schema), path)
      field = { name: name.to_s, path: path.join("."), children: children }
      return field if children.any?

      expression = expression_for(path)
      return field.merge(expression: expression) if expression

      field.merge(expression: "nil", todo: true)
    end

    # @param path [Array<String>] field path
    # @return [String, nil] matching Ruby expression
    def expression_for(path)
      normalized_mapping_rules[normalize_path(path)] ||
        normalized_mapping_rules[normalize_field_name(path.last)]
    end

    # @return [Hash<String, String>] normalized mapping rules
    def normalized_mapping_rules
      @normalized_mapping_rules ||= mapping_rules.each_with_object({}) do |(field, expression), rules|
        rules[normalize_path(field.to_s.split("."))] = expression
      end
    end

    # @param path [Array<String>] field path
    # @return [String] normalized field path
    def normalize_path(path)
      path.map { |part| normalize_field_name(part) }.join(".")
    end

    # @param name [String, Symbol] field name
    # @return [String] normalized field name
    def normalize_field_name(name)
      name.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end

    def properties(schema)
      effective_schema(schema)&.properties || {}
    end

    def effective_schema(schema)
      schema&.type == "array" ? schema.items : schema
    end
  end
end
