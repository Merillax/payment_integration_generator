# frozen_string_literal: true

module PaymentIntegrationGenerator
  class PayloadBuilder
    # @param mapping [Array<Hash>] маппинг payload, созданный PayloadMappingResolver
    def initialize(mapping:)
      @mapping = mapping
    end

    # @return [String] исходный код сгенерированного метода build_payout_payload
    def call
      [
        "# To customize field mappings, override PayloadMappingResolver#mapping_rules.",
        "# Review fields marked with TODO before using this integration.",
        "def build_payout_payload(operation)",
        "  {",
        render_fields(@mapping, 4),
        "  }",
        "end"
      ].join("\n")
    end

    private

    # @param fields [Array<Hash>] поля для генерации
    # @param indent [Integer] размер отступа
    # @return [String] сгенерированные поля Ruby-хэша
    def render_fields(fields, indent)
      fields.each_with_index.map do |field, index|
        render_field(field, indent, comma: index < fields.length - 1)
      end.join("\n")
    end

    # @param field [Hash] поле для генерации
    # @param indent [Integer] размер отступа
    # @param comma [Boolean] нужно ли добавить запятую
    # @return [String] сгенерированное Ruby-поле
    def render_field(field, indent, comma:)
      prefix = " " * indent
      key = ruby_key(field.fetch(:name))

      if field.fetch(:children).any?
        suffix = comma ? "," : ""
        "#{prefix}#{key} {\n#{render_fields(field.fetch(:children), indent + 2)}\n#{prefix}}#{suffix}"
      else
        separator = comma ? "," : ""
        todo = field[:todo] ? " # TODO: no matching mapping rule for #{field.fetch(:path)}" : ""
        "#{prefix}#{key} #{field.fetch(:expression)}#{separator}#{todo}"
      end
    end

    # @param name [String] имя поля
    # @return [String] ключ Ruby-хэша
    def ruby_key(name)
      name.match?(/\A[A-Za-z_]\w*\z/) ? "#{name}:" : "#{name.inspect} =>"
    end
  end
end
