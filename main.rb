require_relative "lib/parsers/open_api_yaml_parser"

yaml_file_path = ARGV[0]

if yaml_file_path.nil? || yaml_file_path.empty?
  puts "Ошибка: Первым аргументом должна быть передан путь к конфигурации OpenApi"
  exit 1
end

unless File.exist?(yaml_file_path)
  puts "Ошибка: Конфигурация OpenApi не найдена!" 
  exit 1
end

result = OpenApiYamlParser.new(yaml_file_path).validate
print(result.message)




  