# frozen_string_literal: true

require "thor"

module PaymentIntegrationGenerator
  class CLI < Thor
    desc "generate [INTEGRATION_NAME]", "Generate integration based on OpenAPI specification"
    method_option :file, type: :string, aliases: "-f", desc: "File to generate"
    method_option :url, type: :string, aliases: "-u", desc: "Url to generate"
    method_option :output_folder, type: :string, aliases: "-u", desc: "Destination folder"
    def generate(integration_name)
      raise "--file or --url must be specified" if options[:file].nil? && options[:url].nil?
      raise "Both the --file and the --url are specified" if options[:file] && options[:url]
      raise "INTEGRATION_NAME must be specified" if integration_name.nil?

      # Check if the integration_name is already PascalCase
      unless integration_name =~ /^[A-Z][a-z]+[A-Z]/
        integration_name = integration_name.split(/[_\-\s]+/).map(&:capitalize).join
      end

      document = OpenApiParser.new(file_path: options[:file], url: options[:url])
                              .parse
      
      # TODO: run integration generator
      integration_generator = PaymentIntegrationGenerator::IntegrationGenerator.new(
        openapi_document: document,
        integration_name: integration_name,
      # output_folder_path: options[:output_folder]
      )
      puts "--------------------------------"
      puts "-----INITIALIZING SEARCHERS-----"
      puts "--------------------------------"

      integration_generator.initialize_searchers
      integration_generator.available_searchers.each do |searcher|
        uri, path_item = integration_generator.send(searcher).search_result
        puts "#{searcher} result: \n uri:  #{uri} \n\n"

        while true
          pattern = ask("Type 'YES', if result is correct, or search pattern as format 'method uri'. For example 'post /payouts'")
          break if pattern == 'YES'
          
          begin
            integration_generator.send(searcher).complete_pattern_search(pattern)
            break
          rescue ArgumentError => e
            puts e
          end
        end
      end
      puts "Generating #{integration_name} integration based on OpenAPI specification..."

      integration_generator.call

      Generators::DocumentationGenerator.new(
        openapi_document: document,
        integration_name: integration_name,
        # output_folder_path: options[:output_folder]
      ).call

      Generators::FixturesGenerator.new(
        openapi_document: document,
        integration_name: integration_name,
        # output_folder_path: options[:output_folder]
      ).call

      puts "Done!"
    rescue StandardError => e
      puts "Error: #{e.message}. Backtrace: #{e.backtrace}"
      exit 1
    end
  end
end
