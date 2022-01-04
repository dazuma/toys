# frozen_string_literal: true

require "monitor"
require "rubygems"

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
      # @return [void]
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
      # @param terminal [Toys::Utils::Terminal] Terminal to use (optional)
      # @param input [IO] Input IO (optional, defaults to STDIN)
      # @param output [IO] Output IO (optional, defaults to STDOUT)
      # @param suppress_confirm [Boolean] Deprecated. Use `on_missing` instead.
      # @param default_confirm [Boolean] Deprecated. Use `on_missing` instead.
      #
      def initialize(on_missing: nil,
                     on_conflict: nil,
                     terminal: nil,
                     input: nil,
                     output: nil,
                     suppress_confirm: nil,
                     default_confirm: nil)
        @default_confirm = default_confirm || default_confirm.nil? ? true : false
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
      # @return [void]
      #
      def activate(name, *requirements)
        Gems.synchronize do
          begin
            gem(name, *requirements)
          rescue ::Gem::LoadError => e
            handle_activation_error(e, name, requirements)
          end
        end
      end

      ##
      # Search for an appropriate Gemfile, and set up the bundle.
      #
      # @param groups [Array<String>] The groups to include in setup.
      #
      # @param gemfile_path [String] The path to the Gemfile to use. If `nil`
      #     or not given, the `:search_dirs` will be searched for a Gemfile.
      #
      # @param search_dirs [String,Array<String>] Directories in which to
      #     search for a Gemfile, if gemfile_path is not given. You can provide
      #     a single directory or an array of directories.
      #
      # @param gemfile_names [String,Array<String>] File names that are
      #     recognized as Gemfiles, when searching because gemfile_path is not
      #     given. Defaults to {DEFAULT_GEMFILE_NAMES}.
      #
      # @param retries [Integer] Number of times to retry bundler operations.
      #     Optional.
      #
      # @return [void]
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
          if configure_gemfile(gemfile_path)
            activate("bundler", "~> 2.2")
            require "bundler"
            setup_bundle(gemfile_path, groups: groups, retries: retries)
          end
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

      private

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

      def handle_activation_error(error, name, requirements)
        is_missing_spec =
          if defined?(::Gem::MissingSpecError)
            error.is_a?(::Gem::MissingSpecError)
          else
            error.message.include?("Could not find")
          end
        if !is_missing_spec || @on_missing == :error
          report_activation_error(name, requirements, error)
          return
        end
        confirm_and_install_gem(name, requirements)
        begin
          gem(name, *requirements)
        rescue ::Gem::LoadError => e
          report_activation_error(name, requirements, e)
        end
      end

      def gem_requirements_text(name, requirements)
        "#{name.inspect}, #{requirements.map(&:inspect).join(', ')}"
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

      def configure_gemfile(gemfile_path)
        old_path = ::ENV["BUNDLE_GEMFILE"]
        if old_path
          if gemfile_path != old_path
            case @on_conflict
            when :warn
              terminal.puts("Warning: could not set up bundler because it is already set up.", :red)
            when :error
              raise AlreadyBundledError, "Could not set up bundler because it is already set up"
            end
          end
          return false
        end
        ::ENV["BUNDLE_GEMFILE"] = gemfile_path
        true
      end

      def find_lockfile_path(gemfile_path)
        if ::File.basename(gemfile_path) == "gems.rb"
          ::File.join(::File.dirname(gemfile_path), "gems.locked")
        else
          "#{gemfile_path}.lock"
        end
      end

      def setup_bundle(gemfile_path, groups: nil, retries: nil)
        check_gemfile_compatibility(gemfile_path)
        groups = Array(groups)
        modified_gemfile_path = create_modified_gemfile(gemfile_path)
        begin
          attempt_setup_bundle(modified_gemfile_path, groups)
        rescue ::Bundler::GemNotFound, ::Bundler::VersionConflict
          ::Bundler.reset!
          restore_toys_libs
          install_bundle(modified_gemfile_path, retries: retries)
          attempt_setup_bundle(modified_gemfile_path, groups)
        ensure
          delete_modified_gemfile(modified_gemfile_path)
          ::ENV["BUNDLE_GEMFILE"] = gemfile_path
        end
        restore_toys_libs
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

      def check_gemfile_compatibility(gemfile_path)
        ::Bundler.configure
        builder = ::Bundler::Dsl.new
        builder.eval_gemfile(gemfile_path)
        check_gemfile_gem_compatibility(builder, "toys-core")
        check_gemfile_gem_compatibility(builder, "toys")
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
          ::File.open(modified_lockfile_path, "w") { |file| file.write(lockfile_content) }
        end
        modified_gemfile_path
      end

      def modified_gemfile_content(gemfile_path)
        is_running_toys = ::Toys.const_defined?(:VERSION)
        content = [::File.read(gemfile_path)]
        content << "has_toys_dep = dependencies.any? { |dep| dep.name == 'toys' }" unless is_running_toys
        content << "dependencies.delete_if { |dep| dep.name == 'toys-core' || dep.name == 'toys' }"
        repo_root = ::File.dirname(::File.dirname(::Toys::CORE_LIB_PATH)) if ::ENV["TOYS_DEV"]
        path = repo_root ? ::File.join(repo_root, "toys-core") : nil
        content << "gem 'toys-core', #{::Toys::Core::VERSION.inspect}, path: #{path.inspect}"
        path = repo_root ? ::File.join(repo_root, "toys") : nil
        guard = is_running_toys ? "" : " if has_toys_dep"
        content << "gem 'toys', #{::Toys::Core::VERSION.inspect}, path: #{path.inspect}#{guard}"
        content
      end

      def delete_modified_gemfile(modified_gemfile_path)
        ::File.delete(modified_gemfile_path) if ::File.exist?(modified_gemfile_path)
        modified_lockfile_path = find_lockfile_path(modified_gemfile_path)
        ::File.delete(modified_lockfile_path) if ::File.exist?(modified_lockfile_path)
      end

      def restore_toys_libs
        $LOAD_PATH.delete(::Toys::CORE_LIB_PATH)
        $LOAD_PATH.unshift(::Toys::CORE_LIB_PATH)
        if ::Toys.const_defined?(:LIB_PATH)
          $LOAD_PATH.delete(::Toys::LIB_PATH)
          $LOAD_PATH.unshift(::Toys::LIB_PATH)
        end
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
        if result.error?
          terminal.puts("Failed to install. Trying update...")
          result = exec_util.exec_ruby([bundler_bin, "update"] + args)
          unless result.success?
            raise ::Bundler::InstallError, "Failed to install or update bundle: #{gemfile_path}"
          end
        end
      end
    end
  end
end
