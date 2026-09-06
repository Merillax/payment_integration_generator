# frozen_string_literal: true

require "thor"

module PaymentIntegrationGenerator
  class CLI < Thor
    desc "generate [INTEGRATION_NAME]", "Generate integration based on OpenAPI specification"
    method_option :file, type: :string, aliases: "-f", desc: "File to generate"
    method_option :url, type: :string, aliases: "-u", desc: "Url to generate"
    method_option :output_folder, type: :string, aliases: "-o", desc: "Destination folder"
    method_option :payload_mapping_resolver,
                  type: :string,
                  aliases: "-r",
                  desc: "Path to a Ruby file with a custom payload mapping resolver"
    def generate(integration_name)
      raise "--file or --url must be specified" if options[:file].nil? && options[:url].nil?
      raise "Both the --file and the --url are specified" if options[:file] && options[:url]
      raise "INTEGRATION_NAME must be specified" if integration_name.nil?

      # Проверка, что имя уже в PascalCase
      unless integration_name =~ /^[A-Z][a-z]+[A-Z]/
        integration_name = integration_name.split(/[_\-\s]+/).map(&:capitalize).join
      end

      document = OpenApiParser.new(file_path: options[:file], url: options[:url])
                              .parse

      integration_generator = PaymentIntegrationGenerator::IntegrationGenerator.new(
        openapi_document: document,
        integration_name: integration_name,
        payload_mapping_resolver: payload_mapping_resolver_class,
        output_folder_path: options[:output_folder]
      )
      puts "--------------------------------"
      puts "-----INITIALIZING SEARCHERS-----"
      puts "--------------------------------"

      integration_generator.initialize_searchers
      integration_generator.available_searchers.each do |searcher|
        uri, path_item = integration_generator.send(searcher).search_result
        puts ''
        puts "#{searcher} result: \n uri:  #{uri} \n\n"

        message = <<~TEXT
          Options to type:
          1) 'YES', if result is correct;
          2) 'ToDo', if you want to do it manually later;
          3) Search pattern as format 'method uri', if result if not correct. For example 'post /payouts'.
        TEXT
        puts message

        pattern = ask('')
        case pattern
        when "YES" then next
        when "ToDo" then integration_generator.send(searcher).enable_todo_option
        else 
          handle_manually_user_input(pattern, integration_generator, searcher)
        end
      end
      puts "--------------------------------"
      puts "--INITIALIZING SEARCHERS_ENDS---"
      puts "--------------------------------"

      puts "Generating #{integration_name} integration based on OpenAPI specification..."

      integration_generator.call

      Generators::DocumentationGenerator.new(
        openapi_document: document,
        integration_name: integration_name,
        output_folder_path: options[:output_folder]
      ).call

      Generators::FixturesGenerator.new(
        openapi_document: document,
        integration_name: integration_name,
        output_folder_path: options[:output_folder]
      ).call

      puts "Done!"
    rescue StandardError => e
      puts "Error: #{e.message}. Backtrace: #{e.backtrace}"
      exit 1
    end

    no_commands do
      def payload_mapping_resolver_class
        resolver_path = options[:payload_mapping_resolver]
        return PayloadMappingResolver unless resolver_path

        absolute_path = File.expand_path(resolver_path)
        raise "Resolver file #{absolute_path} does not exist" unless File.file?(absolute_path)

        class_name = File.basename(absolute_path, ".rb").split(/[_\-\s]+/).map(&:capitalize).join
        require absolute_path

        resolver = Object.const_get(class_name)
        return resolver if resolver <= PayloadMappingResolver

        raise ArgumentError, "#{class_name} must inherit from PayloadMappingResolver"
      rescue NameError
        raise NameError, "Could not find #{class_name} in #{absolute_path}"
      end

      def handle_manually_user_input(pattern, integration_generator, searcher)
        while true
          begin
            integration_generator.send(searcher).complete_pattern_search(pattern)
            break
          rescue ArgumentError => e
            puts e
            pattern = ask("Please retype search pattern as format 'method uri', For example 'post /payouts'.\n")
          end
        end
      end
    end
  end
end
