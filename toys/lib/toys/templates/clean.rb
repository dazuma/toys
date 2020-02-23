# frozen_string_literal: true

module Toys
  module Templates
    ##
    # A template for tools that clean build artifacts
    #
    class Clean
      include Template

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "clean"

      ##
      # Create the template settings for the Clean template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param paths [Array<String>] An array of glob patterns indicating what
      #     to clean.
      #
      def initialize(name: nil, paths: [])
        @name = name
        @paths = paths
      end

      ##
      # Name of the tool to create.
      #
      # @param value [String]
      # @return [String]
      #
      attr_writer :name

      ##
      # An array of glob patterns indicating what to clean.
      #
      # @param value [Array<String>]
      # @return [Array<String>]
      #
      attr_writer :paths

      # @private
      def paths
        Array(@paths)
      end

      # @private
      def name
        @name || DEFAULT_TOOL_NAME
      end

      on_expand do |template|
        tool(template.name) do
          desc "Clean built files and directories."

          include :fileutils

          to_run do
            ::Dir.chdir(context_directory || ::Dir.getwd) do
              files = []
              template.paths.each do |pattern|
                files.concat(::Dir.glob(pattern))
              end
              files.uniq.each do |file|
                if ::File.exist?(file)
                  rm_rf(file)
                  puts "Cleaned: #{file}"
                end
              end
            end
          end
        end
      end
    end
  end
end
