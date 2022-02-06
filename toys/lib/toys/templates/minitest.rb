# frozen_string_literal: true

module Toys
  module Templates
    ##
    # A template for tools that run minitest
    #
    class Minitest
      include Template

      ##
      # Default version requirements for the minitest gem.
      # @return [Array<String>]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = ["~> 5.0"].freeze

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "test"

      ##
      # Default set of library paths
      # @return [Array<String>]
      #
      DEFAULT_LIBS = ["lib"].freeze

      ##
      # Default set of test file globs
      # @return [Array<String>]
      #
      DEFAULT_FILES = ["test/**/test*.rb"].freeze

      ##
      # Create the template settings for the Minitest template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param gem_version [String,Array<String>] Version requirements for
      #     the minitest gem. Optional. If not provided, uses the bundled
      #     version if bundler is enabled, or defaults to
      #     {DEFAULT_GEM_VERSION_REQUIREMENTS} if bundler is not enabled.
      # @param libs [Array<String>] An array of library paths to add to the
      #     ruby require path. Defaults to {DEFAULT_LIBS}.
      # @param files [Array<String>] An array of globs indicating the test
      #     files to load. Defaults to {DEFAULT_FILES}.
      # @param seed [Integer] The random seed, if any. Optional.
      # @param verbose [Boolean] Whether to produce verbose output. Defaults to
      #     false.
      # @param warnings [Boolean] If true, runs tests with Ruby warnings.
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
                     files: nil,
                     seed: nil,
                     verbose: false,
                     warnings: true,
                     bundler: false,
                     context_directory: nil)
        @name = name
        @gem_version = gem_version
        @libs = libs
        @files = files
        @seed = seed
        @verbose = verbose
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
      # Version requirements for the minitest gem.
      # If set to `nil`, uses the bundled version if bundler is enabled, or
      # defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS} if bundler is not
      # enabled.
      #
      # @param value [String,Array<String>,nil]
      # @return [String,Array<String>,nil]
      #
      attr_writer :gem_version

      ##
      # An array of library paths to add to the ruby require path.
      # If set to `nil`, defaults to {DEFAULT_LIBS}.
      #
      # @param value [String,Array<String>,nil]
      # @return [String,Array<String>,nil]
      #
      attr_writer :libs

      ##
      # An array of globs indicating the test files to load.
      # If set to `nil`, defaults to {DEFAULT_FILES}.
      #
      # @param value [String,Array<String>,nil]
      # @return [String,Array<String>,nil]
      #
      attr_writer :files

      ##
      # The random seed, or `nil` if not specified.
      #
      # @param value [Integer,nil]
      # @return [Integer,nil]
      #
      attr_writer :seed

      ##
      # Whether to produce verbose output.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :verbose

      ##
      # Whether to run tests with Ruby warnings.
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
      attr_reader :seed

      ##
      # @private
      #
      attr_reader :verbose

      ##
      # @private
      #
      attr_reader :warnings

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
      def libs
        @libs ? Array(@libs) : DEFAULT_LIBS
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
      def gem_version
        return Array(@gem_version) if @gem_version
        @bundler ? [] : DEFAULT_GEM_VERSION_REQUIREMENTS
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
          desc "Run minitest on the current project."

          set_context_directory template.context_directory if template.context_directory

          include :exec
          include :gems

          bundler_settings = template.bundler_settings
          include :bundler, **bundler_settings if bundler_settings

          flag :seed, "-s", "--seed SEED",
               default: template.seed, desc: "Sets random seed."
          flag :warnings, "-w", "--[no-]warnings",
               default: template.warnings,
               desc: "Turn on Ruby warnings (defaults to #{template.warnings})"
          flag :name, "-n", "--name PATTERN",
               desc: "Filter run on /regexp/ or string."
          flag :exclude, "-e", "--exclude PATTERN",
               desc: "Exclude /regexp/ or string from run."

          remaining_args :tests,
                         complete: :file_system,
                         desc: "Paths to the tests to run (defaults to all tests)"

          to_run do
            gem "minitest", *template.gem_version

            ::Dir.chdir(context_directory || ::Dir.getwd) do
              ruby_args = []
              libs = Array(template.libs)
              ruby_args << "-I#{libs.join(::File::PATH_SEPARATOR)}" unless libs.empty?
              ruby_args << "-w" if warnings
              ruby_args << "-"
              ruby_args << "--seed" << seed if seed
              vv = verbosity
              vv += 1 if template.verbose
              ruby_args << "--verbose" if vv.positive?
              ruby_args << "--name" << name if name
              ruby_args << "--exclude" << exclude if exclude

              if tests.empty?
                Array(template.files).each do |pattern|
                  tests.concat(::Dir.glob(pattern))
                end
                tests.uniq!
              end

              result = exec_ruby(ruby_args, in: :controller) do |controller|
                controller.in.puts("require 'minitest/autorun'")
                tests.each do |file|
                  controller.in.puts("load '#{file}'")
                end
              end
              if result.error?
                logger.error("Minitest failed!")
                exit(result.exit_code)
              end
            end
          end
        end
      end
    end
  end
end
