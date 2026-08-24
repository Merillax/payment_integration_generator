require "erb"
require "fileutils"

module Generators
  class DtoGenerator
    TEMPLATE_PATH = File.join(__dir__, "/lib/generators/templates/dto_template.erb")

    def initialize(dto_config, path_to_create)
      @dto_config = dto_config
      @path_to_create = path_to_create
    end

    def generate
      template = ERB.new(File.read(TEMPLATE_PATH), trim_mode: "-")
      filled_template = template.result(binding)
      result = create_dto_file(filled_template)
    end

    private

    def create_dto_file(data)

      

    end
  end
end