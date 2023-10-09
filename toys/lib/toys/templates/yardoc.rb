# frozen_string_literal: true

module Toys
  module Templates
    ##
    # A template that generates yardoc tools.
    #
    class Yardoc
      include Template

      ##
      # Default version requirements for the yard gem.
      # @return [String]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = ["~> 0.9"].freeze

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "yardoc"

      ##
      # Default file globs
      # @return [Array<String>]
      #
      DEFAULT_FILES = ["lib/**/*.rb"].freeze

      ##
      # Default output directory
      # @return [String]
      #
      DEFAULT_OUTPUT_DIR = "doc"

      ##
      # Create the template settings for the Yardoc template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param gem_version [String,Array<String>] Version requirements for
      #     the yard gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param files [Array<String>] An array of globs indicating the files
      #     to document. Defaults to {DEFAULT_FILES}.
      # @param generate_output [Boolean] Whether to generate output. Setting to
      #     false causes yardoc to emit warnings/errors but not generate html.
      #     Defaults to true.
      # @param generate_output_flag [Boolean] Whether to create a flag
      #     `--[no-]output` that can control whether output is generated.
      #     Defaults to false.
      # @param output_dir [String,nil] Output directory. Defaults to
      #     {DEFAULT_OUTPUT_DIR}.
      # @param fail_on_warning [Boolean] Whether the tool should return a
      #     nonzero error code if any warnings happen. Defaults to false.
      # @param fail_on_undocumented_objects [Boolean] Whether the tool should
      #     return a nonzero error code if any objects remain undocumented.
      #     Defaults to false.
      # @param show_public [Boolean] Show public methods. Defaults to true.
      # @param show_protected [Boolean] Show protected methods. Defaults to
      #     false.
      # @param show_private [Boolean] Show private methods. Defaults to false.
      # @param hide_private_tag [Boolean] Hide methods with the `@private` tag.
      #     Defaults to false.
      # @param readme [String,nil] Name of the readme file used as the title
      #     page. If not provided, YARD will choose a default.
      # @param markup [String,nil] Markup style used in documentation. If not
      #     provided, YARD will choose a default, likely "rdoc".
      # @param template [String,nil] Template to use. If not provided, YARD
      #     will choose a default.
      # @param template_path [String,nil] The optional template path to look
      #     for templates in.
      # @param format [String,nil] The output format for the template. If not
      #     provided, YARD will choose a default, likely "html".
      # @param options [Array<String>] Additional options passed to YARD
      # @param stats_options [Array<String>] Additional stats options passed to
      #     YARD
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
                     generate_output: true,
                     generate_output_flag: false,
                     output_dir: nil,
                     fail_on_warning: false,
                     fail_on_undocumented_objects: false,
                     show_public: true,
                     show_protected: false,
                     show_private: false,
                     hide_private_tag: false,
                     readme: nil,
                     markup: nil,
                     template: nil,
                     template_path: nil,
                     format: nil,
                     options: [],
                     stats_options: [],
                     bundler: false,
                     context_directory: nil)
        @name = name
        @gem_version = gem_version
        @files = files
        @generate_output = generate_output
        @generate_output_flag = generate_output_flag
        @output_dir = output_dir
        @fail_on_warning = fail_on_warning
        @fail_on_undocumented_objects = fail_on_undocumented_objects
        @show_public = show_public
        @show_protected = show_protected
        @show_private = show_private
        @hide_private_tag = hide_private_tag
        @readme = readme
        @markup = markup
        @template = template
        @template_path = template_path
        @format = format
        @options = options
        @stats_options = stats_options
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
      # Whether to generate output. Setting to false causes yardoc to emit
      # warnings/errors but not generate html.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :generate_output

      ##
      # Whether to create a flag `--[no-]output` that can control whether
      # output is generated.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :generate_output_flag

      ##
      # Name of directory to receive html output files.
      # If set to `nil`, defaults to {DEFAULT_OUTPUT_DIR}.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :output_dir

      ##
      # Whether the tool should return a nonzero error code if any warnings
      # happen.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :fail_on_warning

      ##
      # Whether the tool should return a nonzero error code if any objects
      # remain undocumented.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :fail_on_undocumented_objects

      ##
      # Whether to document public methods.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :show_public

      ##
      # Whether to document protected methods.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :show_protected

      ##
      # Whether to document private methods.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :show_private

      ##
      # Whether to hide methods with the `@private` tag.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :hide_private_tag

      ##
      # Name of the readme file used as the title page.
      # If set to `nil`, YARD will choose a default.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :readme

      ##
      # Markup style used in documentation.
      # If set to `nil`, YARD will choose a default, likely "rdoc".
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :markup

      ##
      # Template to use.
      # If set to `nil`, YARD will choose a default.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :template

      ##
      # Directory path to look for templates in.
      # If set to `nil`, no additional template lookup paths will be used.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :template_path

      ##
      # Output format for the template.
      # If set to `nil`, YARD will choose a default, likely "html".
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :format

      ##
      # Additional options to pass to YARD
      #
      # @param value [Array<String>]
      # @return [Array<String>]
      #
      attr_writer :options

      ##
      # Additional stats options to pass to YARD
      #
      # @param value [Array<String>]
      # @return [Array<String>]
      #
      attr_writer :stats_options

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

      ##
      # @private
      #
      attr_reader :generate_output

      ##
      # @private
      #
      attr_reader :generate_output_flag

      ##
      # @private
      #
      attr_reader :fail_on_warning

      ##
      # @private
      #
      attr_reader :fail_on_undocumented_objects

      ##
      # @private
      #
      attr_reader :show_public

      ##
      # @private
      #
      attr_reader :show_protected

      ##
      # @private
      #
      attr_reader :show_private

      ##
      # @private
      #
      attr_reader :hide_private_tag

      ##
      # @private
      #
      attr_reader :readme

      ##
      # @private
      #
      attr_reader :markup

      ##
      # @private
      #
      attr_reader :template

      ##
      # @private
      #
      attr_reader :template_path

      ##
      # @private
      #
      attr_reader :format

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
      def stats_options
        Array(@stats_options)
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
          desc "Run yardoc on the current project."

          set_context_directory template.context_directory if template.context_directory

          if template.generate_output_flag
            flag :generate_output, "--[no-]output",
                 default: template.generate_output,
                 desc: "Whether to generate output"
          else
            static :generate_output, template.generate_output
          end

          static :gem_version, template.gem_version
          static :template_files, template.files
          static :run_options, template.options.dup
          static :stats_options, template.stats_options.dup
          static :fail_on_undocumented_objects, template.fail_on_undocumented_objects
          static :fail_on_warning, template.fail_on_warning
          static :output_dir, template.output_dir
          static :show_public, template.show_public
          static :show_protected, template.show_protected
          static :show_private, template.show_private
          static :hide_private_tag, template.hide_private_tag
          static :readme, template.readme
          static :markup, template.markup
          static :yard_template, template.template
          static :template_path, template.template_path
          static :yard_format, template.format

          include :exec
          include :terminal
          include :gems

          bundler_settings = template.bundler_settings
          include :bundler, **bundler_settings if bundler_settings

          # @private
          def run # rubocop:disable all
            gem "yard", *gem_version

            ::Dir.chdir(context_directory || ::Dir.getwd) do
              files = []
              template_files.each do |pattern|
                files.concat(::Dir.glob(pattern))
              end
              files.uniq!

              stats_options << "--list-undoc" if fail_on_undocumented_objects
              run_options << "--fail-on-warning" if fail_on_warning
              run_options << "--no-output" unless generate_output
              run_options << "--output-dir" << output_dir if output_dir
              run_options << "--no-public" unless show_public
              run_options << "--protected" if show_protected
              run_options << "--private" if show_private
              run_options << "--no-private" if hide_private_tag
              run_options << "-r" << readme if readme
              run_options << "-m" << markup if markup
              run_options << "-t" << yard_template if yard_template
              run_options << "-p" << template_path if template_path
              run_options << "-f" << yard_format if yard_format
              unless stats_options.empty?
                run_options << "--no-stats"
                stats_options << "--use-cache"
              end
              run_options.concat(files)

              code = <<~CODE
                gem 'yard', *#{gem_version.inspect}
                require 'yard'
                ::YARD::CLI::Yardoc.run(*#{run_options.inspect})
              CODE
              result = exec_ruby(["-e", code])
              if result.error?
                puts("Yardoc encountered errors", :red, :bold) unless verbosity.negative?
                exit(1)
              end
              unless stats_options.empty?
                code = <<~CODE
                  gem 'yard', *#{gem_version.inspect}
                  require 'yard'
                  ::YARD::CLI::Stats.run(*#{stats_options.inspect})
                CODE
                result = exec_ruby(["-e", code], out: :capture)
                puts result.captured_out
                if result.error?
                  puts("Yardoc encountered errors", :red, :bold) unless verbosity.negative?
                  exit(1)
                end
                exit_on_nonzero_status(result)
                if fail_on_undocumented_objects && result.captured_out =~ /Undocumented\sObjects:/
                  unless verbosity.negative?
                    puts("Yardoc encountered undocumented objects", :red, :bold)
                  end
                  exit(1)
                end
              end
            end
          end
        end
      end
    end
  end
end
