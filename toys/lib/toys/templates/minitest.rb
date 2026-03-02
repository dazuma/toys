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
      # Note that arguments related to gem and bundler settings are defaults
      # that can be overridden by command line arguments.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param minitest [String,Array<String>] Version requirements for
      #     the "minitest" gem, used if bundler is not enabled.
      #     Optional. If not provided, defaults to the value given in
      #     {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param gem_version [String,Array<String>] Deprecated alias for the
      #     `minitest` argument.
      # @param minitest_mock [String,Array<String>,true] Include the
      #     "minitest-mock" gem with the given version requirements. Used if
      #     bundler is not enabled. If true is passed, the value in
      #     {DEFAULT_GEM_VERSION_REQUIREMENTS} is used.
      # @param minitest_focus [String,Array<String>,true] Include the
      #     "minitest-focus" gem with the given version requirements. Used if
      #     bundler is not enabled. If true is passed, the value in
      #     {DEFAULT_GEM_VERSION_REQUIREMENTS} is used.
      # @param minitest_rg [String,Array<String>,true] Include the
      #     "minitest-rg" gem with the given version requirements. Used if
      #     bundler is not enabled. If true is passed, the value in
      #     {DEFAULT_GEM_VERSION_REQUIREMENTS} is used.
      # @param gems [Hash{String=>String|Array<String>|true}] Include the given
      #     gems with the given version requirements. Used if bundler is not
      #     enabled. If the version requirement is set to `true`, then a
      #     the default in {DEFAULT_GEM_VERSION_REQUIREMENTS} is used. If there
      #     is no default available, then no particular version requirements
      #     are imposed.
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
      #     used unless enabled via command line argument. If `true` or a Hash
      #     of options, bundler is enabled by default unless disabled via a
      #     command line argument. See the documentation for the
      #     [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      #     for information on available options. Note that any `:setup` option
      #     is ignored; the bundle, if enabled, is always installed and set up
      #     at the start of the tool execution.
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
        update_version_spec("minitest", minitest || gem_version)
        update_version_spec("minitest-mock", minitest_mock)
        update_version_spec("minitest-focus", minitest_focus)
        update_version_spec("minitest-rg", minitest_rg)
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
      #     the list. (Note that it is not possible to remove the `minitest`
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
      # Version requirements for the minitest gem. Used if bundler is not used.
      # If set to `true` or `nil`, a default version requirement is used.
      #
      # @param value [String,Array<String>,true,nil]
      #
      def minitest=(value)
        update_version_spec("minitest", value)
      end
      alias gem_version= minitest=

      ##
      # Version requirements for the minitest-mock gem. Used if bundler is not
      # used.
      # If set to `true`, a default version requirement is used.
      # If set to `nil`, minitest-mock is removed from the gem dependencies.
      #
      # @param value [String,Array<String>,true,nil]
      #
      def minitest_mock=(value)
        update_version_spec("minitest-mock", value)
      end

      ##
      # Version requirements for the minitest-focus gem. Used if bundler is not
      # used.
      # If set to `true`, a default version requirement is used.
      # If set to `nil`, minitest-focus is removed from the gem dependencies.
      #
      # @param value [String,Array<String>,true,nil]
      #
      def minitest_focus=(value)
        update_version_spec("minitest-focus", value)
      end

      ##
      # Version requirements for the minitest-rg gem. Used if bundler is not
      # used.
      # If set to `true`, a default version requirement is used.
      # If set to `nil`, minitest-rg is removed from the gem dependencies.
      #
      # @param value [String,Array<String>,true,nil]
      #
      def minitest_rg=(value)
        update_version_spec("minitest-rg", value)
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
      def files
        @files ? Array(@files) : DEFAULT_FILES
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
          desc("Run minitest-based tests for the current project.")

          long_desc(
            "Run minitest-based tests for the current project.",
            "",
            "By default, executes tests in the files that match the following patterns:"
          )
          template.files.each do |pattern|
            long_desc(["  - `#{pattern}`"])
          end
          long_desc(
            "To override this list, pass the paths to the test files to run as command line arguments." \
            " You can also filter the test names to run using the --include and --exclude arguments.",
            ""
          )
          if template.default_to_bundler?
            long_desc(
              "By default, uses the project bundle to load gems needed for testing, including the minitest gem.",
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

          flag(:seed, "-s", "--seed SEED") do
            default(template.seed)
            desc("Sets random seed.")
          end
          flag(:warnings, "-w", "--[no-]warnings") do
            default(template.warnings)
            desc("Turn on Ruby warnings (defaults to #{template.warnings})")
          end
          flag(:include_name, "-i", "-n", "--include PATTERN", "--name PATTERN") do
            desc("Include /regexp/ or string for run.")
            long_desc(
              "Include /regexp/ or string for run.",
              "",
              "If the argument begins and ends with slashes, it is treated as a regular expression that must" \
              " match test names in order to run them. Otherwise, the argument is treated as the name of the" \
              " single test to run.",
              "This can be combined with --exclude."
            )
          end
          flag(:exclude_name, "-e", "-x", "--exclude PATTERN") do
            desc("Exclude /regexp/ or string from run.")
            long_desc(
              "Exclude /regexp/ or string for run.",
              "",
              "If the argument begins and ends with slashes, it is treated as a regular expression that will" \
              " filter out any matching test names. Otherwise, the argument is treated as the name of the" \
              " single test to omit.",
              "This can be combined with --include."
            )
          end
          flag(:expand_globs, "--globs", "--expand-globs") do
            desc("Expand any literal globs in the test file arguments.")
          end
          flag(:preload_code, "--preload-code CODE") do
            desc("Ruby code to execute before loading tests.")
          end
          flag(:override_libs, "--libs PATH") do
            # The logic below requires this to default to nil instead of the empty array.
            handler(:push)
            desc("Override the test library paths.")
            long_desc(
              "Specifies require paths to use when running tests." \
              " Pass this flag multiple times to include multiple paths.",
              "",
              "If no --libs flags are present, defaults to the following list of paths:"
            )
            template.libs.each do |path|
              long_desc(["  - #{path}"])
            end
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
              ["  --use-gem minitest-focus,~>1.4"],
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

          remaining_args(:tests) do
            complete(:file_system)
            desc("Paths to the test files to load (defaults to all tests)")
            long_desc(
              "Paths to the test files to load.",
              "",
              "Defaults to all files matching the following patterns:"
            )
            template.files.each do |pattern|
              long_desc(["  - `#{pattern}`"])
            end
          end

          static :default_to_bundler, template.default_to_bundler?
          static :gem_dependencies, template.gem_dependencies
          static :libs, template.libs
          static :files, template.files
          static :template_verbose, template.verbose
          static :mt_compat, template.mt_compat

          # @private
          def run
            require "tempfile"
            ::Dir.chdir(context_directory || ::Dir.getwd) do
              loaded_gem_versions = init_bundle_or_gems
              found_tests = expand_tests
              validate_tests(found_tests)
              ::Tempfile.create(["toys-minitest-script-", ".rb"]) do |script_file|
                script_file.write(ruby_script(loaded_gem_versions, found_tests))
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
              next if gem_name == "minitest"
              gem gem_name, *version_requirements
            end
            gem "minitest", *updated_dependencies["minitest"]
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
              versions = ::Toys::Templates::Minitest::DEFAULT_GEM_VERSION_REQUIREMENTS[name] || [] if versions.empty?
              dependencies[name] = versions
            end
            override_omit_gems.each do |name|
              name = name.strip
              if name == "minitest"
                logger.warn("You cannot omit the minitest gem. Ignoring --omit-gem=minitest.")
              else
                dependencies.delete(name)
              end
            end
            dependencies
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
          def ruby_script(loaded_gem_versions, found_tests)
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
            lines << "require 'minitest/autorun'"
            lines.append(preload_code) if preload_code
            lines.concat(found_tests.map { |path| "load #{path.inspect}" })
            lines << ""
            lines.join("\n")
          end

          # @private
          def expand_tests
            if !tests.empty? && !expand_globs
              tests.dup
            else
              all_matches = []
              (tests.empty? ? files : tests).each do |pattern|
                matches = ::Dir.glob(pattern)
                logger.warn("Glob #{pattern.inspect} did not match anything") if matches.empty?
                all_matches.concat(matches)
              end
              all_matches.uniq
            end
          end

          # @private
          def validate_tests(found_tests)
            ok = true
            found_tests.each do |path|
              if ::File.file?(path) && ::File.readable?(path)
                logger.info("Reading test: #{path}")
              else
                logger.error("Unable to load test: #{path}")
                ok = false
              end
            end
            exit(1) unless ok
          end

          # @private
          def ruby_args(script_path)
            args = []
            effective_libs = override_libs || libs
            args << "-I#{effective_libs.join(::File::PATH_SEPARATOR)}" unless effective_libs.empty?
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
