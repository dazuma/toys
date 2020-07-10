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
      #      *  `:confirm` - prompt the user on whether to install
      #      *  `:error` - raise an exception
      #      *  `:install` - just install the gem
      #     The default is `:confirm`.
      # @param on_conflict [:error,:warn,:ignore] What to do if bundler has
      #     already been run with a different Gemfile. Possible values:
      #      *  `:error` - raise an exception
      #      *  `:ignore` - just silently proceed without bundling again
      #      *  `:warn` - print a warning and proceed without bundling again
      #     The default is `:error`.
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
        @input = input || ::STDIN
        @output = output || ::STDOUT
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
      # Set up the bundle.
      #
      # @param groups [Array<String>] The groups to include in setup
      # @param search_dirs [Array<String>] Directories to search for a Gemfile
      # @return [void]
      #
      def bundle(groups: nil,
                 search_dirs: nil)
        Gems.synchronize do
          gemfile_path = find_gemfile(Array(search_dirs))
          if configure_gemfile(gemfile_path)
            activate("bundler", "~> 2.1")
            require "bundler"
            setup_bundle(gemfile_path, groups || [])
          end
        end
      end

      @global_mutex = ::Monitor.new

      ## @private
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
          response = terminal.confirm("Gem needed: #{requirements_text}. Install? ",
                                      default: @default_confirm)
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

      def find_gemfile(search_dirs)
        search_dirs.each do |dir|
          gemfile_path = ::File.join(dir, "Gemfile")
          return gemfile_path if ::File.readable?(gemfile_path)
        end
        raise GemfileNotFoundError, "Gemfile not found"
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

      def setup_bundle(gemfile_path, groups)
        begin
          modify_bundle_definition(gemfile_path)
          ::Bundler.setup(*groups)
        rescue ::Bundler::GemNotFound
          restore_toys_libs
          install_bundle(gemfile_path)
          ::Bundler.reset!
          modify_bundle_definition(gemfile_path)
          ::Bundler.setup(*groups)
        end
        restore_toys_libs
      end

      def modify_bundle_definition(gemfile_path)
        builder = ::Bundler::Dsl.new
        builder.eval_gemfile(gemfile_path)
        begin
          builder.eval_gemfile(::File.join(__dir__, "gems", "gemfile.rb"))
        rescue ::Bundler::Dsl::DSLError
          terminal.puts(
            "WARNING: Unable to integrate your Gemfile into the Toys runtime.\n" \
            "When using the Toys Bundler integration features, do NOT list\n" \
            "the toys or toys-core gems directly in your Gemfile. They can be\n" \
            "dependencies of another gem, but cannot be listed directly.",
            :red
          )
          return
        end
        toys_gems = ["toys-core"]
        toys_gems << "toys" if ::Toys.const_defined?(:VERSION)
        definition = builder.to_definition(gemfile_path + ".lock", { gems: toys_gems })
        ::Bundler.instance_variable_set(:@definition, definition)
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
          terminal.confirm("Your bundle is not complete. Install? ", default: @default_confirm)
        end
      end

      def install_bundle(gemfile_path)
        gemfile_dir = ::File.dirname(gemfile_path)
        unless permission_to_bundle?
          raise BundleNotInstalledError,
                "Your bundle is not installed. Consider running" \
                  " `cd #{gemfile_dir} && bundle install`"
        end
        require "bundler/cli"
        ::Bundler::CLI.start(["install"])
      end
    end
  end
end
