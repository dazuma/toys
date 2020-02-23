# frozen_string_literal: true

module Toys
  module Templates
    ##
    # A template for tools that run rubocop
    #
    class Rubocop
      include Template

      ##
      # Default version requirements for the rubocop gem.
      # @return [Array<String>]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = [].freeze

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "rubocop"

      ##
      # Create the template settings for the Rubocop template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param gem_version [String,Array<String>] Version requirements for
      #     the rubocop gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param fail_on_error [Boolean] If true, exits with a nonzero code if
      #     Rubocop fails. Defaults to true.
      # @param options [Array<String>] Additional options passed to the Rubocop
      #     CLI.
      # @param bundler [Boolean,Hash] If `false` (the default), bundler is not
      #     enabled for this tool. If `true` or a Hash of options, bundler is
      #     enabled. See the documentation for the
      #     [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      #     for information on available options.
      #
      def initialize(name: DEFAULT_TOOL_NAME,
                     gem_version: nil,
                     fail_on_error: true,
                     options: [],
                     bundler: false)
        @name = name
        @gem_version = gem_version
        @fail_on_error = fail_on_error
        @options = options
        @bundler = bundler
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
      # Whether to exit with a nonzero code if Rubocop fails.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :fail_on_error

      ##
      # Additional options to pass to Rubocop
      #
      # @param value [Array<String>]
      # @return [Array<String>]
      #
      attr_writer :options

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
      attr_reader :fail_on_error
      ## @private
      attr_reader :options

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
      def bundler_settings
        if @bundler && !@bundler.is_a?(::Hash)
          {}
        else
          @bundler
        end
      end

      on_expand do |template|
        tool(template.name) do
          desc "Run rubocop on the current project."

          include :gems
          include :exec

          bundler_settings = template.bundler_settings
          include :bundler, **bundler_settings if bundler_settings

          to_run do
            gem "rubocop", *template.gem_version

            ::Dir.chdir(context_directory || ::Dir.getwd) do
              logger.info "Running RuboCop..."
              result = exec_ruby([], in: :controller) do |controller|
                controller.in.puts("gem 'rubocop', *#{template.gem_version.inspect}")
                controller.in.puts("require 'rubocop'")
                controller.in.puts("exit(::RuboCop::CLI.new.run(#{template.options.inspect}))")
              end
              if result.error?
                logger.error "RuboCop failed!"
                exit(1) if template.fail_on_error
              end
            end
          end
        end
      end
    end
  end
end
