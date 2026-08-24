require_relative "lib/parsers/open_api_yaml_parser"
require_relative "lib/generators/base"

yaml_file_path = ARGV[0]

if yaml_file_path.nil? || yaml_file_path.empty?
  puts "Ошибка: Первым аргументом должна быть передан путь к конфигурации OpenApi"
  exit 1
end

unless File.exist?(yaml_file_path)
  puts "Ошибка: Конфигурация OpenApi не найдена!" 
  exit 1
end

result = OpenApiYamlParser.new(yaml_file_path).parse
if result.failure?
  puts result.message 
  exit 1
end

puts result.data["components"]["schemas"]["Money"].to_h
result.data["components"]["schemas"].each do |hh|
  puts hh
end


result = BaseGenerator.new(result.data).start_generation
if result.failure?
  puts result.message 
  exit 1
end





  