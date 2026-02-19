# frozen_string_literal: true

module Toys
  module Templates
    ##
    # A template for tools that run minitest
    #
    class Minitest
      include Template

      ##
      # Default version requirements for gem names.
      # @return [Hash{String=>Array<String>}]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = {
        "minitest" => [">= 5.0", "< 7"].freeze,
        "minitest-mock" => ["~> 5.27"].freeze,
        "minitest-focus" => ["~> 1.4", ">= 1.4.1"].freeze,
        "minitest-rg" => ["~> 5.4"].freeze,
      }.freeze

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
      # @param minitest [String,Array<String>] Version requirements for
      #     the "minitest" gem. Optional. If not provided, defaults to the
      #     value given in {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      #     Ignored if bundler is enabled.
      # @param gem_version [String,Array<String>] Deprecated alias for the
      #     `minitest` argument.
      # @param minitest_mock [String,Array<String>,true] Include the
      #     "minitest-mock" gem with the given version requirements. If true
      #     is passed, the value in {DEFAULT_GEM_VERSION_REQUIREMENTS} is used.
      #     Ignored if bundler is enabled.
      # @param minitest_focus [String,Array<String>,true] Include the
      #     "minitest-focus" gem with the given version requirements. If true
      #     is passed, the value in {DEFAULT_GEM_VERSION_REQUIREMENTS} is used.
      #     Ignored if bundler is enabled.
      # @param minitest_rg [String,Array<String>,true] Include the
      #     "minitest-rg" gem with the given version requirements. If true
      #     is passed, the value in {DEFAULT_GEM_VERSION_REQUIREMENTS} is used.
      #     Ignored if bundler is enabled.
      # @param gems [Hash{String=>String|Array<String>|true}] Include the given
      #     gems with the given version requirements. If true is provided for
      #     a version, then no version requirements are imposed.
      #     Ignored if bundler is enabled.
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
      # @param mt_compat [boolean] If set to `true` or `false`, sets the
      #     `MT_COMPAT` environment variable accordingly. This may be required
      #     for certain older Minitest plugins. Optional. If not present, keeps
      #     any current setting.
      # @param context_directory [String] A custom context directory to use
      #     when executing this tool.
      #
      def initialize(name: nil,
                     minitest: nil,
                     minitest_mock: nil,
                     minitest_focus: nil,
                     minitest_rg: nil,
                     gems: nil,
                     gem_version: nil,
                     libs: nil,
                     files: nil,
                     seed: nil,
                     verbose: false,
                     warnings: true,
                     bundler: false,
                     mt_compat: nil,
                     context_directory: nil)
        @name = name
        @libs = libs
        @files = files
        @seed = seed
        @verbose = verbose
        @warnings = warnings
        @bundler = bundler
        @mt_compat = mt_compat
        @context_directory = context_directory
        @gem_dependencies = {}
        unless @bundler
          update_version_spec("minitest", minitest || gem_version || true)
          update_version_spec("minitest-mock", minitest_mock)
          update_version_spec("minitest-focus", minitest_focus)
          update_version_spec("minitest-rg", minitest_rg)
          update_gems(gems) if gems
        end
      end

      ##
      # Name of the tool to create.
      #
      # @param value [String]
      # @return [String]
      #
      attr_writer :name

      ##
      # Update gems and version requirements.
      # Ignored if bundler is enabled.
      #
      # @param gems [Hash{String=>String|Array<String>|true|false|nil}]
      #     A mapping from gem name to either the version requirements,
      #     `true` to indicate no particular version restrictions, or `false`
      #     or `nil` to remove the gem from the list. (Note that it is not
      #     possible to remove the `minitest` gem, and setting it to `nil`
      #     will simply restore the default version restrictions.)
      # @return [self]
      #
      def update_gems(gems)
        unless @bundler
          gems.each do |gem_name, version_requirements|
            update_version_spec(gem_name, version_requirements)
          end
        end
        self
      end

      ##
      # Version requirements for the minitest gem.
      # If set to `true` or `nil`, a default version requirement is used.
      # Ignored if bundler is enabled.
      #
      # @param value [String,Array<String>,true,nil]
      #
      def minitest=(value)
        update_version_spec("minitest", value || true) unless @bundler
      end
      alias gem_version= minitest=

      ##
      # Version requirements for the minitest-mock gem.
      # If set to `true`, a default version requirement is used.
      # If set to `nil`, minitest-mock is removed from the gem dependencies.
      # Ignored if bundler is enabled.
      #
      # @param value [String,Array<String>,true,nil]
      #
      def minitest_mock=(value)
        update_version_spec("minitest-mock", value) unless @bundler
      end

      ##
      # Version requirements for the minitest-focus gem.
      # If set to `true`, a default version requirement is used.
      # If set to `nil`, minitest-focus is removed from the gem dependencies.
      # Ignored if bundler is enabled.
      #
      # @param value [String,Array<String>,true,nil]
      #
      def minitest_focus=(value)
        update_version_spec("minitest-focus", value) unless @bundler
      end

      ##
      # Version requirements for the minitest-rg gem.
      # If set to `true`, a default version requirement is used.
      # If set to `nil`, minitest-rg is removed from the gem dependencies.
      # Ignored if bundler is enabled.
      #
      # @param value [String,Array<String>,true,nil]
      #
      def minitest_rg=(value)
        update_version_spec("minitest-rg", value) unless @bundler
      end

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
      # Adjust the `MT_COMPAT` environment variable when running tests. This
      # setting may be necessary for certain older Minitest plugins.
      #
      # Pass `true` to enable compat mode, `false` to disable it, or `nil` to
      # use any ambient setting from the current environment.
      #
      # @param value [true,false,nil]
      # @return [true,false,nil]
      #
      attr_writer :mt_compat

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
      attr_reader :mt_compat

      ##
      # @private
      #
      def gem_dependencies
        @bundler ? nil : @gem_dependencies
      end

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
          flag :include_name, "-i", "-n", "--include PATTERN", "--name PATTERN",
               desc: "Filter run on /regexp/ or string."
          flag :exclude_name, "-e", "--exclude PATTERN",
               desc: "Exclude /regexp/ or string from run."

          remaining_args :tests,
                         complete: :file_system,
                         desc: "Paths to the tests to run (defaults to all tests)"

          static :gem_dependencies, template.gem_dependencies
          static :libs, template.libs
          static :files, template.files
          static :template_verbose, template.verbose
          static :mt_compat, template.mt_compat

          # @private
          def run
            require "tempfile"
            loaded_gem_versions = load_gems
            ::Dir.chdir(context_directory || ::Dir.getwd) do
              ::Tempfile.create(["toys_minitest_", ".rb"]) do |script_file|
                script_file.write(ruby_script(loaded_gem_versions))
                script_file.close
                result = exec_ruby(ruby_args(script_file.path), env: ruby_env)
                if result.error?
                  logger.error("Minitest failed!")
                  exit(result.exit_code)
                end
              end
            end
          end

          # @private
          def load_gems
            return nil unless gem_dependencies
            gem_dependencies.each do |gem_name, version_requirements|
              next if gem_name == "minitest"
              gem gem_name, *version_requirements
            end
            gem "minitest", *gem_dependencies["minitest"]
            loaded_versions = {}
            ::Gem.loaded_specs.each_value do |spec|
              loaded_versions[spec.name] = spec.version.to_s if gem_dependencies.key?(spec.name)
            end
            loaded_versions
          end

          # @private
          def ruby_env
            case mt_compat
            when true
              { "MT_COMPAT" => "true" }
            when false
              { "MT_COMPAT" => nil }
            else
              {}
            end
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
            loaded_gems = ::Gem.loaded_specs
            ["minitest", "minitest-mock", "minitest-focus", "minitest-rg"].each do |gem_name|
              lines << "require #{gem_name.tr('-', '/').inspect}" if loaded_gems.key?(gem_name)
            end
            if tests.empty?
              files.each do |pattern|
                tests.concat(::Dir.glob(pattern))
              end
              tests.uniq!
            end
            lines << "require 'minitest/autorun'"
            lines.concat(tests.map { |path| "load #{path.inspect}" })
            lines << ""
            lines.join("\n")
          end

          # @private
          def ruby_args(script_path)
            args = []
            args << "-I#{libs.join(::File::PATH_SEPARATOR)}" unless libs.empty?
            args << "-w" if warnings
            args << script_path
            args << "--seed" << seed if seed
            vv = verbosity
            vv += 1 if template_verbose
            args << "--verbose" if vv.positive?
            args << "--name" << include_name if include_name
            args << "--exclude" << exclude_name if exclude_name
            args
          end
        end
      end

      private

      def update_version_spec(gem_name, version_requirements)
        version_requirements ||= true if gem_name == "minitest"
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
