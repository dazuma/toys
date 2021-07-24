# frozen_string_literal: true

module Toys
  module Templates
    ##
    # A template for tools that run rspec
    #
    class Rspec
      include Template

      ##
      # Default version requirements for the rspec gem.
      # @return [Array<String>]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = ["~> 3.1"].freeze

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "spec"

      ##
      # Default set of library paths
      # @return [Array<String>]
      #
      DEFAULT_LIBS = ["lib"].freeze

      ##
      # Default order type
      # @return [String]
      #
      DEFAULT_ORDER = "defined"

      ##
      # Default format code
      # @return [String]
      #
      DEFAULT_FORMAT = "p"

      ##
      # Default spec file glob
      # @return [String]
      #
      DEFAULT_PATTERN = "spec/**/*_spec.rb"

      ##
      # Create the template settings for the RSpec template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param gem_version [String,Array<String>] Version requirements for
      #     the rspec gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param libs [Array<String>] An array of library paths to add to the
      #     ruby require path. Defaults to {DEFAULT_LIBS}.
      # @param options [String] The path to a custom options file, if any.
      # @param order [String] The order in which to run examples. Default is
      #     {DEFAULT_ORDER}.
      # @param format [String] The formatter code. Default is {DEFAULT_FORMAT}.
      # @param out [String] Write output to a file instead of stdout.
      # @param backtrace [Boolean] Enable full backtrace (default is false).
      # @param pattern [String] A glob indicating the spec files to load.
      #     Defaults to {DEFAULT_PATTERN}.
      # @param warnings [Boolean] If true, runs specs with Ruby warnings.
      #     Defaults to true.
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
                     libs: nil,
                     options: nil,
                     order: nil,
                     format: nil,
                     out: nil,
                     backtrace: false,
                     pattern: nil,
                     warnings: true,
                     bundler: false,
                     context_directory: nil)
        @name = name
        @gem_version = gem_version
        @libs = libs
        @options = options
        @order = order
        @format = format
        @out = out
        @backtrace = backtrace
        @pattern = pattern
        @warnings = warnings
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
      # Version requirements for the rspec gem.
      # If set to `nil`, uses the bundled version if bundler is enabled, or
      # defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS} if bundler is not
      # enabled.
      #
      # @param value [String,Array<String>,nil]
      # @return [String,Array<String>,nil]
      #
      attr_writer :gem_version

      ##
      # An array of directories to add to the Ruby require path.
      # If set to `nil`, defaults to {DEFAULT_LIBS}.
      #
      # @param value [Array<String>,nil]
      # @return [Array<String>,nil]
      #
      attr_writer :libs

      ##
      # Path to the custom options file, or `nil` for none.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :options

      ##
      # The order in which to run examples.
      # If set to `nil`, defaults to {DEFAULT_ORDER}.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :order

      ##
      # The formatter code.
      # If set to `nil`, defaults to {DEFAULT_FORMAT}.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :format

      ##
      # Path to a file to write output to.
      # If set to `nil`, writes output to standard out.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :out

      ##
      # Whether to enable full backtraces.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :backtrace

      ##
      # A glob indicating the spec files to load.
      # If set to `nil`, defaults to {DEFAULT_PATTERN}.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :pattern

      ##
      # Whether to run with Ruby warnings.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :warnings

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
      # Activate bundler for this tool.
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

      ## @private
      attr_reader :options
      ## @private
      attr_reader :out
      ## @private
      attr_reader :backtrace
      ## @private
      attr_reader :warnings
      # @private
      attr_reader :context_directory

      # @private
      def name
        @name || DEFAULT_TOOL_NAME
      end

      # @private
      def gem_version
        return Array(@gem_version) if @gem_version
        @bundler ? [] : DEFAULT_GEM_VERSION_REQUIREMENTS
      end

      # @private
      def libs
        @libs ? Array(@libs) : DEFAULT_LIBS
      end

      # @private
      def order
        @order || DEFAULT_ORDER
      end

      # @private
      def format
        @format || DEFAULT_FORMAT
      end

      # @private
      def pattern
        @pattern || DEFAULT_PATTERN
      end

      # @private
      def bundler_settings
        if @bundler && !@bundler.is_a?(::Hash)
          {}
        else
          @bundler
        end
      end

      on_expand do |template|
        tool(template.name) do
          desc "Run rspec on the current project."

          set_context_directory template.context_directory if template.context_directory

          include :exec
          include :gems

          bundler_settings = template.bundler_settings
          include :bundler, **bundler_settings if bundler_settings

          flag :order, "--order TYPE",
               default: template.order,
               desc: "Run examples by the specified order type (default: #{template.order})"
          flag :format, "-f", "--format FORMATTER",
               default: template.format,
               desc: "Choose a formatter (default: #{template.format})"
          flag :out, "-o", "--out FILE",
               default: template.out,
               desc: "Write output to a file (default: #{template.out.inspect})"
          flag :backtrace, "-b", "--[no-]backtrace",
               default: template.backtrace,
               desc: "Enable full backtrace (default: #{template.backtrace})"
          flag :warnings, "-w", "--[no-]warnings",
               default: template.warnings,
               desc: "Turn on Ruby warnings (default: #{template.warnings})"
          flag :pattern, "-P", "--pattern PATTERN",
               default: template.pattern,
               desc: "Load files matching pattern (default: #{template.pattern.inspect})"
          flag :exclude_pattern, "--exclude-pattern PATTERN",
               desc: "Load files except those matching pattern."
          flag :example, "-e", "--example STRING",
               desc: "Run examples whose full nested names include STRING" \
                     " (may be used more than once)."
          flag :tag, "-t", "--tag TAG",
               desc: "Run examples with the specified tag, or exclude" \
                     " examples by adding ~ before the tag."

          remaining_args :files,
                         complete: :file_system,
                         desc: "Paths to the specs to run (defaults to all specs)"

          to_run do
            gem_requirements = Array(template.gem_version)
            gem "rspec", *gem_requirements

            ::Dir.chdir(context_directory || ::Dir.getwd) do
              ruby_args = []
              libs = Array(template.libs)
              ruby_args << "-I#{libs.join(::File::PATH_SEPARATOR)}" unless libs.empty?
              ruby_args << "-w" if warnings
              ruby_args << "-"
              ruby_args << "--options" << template.options if template.options
              ruby_args << "--order" << order if order
              ruby_args << "--format" << format if format
              ruby_args << "--out" << out if out
              ruby_args << "--backtrace" if backtrace
              ruby_args << "--pattern" << pattern
              ruby_args << "--exclude-pattern" << exclude_pattern if exclude_pattern
              ruby_args << "--example" << example if example
              ruby_args << "--tag" << tag if tag
              ruby_args.concat(files)

              result = exec_ruby(ruby_args, in: :controller) do |controller|
                controller.in.puts("gem 'rspec', *#{gem_requirements.inspect}")
                controller.in.puts("require 'rspec/core'")
                controller.in.puts("::RSpec::Core::Runner.invoke")
              end
              if result.error?
                logger.error("RSpec failed!")
                exit(result.exit_code)
              end
            end
          end
        end
      end
    end
  end
end
