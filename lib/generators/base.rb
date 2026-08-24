require 'fileutils'
require_relative "../service_result_object/failure_result_object"
require_relative "../service_result_object/success_result_object"
require_relative "./dto_generator"


module Generators
  class BaseGenerator
    PATH_TO_OUTPUT = File.join(__dir__, "/output/")
    AVAILABLE_GENERATORS = ["dtos"]
    DTOS_PATH = ["components", "schemas"]
    PATHES_TO_CREATE = {
      dto: File.join(PATH_TO_OUTPUT, "dtos"),
    }

    def initialize(parsed_config_data)
      @parsed_config_data = parsed_config_data
    end

    def start_generation
      result = create_directory
      return result if result.failure?

      result = AVAILABLE_GENERATORS.reduce([]) {|errors, gen_name| send("create_#{gen_name}") }
      return SuccessResultObject.new("success") if result.all? {|result_object| result_object.success? }

      errors = []
      result.each {|res_obj| errors << res_obj.message if res_obj.failure? }
      FailureResultObject.new("\n".join(errors))
    end

    private

    def create_directory
      return FailureResultObject.new("Ошибка: Интеграция с таким именем уже существует!") if Dir.exist?(path_to_directory)
      
      FileUtils.mkdir_p(path_to_directory)
      return SuccessResultObject.new("Success")
    end

    def create_dtos
      result = generator_data_presented?("dtos")
      return result if result.failure?

      dtos_config_data = result.data
      dtos_errors = []
      dtos_config_data.keys.each do |dto_data_key|
        dto_data = dtos_config_data[dto_data_key].to_h
        dto_data["dto_class_name"] = dto_data_key
        generate_result = Generators::DtoGenerator.new(dto_data, PATHES_TO_CREATE["dto"]).generate
        dtos_errors << generate_result.message if generate_result.failure?
      end

      dtos_errors.empty? ? SuccessResultObject.new("success") : FailureResultObject.new("\n".join(dtos_errors))
    end

    def generator_data_presented?(generator_name)
      config_data = const_get("#{generator_name}_path").reduce(@parsed_config_data) {|data, path| !data.nil? && !data[path].nil? ? data[path] : nil }
      return FailureResultObject.new("Ошибка: Конфигурация #{generator_name} в OpneApi конфигурации не представлена!") unless config_data

      SuccessResultObject.new(data: config_data)
    end

    def path_to_directory
      @path_to_directory ||= File.join(PATH_TO_OUTPUT, to_snake_case(@parsed_config_data.info.title))
    end

    def to_snake_case(str)
      str
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')   # граница между аббревиатурой и следующим словом: "HTTPStatus" -> "HTTP_Status"
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')          # граница между строчной/цифрой и заглавной: "createPayment" -> "create_Payment"
        .gsub(/[\s\-]+/, "_")
        .downcase
    end
  end
end