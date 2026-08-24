require 'yaml'
require 'openapi3_parser'
require_relative "../service_result_object/failure_result_object"
require_relative "../service_result_object/success_result_object"

class OpenApiYamlParser
  def initialize(path_to_yaml_file)
    @path_to_yaml_file = path_to_yaml_file
  end
    
  def parse
    result = validate
    return result unless result.success?

    return SuccessResultObject.new(data: open_api_data)
  end

  def validate
    return FailureResultObject.new(open_api_data.errors.inspect) unless open_api_data.valid?
    return FailureResultObject.new("Конфигурация не содержит блока 'info'") if open_api_data["info"].nil?
    return FailureResultObject.new("Конфигурация не содержит наименования проектной конфигурации") if open_api_data["info"]["title"].nil? || open_api_data["info"]["title"].empty?


    SuccessResultObject.new("Success")
  end

  private

  def open_api_data
    @open_api_data ||= Openapi3Parser.load_file(@path_to_yaml_file)
  end
end
