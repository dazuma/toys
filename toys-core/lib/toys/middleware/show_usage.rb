# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

require "toys/middleware/base"
require "toys/utils/usage"

module Toys
  module Middleware
    ##
    # A middleware that shows usage documentation.
    #
    # This can be configured to display usage text when a switch (typically
    # `--help`) is provided. It can also be configured to display usage text
    # automatically for tools that do not have an executor.
    #
    # If a tool has no executor, this middleware also adds a `--[no-]recursive`
    # flag, which, when set to `true` (the default), shows all subcommands
    # recursively rather than only immediate subcommands.
    #
    class ShowUsage < Base
      ##
      # Default help switches
      # @return [Array<String>]
      #
      DEFAULT_HELP_SWITCHES = ["-?", "--help"].freeze

      ##
      # Create a ShowUsage middleware.
      #
      # @param [Boolean,Array<String>,Proc] help_switches Specify switches to
      #     activate help. The value may be any of the following:
      #     *  An array of switches that cause the tool to display its usage.
      #     *  The `true` value to use {DEFAULT_HELP_SWITCHES}. (Default)
      #     *  The `false` value to disable help switches.
      #     *  A proc that takes a tool and returns any of the above.
      # @param [Boolean] fallback_execution Cause the tool to display its own
      #     usage text if it does not otherwise have an executor. This is
      #     mostly useful for groups, which have children but no executor.
      #     Default is `true`.
      #
      def initialize(help_switches: true, fallback_execution: true)
        @help_switches = help_switches
        @fallback_execution = fallback_execution
      end

      ##
      # Configure switches and default data.
      #
      def config(tool)
        help_switches = Middleware.resolve_switches_spec(@help_switches, tool,
                                                         DEFAULT_HELP_SWITCHES)
        if !help_switches.empty?
          tool.add_switch(:_help, *help_switches,
                          doc: "Show help message",
                          default: !tool.includes_executor? && @fallback_execution,
                          only_unique: true)
        elsif @fallback_execution
          tool.default_data[:_help] = !tool.includes_executor?
        end
        if !tool.includes_executor? && (!help_switches.empty? || @fallback_execution)
          tool.add_switch(:_recursive, "--[no-]recursive",
                          default: true,
                          doc: "Show all subcommands recursively (default is true)",
                          only_unique: true)
        end
        yield
      end

      ##
      # Display usage text if requested.
      #
      def execute(context)
        if context[:_help]
          puts(Utils::Usage.from_context(context).string(recursive: context[:_recursive]))
        else
          yield
        end
      end
    end
  end
end
