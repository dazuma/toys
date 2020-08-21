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
      #     to clean. You can also include the symbol `:gitignore` which will
      #     clean all items covered by `.gitignore` files, if contained in a
      #     git working tree.
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

          static :template_paths, template.paths

          include :fileutils
          include :exec

          # @private
          def run
            cd(context_directory || ::Dir.getwd) do
              template_paths.each do |elem|
                case elem
                when :gitignore
                  clean_gitignore
                when ::String
                  clean_pattern(elem)
                else
                  raise "Unknown path in clean: #{elem.inspect}"
                end
              end
            end
          end

          # @private
          def clean_gitignore
            result = exec(["git", "rev-parse", "--is-inside-work-tree"], out: :null, err: :null)
            unless result.success?
              logger.error("Skipping :gitignore because we don't seem to be in a git directory")
              return
            end
            clean_gitignore_dir(".")
          end

          # @private
          def clean_gitignore_dir(dir)
            children = dir_children(dir)
            result = exec(["git", "check-ignore", "--stdin"],
                          in: :controller, out: :capture) do |controller|
              children.each { |child| controller.in.puts(child) }
            end
            result.captured_out.split("\n").each { |path| clean_path(path) }
            children = dir_children(dir) if result.success?
            children.each { |child| clean_gitignore_dir(child) if ::File.directory?(child) }
          end

          # @private
          def dir_children(dir)
            ::Dir.entries(dir)
                 .reject { |entry| entry =~ /^\.\.?$/ }
                 .map { |entry| ::File.join(dir, entry) }
          end

          # @private
          def clean_pattern(pattern)
            ::Dir.glob(pattern) { |path| clean_path(path) }
          end

          # @private
          def clean_path(path)
            if ::File.exist?(path)
              rm_rf(path)
              puts "Cleaned: #{path}"
            end
          end
        end
      end
    end
  end
end
