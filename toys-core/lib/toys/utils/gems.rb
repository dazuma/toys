# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

require "toys/utils/exec"

module Toys
  module Utils
    ##
    # A helper module that activates and installs gems.
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
        def initialize(requirements_text, gemfile_path)
          super("Required gem not available in the bundle: #{requirements_text}.\n" \
                "Please update your Gemfile #{gemfile_path.inspect}.")
        end
      end

      ##
      # Activate the given gem. If it is not present, attempt to install it (or
      # inform the user to update the bundle).
      #
      # @param [String] name Name of the gem
      # @param [String...] requirements Version requirements
      #
      def self.activate(name, *requirements)
        new.activate(name, *requirements)
      end

      ##
      # Create a new gem activator.
      #
      # @param [IO] input Input IO
      # @param [IO] output Output IO
      # @param [Boolean] suppress_confirm Suppress the confirmation prompt and
      #     just use the given `default_confirm` value. Default is false,
      #     indicating the confirmation prompt appears by default.
      # @param [Boolean] default_confirm Default response for the confirmation
      #     prompt. Default is true.
      #
      def initialize(input: $stdin,
                     output: $stderr,
                     suppress_confirm: false,
                     default_confirm: true)
        @terminal = Terminal.new(input: input, output: output)
        @exec = Utils::Exec.new
        @suppress_confirm = suppress_confirm ? true : false
        @default_confirm = default_confirm ? true : false
      end

      ##
      # Activate the given gem. If it is not present, attempt to install it (or
      # inform the user to update the bundle).
      #
      # @param [String] name Name of the gem
      # @param [String...] requirements Version requirements
      #
      def activate(name, *requirements)
        gem(name, *requirements)
      rescue ::Gem::LoadError => e
        handle_activation_error(e, name, requirements)
      end

      private

      def handle_activation_error(error, name, requirements)
        is_missing_spec =
          if defined?(::Gem::MissingSpecError)
            error.is_a?(::Gem::MissingSpecError)
          else
            error.message.include?("Could not find")
          end
        unless is_missing_spec
          report_error(name, requirements, error)
          return
        end
        install_gem(name, requirements)
        begin
          gem(name, *requirements)
        rescue ::Gem::LoadError => e
          report_error(name, requirements, e)
        end
      end

      def gem_requirements_text(name, requirements)
        "#{name.inspect}, #{requirements.map(&:inspect).join(', ')}"
      end

      def install_gem(name, requirements)
        requirements_text = gem_requirements_text(name, requirements)
        response =
          if @suppress_confirm
            @default_confirm
          else
            @terminal.confirm("Gem needed: #{requirements_text}. Install? ",
                              default: @default_confirm)
          end
        unless response
          raise InstallFailedError, "Canceled installation of needed gem: #{requirements_text}"
        end
        perform_install(name, requirements)
      end

      def perform_install(name, requirements)
        result = @terminal.spinner(leading_text: "Installing gem #{name}... ",
                                   final_text: "Done.\n") do
          @exec.exec(["gem", "install", name, "--version", requirements.join(",")],
                     out: :capture, err: :capture)
        end
        @terminal.puts(result.captured_out + result.captured_err)
        if result.error?
          raise InstallFailedError, "Failed to install gem #{name}"
        end
        ::Gem::Specification.reset
      end

      def report_error(name, requirements, err)
        if ::ENV["BUNDLE_GEMFILE"]
          raise GemfileUpdateNeededError.new(gem_requirements_text(name, requirements),
                                             ::ENV["BUNDLE_GEMFILE"])
        end
        raise ActivationFailedError, err.message
      end
    end
  end
end
