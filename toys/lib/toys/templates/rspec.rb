# frozen_string_literal: true

module Toys
  module Templates
    ##
    # A template for tools that run rspec
    #
    class Rspec
      include Template

      ##
      # Default version requirements for gem names.
      # @return [Hash{String=>Array<String>}]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = {
        "rspec" => ["~> 3.1"].freeze,
      }.freeze

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
      # Note that arguments related to gem and bundler settings are defaults
      # that can be overridden by command line arguments.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param rspec [String,Array<String>] Version requirements for
      #     the "rspec" gem, used if bundler is not enabled.
      #     Optional. If not provided, defaults to the value given in
      #     {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param gem_version [String,Array<String>] Deprecated alias for the
      #     `rspec` argument.
      # @param gems [Hash{String=>String|Array<String>|true}] Include the given
      #     gems with the given version requirements. Used if bundler is not
      #     enabled. If the version requirement is set to `true`, then the
      #     default in {DEFAULT_GEM_VERSION_REQUIREMENTS} is used. If there
      #     is no default available, then no particular version requirements
      #     are imposed.
      # @param libs [Array<String>] An array of library paths to add to the
      #     ruby require path. Defaults to {DEFAULT_LIBS}.
      # @param options [String] The path to a custom options file, if any.
      # @param order [String] The order in which to run examples. Default is
      #     {DEFAULT_ORDER}.
      # @param format [String] The formatter code. Default is {DEFAULT_FORMAT}.
      # @param out [String] Write output to a file instead of stdout.
      # @param backtrace [boolean] Enable full backtrace (default is false).
      # @param pattern [String] A glob indicating the spec files to load.
      #     Defaults to {DEFAULT_PATTERN}.
      # @param warnings [boolean] If true, runs specs with Ruby warnings.
      #     Defaults to true.
      # @param bundler [boolean,Hash] If `false` (the default), bundler is not
      #     used unless enabled via command line argument. If `true` or a Hash
      #     of options, bundler is enabled by default unless disabled via a
      #     command line argument. See the documentation for the
      #     [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      #     for information on available options. Note that any `:setup` option
      #     is ignored; the bundle, if enabled, is always installed and set up
      #     at the start of the tool execution.
      # @param context_directory [String] A custom context directory to use
      #     when executing this tool.
      #
      def initialize(name: nil,
                     rspec: nil,
                     gem_version: nil,
                     gems: nil,
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
        @gem_dependencies = {}
        update_version_spec("rspec", rspec || gem_version)
        update_gems(gems) if gems
      end

      ##
      # Name of the tool to create.
      #
      # @param value [String]
      # @return [String]
      #
      attr_writer :name

      ##
      # Update the gems and version requirements that are used if bundler is
      # not enabled.
      #
      # @param gems [Hash{String=>String|Array<String>|true|false|nil}]
      #     A mapping from gem name to either the version requirements,
      #     `true` to use a default, or `false` or `nil` to remove the gem from
      #     the list. (Note that it is not possible to remove the `rspec`
      #     gem, and setting it to `nil` will simply restore the default
      #     version requirements.)
      # @return [self]
      #
      def update_gems(gems)
        gems.each do |gem_name, version_requirements|
          update_version_spec(gem_name, version_requirements)
        end
        self
      end

      ##
      # Version requirements for the rspec gem. Used if bundler is not used.
      # If set to `true` or `nil`, a default version requirement is used.
      #
      # @param value [String,Array<String>,true,nil]
      #
      def rspec=(value)
        update_version_spec("rspec", value)
      end
      alias gem_version= rspec=

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
      # @param value [boolean]
      # @return [boolean]
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
      # @param value [boolean]
      # @return [boolean]
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
      # @param value [boolean,Hash]
      # @return [boolean,Hash]
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
      attr_reader :options

      ##
      # @private
      #
      attr_reader :out

      ##
      # @private
      #
      attr_reader :backtrace

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
      attr_reader :gem_dependencies

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
      def order
        @order || DEFAULT_ORDER
      end

      ##
      # @private
      #
      def format
        @format || DEFAULT_FORMAT
      end

      ##
      # @private
      #
      def pattern
        @pattern || DEFAULT_PATTERN
      end

      ##
      # @private
      #
      def bundler_settings
        if @bundler.is_a?(::Hash)
          @bundler.merge({setup: :manual})
        else
          {setup: :manual}
        end
      end

      ##
      # @private
      #
      def default_to_bundler?
        @bundler ? true : false
      end

      on_expand do |template|
        tool(template.name) do
          desc "Run rspec on the current project."

          long_desc(
            "Run rspec specs for the current project.",
            "",
            "By default, executes specs matching the following pattern:"
          )
          long_desc(["  - `#{template.pattern}`"])
          long_desc(
            "To override this, pass the paths to the spec files to run as command line arguments." \
            " You can also filter by example name using the --example argument.",
            ""
          )
          if template.default_to_bundler?
            long_desc(
              "By default, uses the project bundle to load gems needed for testing, including the rspec gem.",
              "You can specify a particular Gemfile using the --gemfile argument." \
              " Alternatively, you can disable the bundle and manually specify the gem list using the --use-gem" \
              " and --omit-gem arguments."
            )
          else
            long_desc(
              "By default, loads the following gems with version constraints:"
            )
            template.gem_dependencies.each do |name, versions|
              spec = ([name] + versions).join(", ")
              long_desc(["  - `#{spec}`"])
            end
            long_desc(
              "To alter this list, use the --use-gem and --omit-gem arguments." \
              " Alternatively, you can use a bundle instead by passing the --gemfile argument."
            )
          end

          set_context_directory template.context_directory if template.context_directory

          include :exec
          include :gems

          include :bundler, **template.bundler_settings

          flag(:order, "--order TYPE") do
            default(template.order)
            desc("Run examples by the specified order type (default: #{template.order})")
          end
          flag(:format, "-f", "--format FORMATTER") do
            default(template.format)
            desc("Choose a formatter (default: #{template.format})")
          end
          flag(:out, "-o", "--out FILE") do
            default(template.out)
            desc("Write output to a file (default: #{template.out.inspect})")
          end
          flag(:backtrace, "-b", "--[no-]backtrace") do
            default(template.backtrace)
            desc("Enable full backtrace (default: #{template.backtrace})")
          end
          flag(:warnings, "-w", "--[no-]warnings") do
            default(template.warnings)
            desc("Turn on Ruby warnings (default: #{template.warnings})")
          end
          flag(:pattern, "-P", "--pattern PATTERN") do
            default(template.pattern)
            desc("Load files matching pattern (default: #{template.pattern.inspect})")
          end
          flag(:exclude_pattern, "--exclude-pattern PATTERN") do
            desc("Load files except those matching pattern.")
          end
          flag(:example, "-e", "--example STRING") do
            default([])
            handler(:push)
            desc("Run examples whose full nested names include STRING (may be used more than once).")
          end
          flag(:example_matches, "-E", "--example-matches REGEX") do
            default([])
            handler(:push)
            desc("Run examples whose full nested names match REGEX (may be used more than once).")
          end
          flag(:tag, "-t", "--tag TAG") do
            default([])
            handler(:push)
            desc("Run examples with the specified tag, or exclude examples by adding ~ before the tag.")
          end
          flag(:gemfile_path, "--gemfile PATH", "--gemfile-path PATH") do
            desc("Bundle with the given gemfile, overriding any static setting.")
            long_desc(
              "Bundle with the given gemfile, overriding any static setting.",
              "",
              "You must provide the path to the Gemfile to use. This may override any default project Gemfile.",
              "This flag is mutually exclusive with --use-gem and --omit-gem."
            )
          end
          flag(:override_use_gems, "--use-gem SPEC") do
            default([])
            handler(:push)
            desc("Install the given gem with version requirements, overriding any static setting.")
            long_desc(
              "Install the given gem with version requirements, overriding any static setting.",
              "",
              "The format is the gem name followed by zero or more version requirements, separated by commas.",
              "For example:",
              ["  --use-gem rspec,~>3.1"],
              "",
              "Each --use-gem flag specifies a single gem." \
              " You can provide any number of --use-gem flags to specify any number of gems.",
              "",
              "This flag can be used in conjunction with --omit-gem, but is mutually exclusive with --gemfile."
            )
          end
          flag(:override_omit_gems, "--omit-gem NAME") do
            default([])
            handler(:push)
            desc("Do not install the given gem, overriding any static setting.")
            long_desc(
              "Do not install the given gem, overriding any static setting.",
              "",
              "Each --omit-gem flag omits a single gem." \
              " You can provide any number of --omit-gem flags to specifically omit any number of gems.",
              "",
              "This flag can be used in conjunction with --use-gem, but is mutually exclusive with --gemfile."
            )
          end

          remaining_args :files,
                         complete: :file_system,
                         desc: "Paths to the specs to run (defaults to all specs)"

          static :libs, template.libs
          static :gem_dependencies, template.gem_dependencies
          static :default_to_bundler, template.default_to_bundler?
          static :rspec_options, template.options

          # @private
          def run
            require "tempfile"
            ::Dir.chdir(context_directory || ::Dir.getwd) do
              loaded_gem_versions = init_bundle_or_gems
              ::Tempfile.create(["toys-rspec-script-", ".rb"]) do |script_file|
                script_file.write(ruby_script(loaded_gem_versions))
                script_file.close
                result = exec_ruby(ruby_args(script_file.path))
                if result.error?
                  logger.error("RSpec failed!")
                  exit(result.exit_code)
                end
              end
            end
          end

          # @private
          def ruby_args(script_path) # rubocop:disable Metrics/AbcSize
            args = []
            args << "-I#{libs.join(::File::PATH_SEPARATOR)}" unless libs.empty?
            args << "-w" if warnings
            args << script_path
            args << "--options" << rspec_options if rspec_options
            args << "--order" << order if order
            args << "--format" << format if format
            args << "--out" << out if out
            args << "--backtrace" if backtrace
            args << "--pattern" << pattern
            args << "--exclude-pattern" << exclude_pattern if exclude_pattern
            example.each { |val| args << "--example" << val }
            example_matches.each { |val| args << "--example-matches" << val }
            tag.each { |val| args << "--tag" << val }
            args.concat(files)
            args
          end

          # @private
          def init_bundle_or_gems
            if gemfile_path && (!override_use_gems.empty? || !override_omit_gems.empty?)
              logger.error("--gemfile is mutually exclusive with --use-gem and --omit-gem")
              exit(1)
            end
            if gemfile_path ||
               (default_to_bundler && override_use_gems.empty? && override_omit_gems.empty?)
              bundler_setup(gemfile_path: gemfile_path)
              nil
            else
              load_gems
            end
          end

          # @private
          def load_gems
            updated_dependencies = updated_gem_dependencies
            updated_dependencies.each do |gem_name, version_requirements|
              next if gem_name == "rspec"
              gem gem_name, *version_requirements
            end
            gem "rspec", *updated_dependencies["rspec"]
            loaded_versions = {}
            ::Gem.loaded_specs.each_value do |spec|
              loaded_versions[spec.name] = spec.version.to_s if updated_dependencies.key?(spec.name)
            end
            loaded_versions
          end

          # @private
          def updated_gem_dependencies
            dependencies = gem_dependencies.dup
            override_use_gems.each do |spec|
              name, *versions = spec.strip.split(/\s*,\s*/)
              if name.to_s.empty?
                logger.error("Bad format for --use-gem: #{spec.inspect}")
                exit(1)
              end
              versions.delete_if(&:empty?)
              versions = ::Toys::Templates::Rspec::DEFAULT_GEM_VERSION_REQUIREMENTS[name] || [] if versions.empty?
              dependencies[name] = versions
            end
            override_omit_gems.each do |name|
              name = name.strip
              if name == "rspec"
                logger.warn("You cannot omit the rspec gem. Ignoring --omit-gem=rspec.")
              else
                dependencies.delete(name)
              end
            end
            dependencies
          end

          # @private
          def ruby_script(loaded_gem_versions)
            lines = []
            if loaded_gem_versions
              loaded_gem_versions.each do |gem_name, gem_version|
                lines << "gem #{gem_name.inspect}, '= #{gem_version}'"
              end
            else
              lines << "require 'bundler/setup'"
            end
            lines << "require 'rspec/core'"
            lines << "::RSpec::Core::Runner.invoke"
            lines << ""
            lines.join("\n")
          end
        end
      end

      private

      def update_version_spec(gem_name, version_requirements)
        version_requirements ||= true if gem_name == "rspec"
        if version_requirements
          @gem_dependencies[gem_name] =
            if version_requirements == true
              DEFAULT_GEM_VERSION_REQUIREMENTS[gem_name] || []
            else
              Array(version_requirements).map(&:to_s)
            end
        else
          @gem_dependencies.delete(gem_name)
          nil
        end
      end
    end
  end
end
