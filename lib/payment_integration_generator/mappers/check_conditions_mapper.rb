# frozen_string_literal: true

module PaymentIntegrationGenerator
  class CheckConditionsMapper
    # Строит по схеме тела запроса (payload_schema, найденной CreateRequestSearcher)
    # плоский хэш ограничений для каждого поля — минимум, максимум, допустимые значения.
    def self.call(payload_schema)
      schema = effective_schema(payload_schema)
      return {} unless schema&.properties

      flatten_properties(schema.properties)
    end

    # Если схема сама — массив (корень requestBody: type: array, как у
    # NovaPay «Комфортний»), возвращает схему элементов массива (items),
    # у которой уже есть properties. Для обычных object-схем возвращает схему без изменений.
    # @param schema [Openapi3Parser::Node::Schema, nil]
    # @return [Openapi3Parser::Node::Schema, nil]
    def self.effective_schema(schema)
      return nil unless schema

      schema.type == "array" ? schema.items : schema
    end

    # Рекурсивно проходит хэш properties, разворачивая вложенные объекты и
    # массивы объектов в плоские ключи с префиксом.
    # @param properties [Hash{String => Openapi3Parser::Node::Schema}] properties
    # текущего уровня схемы
    # @param prefix [String, nil] накопленный префикс ключа для вложенных полей
    # @return [Hash{String => Hash}] плоский хэш ограничений на этом и всех вложенных уровнях
    def self.flatten_properties(properties, prefix = nil)
      properties.each_with_object({}) do |(name, property), result|
        key = prefix ? "#{prefix}.#{name}" : name

        case property.type
        when "object"
          if property.properties
            result.merge!(flatten_properties(property.properties, key))
          else
            result[key] = field_conditions(property)
          end
        when "array"
          items = property.items
          if items && items.type == "object" && items.properties
            result.merge!(flatten_properties(items.properties, "#{key}[]"))
          else
            result[key] = field_conditions(property)
          end
        else
          result[key] = field_conditions(property)
        end
      end
    end

    # Достаёт три вида ограничений из схемы одного (примитивного) поля.
    #
    # @param property [Openapi3Parser::Node::Schema] схема конкретного поля
    # @return [Hash] { min:, max:, enum: } — берётся из одноимённого атрибута схемы (minimum/maximum/enum) как есть, либо nil, если атрибут не объявлен в спеке для этого поля
    def self.field_conditions(property)
      {
        min: property.minimum,
        max: property.maximum,
        enum: property.enum&.to_a
      }
    end

    private_class_method :flatten_properties, :field_conditions, :effective_schema
  end
end
