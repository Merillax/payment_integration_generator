# frozen_string_literal: true

module PaymentIntegrationGenerator
  class OpenApiOperationCatalog
    HTTP_METHODS = %i[get post put delete patch].freeze

    def initialize(document:)
      @document = document
    end

    def api_title
      @document.info&.title
    end

    def api_description
      clean(@document.info&.description)
    end

    def environments
      return [] unless @document.respond_to?(:servers) && @document.servers

      @document.servers.map { |server| { name: server.description || "Environment", url: server.url } }
    end

    def auth_info
      schemes = @document.components&.security_schemes
      return { type: "Не указан", header: nil, description: nil } unless schemes

      scheme = values(schemes).find { |item| item.type == "apiKey" } || values(schemes).find { |item| item.type == "http" }
      return { type: "Не указан", header: nil, description: nil } unless scheme

      if scheme.type == "apiKey"
        { type: "API key", header: scheme.name, description: clean(scheme.description) }
      else
        { type: scheme.scheme.to_s.capitalize, header: "Authorization", description: clean(scheme.description) }
      end
    end

    def operations
      @operations ||= begin
        result = []
        @document.paths&.each do |path, path_item|
          HTTP_METHODS.each do |verb|
            operation = path_item.public_send(verb) if path_item.respond_to?(verb)
            result << operation_info(path, verb, operation, path_item) if operation
          end
        end
        result
      end
    end

    def webhook_operations
      operations.select do |item|
        item[:tags].any? { |tag| tag.to_s.downcase.include?("webhook") } ||
          item[:path].to_s.downcase.include?("webhook") ||
          item[:id].to_s.downcase.include?("callback")
      end
    end

    def payout_operations
      operations.reject { |item| webhook_operations.include?(item) }
    end

    def payout_api?
      text = operations.map { |item| "#{item[:id]} #{item[:path]}" }.join(" ").downcase
      text.match?(/payout|withdraw|withdrawal|callback/) && payout_operations.any? { |item| create_operation?(item) }
    end

    def schemas
      @document.components&.schemas || {}
    end

    def statuses
      values = []
      schemas.each do |_name, schema|
        schema.properties&.each do |field_name, field|
          values.concat(field.enum.to_a.map(&:to_s)) if field_name.to_s.downcase.match?(/status|state/) && field.enum
        end
      end
      values.uniq.map { |status| [status, local_status(status)] }
    end

    def errors
      seen = {}
      operations.each do |operation|
        operation[:responses].each do |response|
          next if response[:code].to_s.start_with?("2")
          seen[response[:code].to_s] ||= { code: response[:code], description: response[:description] }
        end
      end
      seen.values
    end

    def request_example(operation, status: nil)
      return nil unless operation

      body = operation[:operation].request_body
      media_example(body, status: status) || example_from_schema(body_schema(body))
    end

    def response_examples(operation)
      return {} unless operation

      operation[:operation].responses.each_with_object({}) do |(code, response), result|
        example = media_example(response) || example_from_schema(body_schema(response))
        result[code.to_s] = example if example
      end
    end

    def local_status(status)
      case status.to_s.downcase
      when "completed", "success", "paid" then "approved"
      when "failed", "cancelled", "rejected" then "rejected"
      else "in_progress"
      end
    end

    def status_values
      statuses.map(&:first)
    end

    private

    def operation_info(path, verb, operation, path_item)
      parameters = []
      [path_item.parameters, operation.parameters].compact.each { |items| items.each { |item| parameters << parameter_info(item) } }
      parameters.uniq! { |item| [item[:name], item[:location]] }
      {
        id: operation.operation_id || "#{verb}_#{snake_case(path)}",
        verb: verb.to_s.upcase,
        path: path,
        summary: clean(operation.summary) || clean(operation.description) || "Операция без описания",
        description: clean(operation.description),
        tags: operation.tags&.to_a || [],
        parameters: parameters,
        request: media_schema(operation.request_body),
        responses: response_infos(operation.responses),
        operation: operation
      }
    end

    def parameter_info(parameter)
      schema = parameter.schema
      {
        name: parameter.name, location: parameter.in, required: parameter.required? ? "да" : "нет",
        type: schema&.type || "-",
        description: clean(parameter.description) || clean(schema&.description) || "-",
        example: value_or_dash(schema&.example || parameter.example)
      }
    end

    def response_infos(responses)
      return [] unless responses
      responses.map { |code, response| { code: code, description: clean(response.description) || "Ответ провайдера", body: media_schema(response) } }
    end

    def media_schema(container)
      content = container&.content
      return nil unless content
      media = content["application/json"] || values(content).first
      return nil unless media
      schema = media.schema
      { type: schema&.type || "-", description: clean(schema&.description) || "", fields: schema_fields(schema), example: media.example || media.examples&.first&.last&.value }
    end

    def schema_fields(schema, prefix = "")
      return [] unless schema&.respond_to?(:properties) && schema.properties
      required = schema.required&.to_a || []
      schema.properties.each_with_object([]) do |(name, field), fields|
        full_name = prefix.empty? ? name : "#{prefix}.#{name}"
        fields << { name: full_name, type: field.type || "-", required: required.include?(name) ? "да" : "нет", description: clean(field.description) || "-", constraints: constraints(field), example: value_or_dash(field.example) }
        fields.concat(schema_fields(field, full_name))
      end
    end

    def constraints(schema)
      values = []
      values << "enum: #{schema.enum.to_a.join(', ')}" if schema.enum
      values << "min: #{schema.minimum}" if schema.respond_to?(:minimum) && schema.minimum
      values << "maxLength: #{schema.max_length}" if schema.respond_to?(:max_length) && schema.max_length
      values << "pattern: `#{schema.pattern}`" if schema.respond_to?(:pattern) && schema.pattern
      values.join("; ")
    end

    def media_example(container, status: nil)
      content = container&.content
      return nil unless content
      media = content["application/json"] || values(content).first
      return nil unless media
      return media.example if media.example && status.nil?
      examples = media.examples
      if examples && status
        matching = examples.find { |name, item| "#{name} #{item.value.to_json}".downcase.include?(status.to_s.downcase) }
        return matching.last.value if matching
      end
      media.example || examples&.first&.last&.value
    end

    def body_schema(container)
      content = container&.content
      media = content && (content["application/json"] || values(content).first)
      media&.schema
    end

    def example_from_schema(schema)
      return nil unless schema
      return schema.example unless schema.example.nil?
      return example_from_schema(schema.one_of.first) if schema.respond_to?(:one_of) && schema.one_of&.first
      return schema.all_of.to_a.reduce({}) { |result, item| result.merge(example_from_schema(item) || {}) } if schema.respond_to?(:all_of) && schema.all_of&.any?
      return schema.default unless schema.default.nil?
      if schema.type == "object" || (schema.respond_to?(:properties) && schema.properties&.any?)
        schema.properties.each_with_object({}) { |(name, field), result| result[name] = example_from_schema(field) }
      elsif schema.type == "array"
        [example_from_schema(schema.items)].compact
      else
        scalar_example(schema)
      end
    end

    def scalar_example(schema)
      return schema.enum.first if schema.enum&.any?
      return 0 if %w[integer number].include?(schema.type)
      return false if schema.type == "boolean"
      return "2026-01-01T00:00:00Z" if schema.format == "date-time"
      schema.type == "string" ? "example" : nil
    end

    def create_operation?(operation)
      "#{operation[:id]} #{operation[:path]}".downcase.match?(/create|init|charge|payment|pay|deposit|order/)
    end

    def values(collection)
      collection.map { |_key, value| value }
    end

    def value_or_dash(value)
      return "-" if value.nil?
      "`#{value.to_json.gsub('|', '\\\\|')}`"
    end

    def clean(value)
      value.to_s.gsub(/\s+/, " ").strip unless value.nil?
    end

    def snake_case(value)
      value.to_s.gsub(/([A-Z]+)([A-Z][a-z])/, '\\1_\\2').gsub(/([a-z\d])([A-Z])/, '\\1_\\2').tr("-", "_").gsub(/\s+/, "_").downcase
    end
  end
end
