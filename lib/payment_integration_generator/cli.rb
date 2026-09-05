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

      puts "Generating #{integration_name} integration based on OpenAPI specification..."

      document = OpenApiParser.new(file_path: options[:file], url: options[:url])
                              .parse
      
      # TODO: run integration generator
      PaymentIntegrationGenerator::IntegrationGenerator.new(
        openapi_document: document,
        integration_name: integration_name,
      # output_folder_path: options[:output_folder]
        ).call

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
