# frozen_string_literal: true

module Toys
  module Templates
    ##
    # A template that generates rdoc tools.
    #
    class Rdoc
      include Template

      ##
      # Default version requirements for the rdoc gem.
      # @return [Array<String>]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = [">= 6.1.0"].freeze

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "rdoc"

      ##
      # Default output directory
      # @return [String]
      #
      DEFAULT_OUTPUT_DIR = "html"

      ##
      # Default file globs
      # @return [Array<String>]
      #
      DEFAULT_FILES = ["lib/**/*.rb"].freeze

      ##
      # Create the template settings for the Rdoc template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param gem_version [String,Array<String>] Version requirements for
      #     the rdoc gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param files [Array<String>] An array of globs indicating the files
      #     to document. Defaults to {DEFAULT_FILES}.
      # @param output_dir [String] Name of directory to receive html output
      #     files. Defaults to {DEFAULT_OUTPUT_DIR}.
      # @param markup [String] Markup format. Allowed values include "rdoc",
      #     "rd", and "tomdoc". If not specified, RDoc will use its default
      #     markup, which is "rdoc".
      # @param title [String] Title of RDoc documentation. If not specified,
      #     RDoc will use a default title.
      # @param main [String] Name of the file to use as the main top level
      #     document. Default is none.
      # @param template [String] Name of the template to use. If not specified,
      #     RDoc will use its default template.
      # @param generator [String] Name of the format generator. If not
      #     specified, RDoc will use its default generator.
      # @param options [Array<String>] Additional options to pass to RDoc.
      # @param bundler [Boolean,Hash] If `false` (the default), bundler is not
      #     enabled for this tool. If `true` or a Hash of options, bundler is
      #     enabled. See the documentation for the
      #     [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      #     for information on available options.
      # @param context_directory [String] A custom context directory to use
      #     when executing this tool.
      #
      def initialize(name: nil,
                     gem_version: nil,
                     files: nil,
                     output_dir: nil,
                     markup: nil,
                     title: nil,
                     main: nil,
                     template: nil,
                     generator: nil,
                     options: [],
                     bundler: false,
                     context_directory: nil)
        @name = name
        @gem_version = gem_version
        @files = files
        @output_dir = output_dir
        @markup = markup
        @title = title
        @main = main
        @template = template
        @generator = generator
        @options = options
        @bundler = bundler
        @context_directory = context_directory
      end

      ##
      # Name of the tool to create.
      #
      # @param value [String]
      # @return [String]
      #
      attr_writer :name

      ##
      # Version requirements for the rdoc gem.
      # If set to `nil`, uses the bundled version if bundler is enabled, or
      # defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS} if bundler is not
      # enabled.
      #
      # @param value [String,Array<String>,nil]
      # @return [String,Array<String>,nil]
      #
      attr_writer :gem_version

      ##
      # An array of globs indicating which files to document.
      #
      # @param value [Array<String>]
      # @return [Array<String>]
      #
      attr_writer :files

      ##
      # Name of directory to receive html output files.
      # If set to `nil`, defaults to {DEFAULT_OUTPUT_DIR}.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :output_dir

      ##
      # Markup format. Allowed values include "rdoc", "rd", and "tomdoc".
      # If set to `nil`, RDoc will use its default markup, which is "rdoc".
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :markup

      ##
      # Title of RDoc documentation pages.
      # If set to `nil`, RDoc will use a default title.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :title

      ##
      # Name of the file to use as the main top level document, or `nil` for
      # no top level document.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :main

      ##
      # Name of the template to use.
      # If set to `nil`, RDoc will choose a default template.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :template

      ##
      # Name of the format generator.
      # If set to `nil`, RDoc will use its default generator.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :generator

      ##
      # Additional options to pass to RDoc
      #
      # @param value [Array<String>]
      # @return [Array<String>]
      #
      attr_writer :options

      ##
      # Custom context directory for this tool.
      #
      # @param value [String]
      # @return [String]
      #
      attr_writer :context_directory

      ##
      # Set the bundler state and options for this tool.
      #
      # Pass `false` to disable bundler. Pass `true` or a hash of options to
      # enable bundler. See the documentation for the
      # [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      # for information on the options that can be passed.
      #
      # @param value [Boolean,Hash]
      # @return [Boolean,Hash]
      #
      attr_writer :bundler

      ##
      # Use bundler for this tool.
      #
      # See the documentation for the
      # [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      # for information on the options that can be passed.
      #
      # @param opts [keywords] Options for bundler
      # @return [self]
      #
      def use_bundler(**opts)
        @bundler = opts
        self
      end

      ##
      # @private
      #
      attr_reader :markup

      ##
      # @private
      #
      attr_reader :title

      ##
      # @private
      #
      attr_reader :main

      ##
      # @private
      #
      attr_reader :template

      ##
      # @private
      #
      attr_reader :generator

      ##
      # @private
      #
      attr_reader :context_directory

      ##
      # @private
      #
      def name
        @name || DEFAULT_TOOL_NAME
      end

      ##
      # @private
      #
      def gem_version
        return Array(@gem_version) if @gem_version
        @bundler ? [] : DEFAULT_GEM_VERSION_REQUIREMENTS
      end

      ##
      # @private
      #
      def files
        @files ? Array(@files) : DEFAULT_FILES
      end

      ##
      # @private
      #
      def output_dir
        @output_dir || DEFAULT_OUTPUT_DIR
      end

      ##
      # @private
      #
      def options
        Array(@options)
      end

      ##
      # @private
      #
      def bundler_settings
        if @bundler && !@bundler.is_a?(::Hash)
          {}
        else
          @bundler
        end
      end

      on_expand do |template|
        tool(template.name) do
          desc "Run rdoc on the current project."

          set_context_directory template.context_directory if template.context_directory

          include :exec, exit_on_nonzero_status: true
          include :gems

          bundler_settings = template.bundler_settings
          include :bundler, **bundler_settings if bundler_settings

          to_run do
            gem_requirements = template.gem_version
            gem "rdoc", *gem_requirements

            ::Dir.chdir(context_directory || ::Dir.getwd) do
              files = []
              template.files.each do |pattern|
                files.concat(::Dir.glob(pattern))
              end
              files.uniq!

              args = template.options.dup
              args << "-o" << template.output_dir
              args << "--markup" << template.markup if template.markup
              args << "--main" << template.main if template.main
              args << "--title" << template.title if template.title
              args << "-T" << template.template if template.template
              args << "-f" << template.generator if template.generator

              exec_ruby([], in: :controller) do |controller|
                controller.in.puts("gem 'rdoc', *#{gem_requirements.inspect}")
                controller.in.puts("require 'rdoc'")
                controller.in.puts("::RDoc::RDoc.new.document(#{(args + files).inspect})")
              end
            end
          end
        end
      end
    end
  end
end
