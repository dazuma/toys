# frozen_string_literal: true

require "fileutils"
require "monitor"

module Toys
  module Utils
    ##
    # A helper class that activates and installs gems and sets up bundler.
    #
    # This class is not loaded by default. Before using it directly, you should
    # `require "toys/utils/gems"`
    #
    class Gems
      ##
      # Failed to activate a gem.
      #
      class ActivationFailedError < ::StandardError
      end

      ##
      # Failed to install a gem.
      #
      class InstallFailedError < ActivationFailedError
      end

      ##
      # Need to add a gem to the bundle.
      #
      class GemfileUpdateNeededError < ActivationFailedError
        ##
        # Create a GemfileUpdateNeededError.
        #
        # @param requirements_text [String] Gems and versions missing.
        # @param gemfile_path [String] Path to the offending Gemfile.
        #
        def initialize(requirements_text, gemfile_path)
          super("Required gem not available in the bundle: #{requirements_text}.\n" \
                "Please update your Gemfile #{gemfile_path.inspect}.")
        end
      end

      ##
      # Failed to run Bundler
      #
      class BundlerFailedError < ::StandardError
      end

      ##
      # Could not find a Gemfile
      #
      class GemfileNotFoundError < BundlerFailedError
      end

      ##
      # The bundle is not and could not be installed
      #
      class BundleNotInstalledError < BundlerFailedError
      end

      ##
      # Bundler has already been run; cannot do so again
      #
      class AlreadyBundledError < BundlerFailedError
      end

      ##
      # The bundle contained a toys or toys-core dependency that is
      # incompatible with the currently running version.
      #
      class IncompatibleToysError < BundlerFailedError
      end

      ##
      # The gemfile names that are searched by default.
      # @return [Array<String>]
      #
      DEFAULT_GEMFILE_NAMES = [".gems.rb", "gems.rb", "Gemfile"].freeze

      ##
      # Activate the given gem. If it is not present, attempt to install it (or
      # inform the user to update the bundle).
      #
      # @param name [String] Name of the gem
      # @param requirements [String...] Version requirements
      #
      # @return [:activated] if the gem was activated
      # @return [:installed] if the gem was installed and activated
      # @return [false] if the gem had already been activated
      #
      # @raise [ActivationFailedError] if activation or install failed
      #
      def self.activate(name, *requirements)
        new.activate(name, *requirements)
      end

      ##
      # Create a new gem activator.
      #
      # @param on_missing [:confirm,:error,:install] What to do if a needed gem
      #     is not installed. Possible values:
      #
      #      *  `:confirm` - prompt the user on whether to install
      #      *  `:error` - raise an exception
      #      *  `:install` - just install the gem
      #
      #     The default is `:confirm`.
      #
      # @param on_conflict [:error,:warn,:ignore] What to do if bundler has
      #     already been run with a different Gemfile. Possible values:
      #
      #      *  `:error` - raise an exception
      #      *  `:ignore` - just silently proceed without bundling again
      #      *  `:warn` - print a warning and proceed without bundling again
      #
      #     The default is `:error`.
      #
      # @param default_confirm [boolean] The default confirmation result, if
      #     `on_missing` is set to `:confirm`. Defaults to true.
      # @param terminal [Toys::Utils::Terminal] Terminal to use (optional)
      # @param input [IO] Input IO (optional, defaults to STDIN)
      # @param output [IO] Output IO (optional, defaults to STDOUT)
      # @param suppress_confirm [boolean] Deprecated. Use `on_missing` instead.
      #
      def initialize(on_missing: nil,
                     on_conflict: nil,
                     terminal: nil,
                     input: nil,
                     output: nil,
                     suppress_confirm: nil,
                     default_confirm: nil)
        require "rubygems"
        unless suppress_confirm.nil?
          warn("The :suppress_confirm argument to Toys::Utils::Gems is deprecated. " \
               "Use :on_missing instead.")
        end
        default_confirm = true if default_confirm.nil?
        @default_confirm = default_confirm ? true : false
        @on_missing = on_missing ||
                      if suppress_confirm
                        @default_confirm ? :install : :error
                      else
                        :confirm
                      end
        @on_conflict = on_conflict || :error
        @terminal = terminal
        @input = input || $stdin
        @output = output || $stdout
      end

      ##
      # Activate the given gem. If it is not present, attempt to install it (or
      # inform the user to update the bundle).
      #
      # @param name [String] Name of the gem
      # @param requirements [String...] Version requirements
      #
      # @return [:activated] if the gem was activated
      # @return [:installed] if the gem was installed and activated
      # @return [false] if the gem had already been activated
      #
      # @raise [ActivationFailedError] if activation or install failed
      #
      def activate(name, *requirements)
        Gems.synchronize do
          gem(name, *requirements) ? :activated : false
        rescue ::Gem::LoadError => e
          handle_activation_error(e, name, requirements)
        end
      end

      ##
      # Search for an appropriate Gemfile, and set up the bundle.
      #
      # @param groups [Array<String>] The groups to include in setup.
      # @param gemfile_path [String] The path to the Gemfile to use. If `nil`
      #     or not given, the `:search_dirs` will be searched for a Gemfile.
      # @param search_dirs [String,Array<String>] Directories in which to
      #     search for a Gemfile, if gemfile_path is not given. You can provide
      #     a single directory or an array of directories.
      # @param gemfile_names [String,Array<String>] File names that are
      #     recognized as Gemfiles, when searching because gemfile_path is not
      #     given. Defaults to {DEFAULT_GEMFILE_NAMES}.
      # @param retries [Integer] Number of times to retry bundler operations.
      #     Optional.
      #
      # @return [:setup] if the bundle was set up with no install needed
      # @return [:installed] if the bundle was installed and set up
      # @return [:updated] if the bundle was updated and set up
      # @return [false] on a bundle conflict if configured not to raise an
      #     exception
      #
      # @raise [BundlerFailedError] if bundle setup failed
      #
      def bundle(groups: nil,
                 gemfile_path: nil,
                 search_dirs: nil,
                 gemfile_names: nil,
                 retries: nil)
        Array(search_dirs).each do |dir|
          break if gemfile_path
          gemfile_path = Gems.find_gemfile(dir, gemfile_names: gemfile_names)
        end
        raise GemfileNotFoundError, "Gemfile not found" unless gemfile_path
        gemfile_path = ::File.absolute_path(gemfile_path)
        Gems.synchronize do
          setup_bundle(gemfile_path, groups: Array(groups), retries: retries)
        end
      end

      # @private
      def self.find_gemfile(search_dir, gemfile_names: nil)
        gemfile_names ||= DEFAULT_GEMFILE_NAMES
        Array(gemfile_names).each do |file|
          gemfile_path = ::File.join(search_dir, file)
          return gemfile_path if ::File.readable?(gemfile_path)
        end
        nil
      end

      @global_mutex = ::Monitor.new

      # @private
      def self.synchronize(&block)
        @global_mutex.synchronize(&block)
      end

      @delete_at_exit_mutex = ::Mutex.new
      @delete_at_exit_list = nil

      # @private
      # This is a class method so the at_exit block doesn't hold onto an
      # instance for the duration of the Ruby process
      def self.delete_at_exit(path)
        @delete_at_exit_mutex.synchronize do
          if @delete_at_exit_list.nil?
            @delete_at_exit_list = []
            at_exit do
              @delete_at_exit_list.each { |del_path| ::FileUtils.rm_f(del_path) }
            end
          end
          @delete_at_exit_list << path
        end
      end

      private

      # ---- General private utilities ----

      def terminal
        @terminal ||= begin
          require "toys/utils/terminal"
          Utils::Terminal.new(input: @input, output: @output)
        end
      end

      def exec_util
        @exec_util ||= begin
          require "toys/utils/exec"
          Utils::Exec.new
        end
      end

      # ---- Private methods as part of gem activation ----

      def handle_activation_error(error, name, requirements)
        is_missing_spec =
          if defined?(::Gem::MissingSpecError)
            error.is_a?(::Gem::MissingSpecError)
          else
            error.message.include?("Could not find")
          end
        if !is_missing_spec || @on_missing == :error
          report_activation_error(name, requirements, error)
        end
        confirm_and_install_gem(name, requirements)
        begin
          gem(name, *requirements)
          :installed
        rescue ::Gem::LoadError => e
          report_activation_error(name, requirements, e)
        end
      end

      def gem_requirements_text(name, requirements)
        ([name] + requirements).map(&:inspect).join(", ")
      end

      def confirm_and_install_gem(name, requirements)
        if @on_missing == :confirm
          requirements_text = gem_requirements_text(name, requirements)
          response = terminal.confirm("Gem needed: #{requirements_text}. Install? ", default: @default_confirm)
          unless response
            raise InstallFailedError, "Canceled installation of needed gem: #{requirements_text}"
          end
        end
        result = exec_util.exec(["gem", "install", name, "--version", requirements.join(",")])
        if result.error?
          raise InstallFailedError, "Failed to install gem #{name}"
        end
        ::Gem::Specification.reset
      end

      def report_activation_error(name, requirements, err)
        if ::ENV["BUNDLE_GEMFILE"]
          raise GemfileUpdateNeededError.new(gem_requirements_text(name, requirements),
                                             ::ENV["BUNDLE_GEMFILE"])
        end
        raise ActivationFailedError, err.message
      end

      # ---- Private methods as part of bundle install and setup ----

      def setup_bundle(gemfile_path, groups: nil, retries: nil)
        configure_gemfile(gemfile_path) do
          activate_bundler
          check_gemfile_compatibility(gemfile_path)
          modified_gemfile_path = create_modified_gemfile(gemfile_path)
          result = nil
          begin
            attempt_setup_bundle(modified_gemfile_path, groups)
            result = :setup
          rescue *bundler_exceptions
            ::Bundler.reset!
            restore_toys_libs
            install_result = install_bundle(modified_gemfile_path, retries: retries)
            attempt_setup_bundle(modified_gemfile_path, groups)
            result = install_result
          ensure
            delete_modified_gemfile(modified_gemfile_path)
            ::Bundler.reset! if result.nil?
            restore_toys_libs
          end
          result
        end
      end

      def configure_gemfile(gemfile_path)
        old_path = ::ENV["BUNDLE_GEMFILE"]
        if old_path && gemfile_path != old_path
          case @on_conflict
          when :warn
            terminal.puts("Warning: could not set up bundle because another is already set up.", :red)
          when :error
            raise AlreadyBundledError, "Could not set up bundle because another is already set up"
          end
          return false
        end
        ::ENV["BUNDLE_GEMFILE"] = gemfile_path
        success = false
        result = nil
        begin
          result = yield
          success = true
        ensure
          ::ENV["BUNDLE_GEMFILE"] = success ? gemfile_path : old_path
        end
        result
      end

      def activate_bundler
        bundler_version_requirements =
          if ::RUBY_VERSION < "3"
            [">= 2.2", "< 2.5"]
          else
            [">= 2.2", "< 5"]
          end
        activate("bundler", *bundler_version_requirements)
        require "bundler"

        # Ensure certain built-in gems that may be used by bundler/rubygems
        # themselves are pre-activated so they can be included in the modified
        # gemfile. This prevents a gem version mismatch if bundler/rubygems
        # loads a version of the gem during the bundler setup code (i.e. after
        # the modified gemfile is created) but the gemfile lock itself calls
        # for a different version.
        require "uri"
        require "stringio"

        # Lock the bundler version, preventing bundler's SelfManager from
        # installing a different bundler and taking over the process.
        ::ENV["BUNDLER_VERSION"] = ::Bundler::VERSION
      end

      def check_gemfile_compatibility(gemfile_path)
        ::Bundler.configure
        builder = ::Bundler::Dsl.new
        builder.eval_gemfile(gemfile_path)
        check_gemfile_gem_compatibility(builder, "toys-core")
        check_gemfile_gem_compatibility(builder, "toys")
      ensure
        ::Bundler.reset!
      end

      def check_gemfile_gem_compatibility(builder, name)
        existing_dep = builder.dependencies.find { |dep| dep.name == name }
        if existing_dep && !existing_dep.requirement.satisfied_by?(::Gem::Version.new(::Toys::Core::VERSION))
          raise IncompatibleToysError,
                "The bundle lists #{name} #{existing_dep.requirement} as a dependency, which is" \
                " incompatible with the current toys version #{::Toys::Core::VERSION}."
        end
      end

      def create_modified_gemfile(gemfile_path)
        dir = ::File.dirname(gemfile_path)
        modified_gemfile_path = loop do
          timestamp = ::Time.now.strftime("%Y%m%d%H%M%S")
          uniquifier = rand(3_656_158_440_062_976).to_s(36) # 10 digits in base 36
          path = ::File.join(dir, ".toys-tmp-gemfile-#{timestamp}-#{uniquifier}")
          break path unless ::File.exist?(path)
        end
        ::File.open(modified_gemfile_path, "w") do |file|
          modified_gemfile_content(gemfile_path).each do |line|
            file.puts(line)
          end
        end
        lockfile_path = find_lockfile_path(gemfile_path)
        modified_lockfile_path = find_lockfile_path(modified_gemfile_path)
        if ::File.readable?(lockfile_path)
          lockfile_content = ::File.read(lockfile_path)
          ::File.write(modified_lockfile_path, lockfile_content)
        end
        modified_gemfile_path
      end

      def modified_gemfile_content(gemfile_path)
        content = [::File.read(gemfile_path)]
        loaded_gems = ::Gem.loaded_specs.values.sort_by(&:name)
        omit_list = ::Toys::Compat.gems_to_omit_from_bundles
        loaded_gems.delete_if { |spec| omit_list.include?(spec.name) } unless omit_list.empty?
        content << "toys_loaded_gems = #{loaded_gems.map(&:name).inspect}"
        content << "dependencies.delete_if { |dep| toys_loaded_gems.include?(dep.name) }"
        loaded_gems.each do |spec|
          path = custom_lib_paths[spec.name]
          path_suffix = path ? ", path: #{path.inspect}" : ""
          content << "gem #{spec.name.inspect}, '= #{spec.version}'#{path_suffix}"
        end
        content
      end

      def custom_lib_paths
        unless defined?(@custom_lib_paths)
          @custom_lib_paths = {}
          if ::ENV["TOYS_DEV"]
            repo_root = ::File.dirname(::File.dirname(::Toys::CORE_LIB_PATH))
            @custom_lib_paths["toys-core"] = ::File.join(repo_root, "toys-core")
            @custom_lib_paths["toys"] = ::File.join(repo_root, "toys")
          end
        end
        @custom_lib_paths
      end

      def delete_modified_gemfile(modified_gemfile_path)
        ::FileUtils.rm_f(modified_gemfile_path)
        modified_lockfile_path = find_lockfile_path(modified_gemfile_path)
        ::FileUtils.rm_f(modified_lockfile_path)
        # Also delete at exit in case bundler recreates the lockfile later
        Gems.delete_at_exit(modified_lockfile_path)
      end

      def find_lockfile_path(gemfile_path)
        if ::File.basename(gemfile_path) == "gems.rb"
          ::File.join(::File.dirname(gemfile_path), "gems.locked")
        else
          "#{gemfile_path}.lock"
        end
      end

      def attempt_setup_bundle(modified_gemfile_path, groups)
        ::ENV["BUNDLE_GEMFILE"] = modified_gemfile_path
        ::Bundler.configure
        ::Bundler.settings.temporary({gemfile: modified_gemfile_path}) do
          ::Bundler.ui.silence do
            ::Bundler.setup(*groups)
          end
        end
      end

      def bundler_exceptions
        @bundler_exceptions ||= begin
          exceptions = [::Bundler::GemNotFound]
          exceptions << ::Bundler::VersionConflict if ::Bundler.const_defined?(:VersionConflict)
          exceptions << ::Bundler::SolveFailure if ::Bundler.const_defined?(:SolveFailure)
          exceptions
        end
      end

      def install_bundle(gemfile_path, retries: nil)
        gemfile_dir = ::File.dirname(gemfile_path)
        unless permission_to_bundle?
          raise BundleNotInstalledError,
                "Your bundle is not installed. Consider running `cd #{gemfile_dir} && bundle install`"
        end
        retries = retries.to_i
        args = ["--gemfile=#{gemfile_path}"]
        args << "--retry=#{retries}" if retries.positive?
        bundler_bin = ::Gem.bin_path("bundler", "bundle", ::Bundler::VERSION)
        result = exec_util.exec_ruby([bundler_bin, "install"] + args)
        return :installed if result.success?
        terminal.puts("Failed to install bundle. Trying update...")
        result = exec_util.exec_ruby([bundler_bin, "update", "--all"] + args)
        return :updated if result.success?
        terminal.puts("Failed to update bundle. Trying update with clean lockfile...")
        lockfile_path = find_lockfile_path(gemfile_path)
        ::File.delete(lockfile_path) if ::File.exist?(lockfile_path) # rubocop:disable Lint/NonAtomicFileOperation
        result = exec_util.exec_ruby([bundler_bin, "update", "--all"] + args)
        return :updated if result.success?
        raise ::Bundler::InstallError, "Failed to install or update bundle: #{gemfile_path}"
      end

      def permission_to_bundle?
        case @on_missing
        when :install
          true
        when :error
          false
        else
          terminal.confirm("Your bundle requires additional gems. Install? ", default: @default_confirm)
        end
      end

      def restore_toys_libs
        $LOAD_PATH.delete(::Toys::CORE_LIB_PATH)
        $LOAD_PATH.unshift(::Toys::CORE_LIB_PATH)
        if ::Toys.const_defined?(:LIB_PATH)
          $LOAD_PATH.delete(::Toys::LIB_PATH)
          $LOAD_PATH.unshift(::Toys::LIB_PATH)
        end
      end
    end
  end
end
