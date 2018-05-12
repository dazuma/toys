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

require "highline"

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
    # If a tool has no executor, this middleware can also add a
    # `--[no-]recursive` flag, which, when set to `true` (the default), shows
    # all subcommands recursively rather than only immediate subcommands.
    #
    class ShowUsage < Base
      ##
      # Default help switches
      # @return [Array<String>]
      #
      DEFAULT_HELP_SWITCHES = ["-?", "--help"].freeze

      ##
      # Default recursive switches
      # @return [Array<String>]
      #
      DEFAULT_RECURSIVE_SWITCHES = ["-r", "--[no-]recursive"].freeze

      ##
      # Default search switches
      # @return [Array<String>]
      #
      DEFAULT_SEARCH_SWITCHES = ["-s WORD", "--search=WORD"].freeze

      ##
      # Create a ShowUsage middleware.
      #
      # @param [Boolean,Array<String>,Proc] help_switches Specify switches to
      #     activate help. The value may be any of the following:
      #     *  An array of switches.
      #     *  The `true` value to use {DEFAULT_HELP_SWITCHES}. (Default)
      #     *  The `false` value for no switches.
      #     *  A proc that takes a tool and returns any of the above.
      # @param [Boolean,Array<String>,Proc] recursive_switches Specify switches
      #     to control recursive subcommand search. The value may be any of the
      #     following:
      #     *  An array of switches.
      #     *  The `true` value to use {DEFAULT_RECURSIVE_SWITCHES}. (Default)
      #     *  The `false` value for no switches.
      #     *  A proc that takes a tool and returns any of the above.
      # @param [Boolean,Array<String>,Proc] search_switches Specify switches
      #     to search subcommands for a search term. The value may be any of
      #     the following:
      #     *  An array of switches.
      #     *  The `true` value to use {DEFAULT_SEARCH_SWITCHES}. (Default)
      #     *  The `false` value for no switches.
      #     *  A proc that takes a tool and returns any of the above.
      # @param [Boolean] default_recursive Whether to search recursively for
      #     subcommands by default. Default is `true`.
      # @param [Boolean] fallback_execution Cause the tool to display its own
      #     usage text if it does not otherwise have an executor. This is
      #     mostly useful for groups, which have children but no executor.
      #     Default is `true`.
      #
      def initialize(help_switches: true,
                     recursive_switches: true,
                     search_switches: true,
                     default_recursive: true,
                     fallback_execution: true)
        @help_switches = help_switches
        @recursive_switches = recursive_switches
        @search_switches = search_switches
        @default_recursive = default_recursive ? true : false
        @fallback_execution = fallback_execution
      end

      ##
      # Configure switches and default data.
      #
      def config(tool)
        help_switches = Middleware.resolve_switches_spec(@help_switches, tool,
                                                         DEFAULT_HELP_SWITCHES)
        is_default = !tool.includes_executor? && @fallback_execution
        if !help_switches.empty?
          desc = "Show help message"
          desc << " (default for groups)" if is_default
          tool.add_switch(:_help, *help_switches,
                          desc: desc,
                          default: is_default,
                          only_unique: true)
        elsif is_default
          tool.default_data[:_help] = true
        end
        if !tool.includes_executor? && (!help_switches.empty? || @fallback_execution)
          add_recursive_switches(tool)
          add_search_switches(tool)
        end
        yield
      end

      ##
      # Display usage text if requested.
      #
      def execute(context)
        if context[:_help]
          usage = Utils::Usage.from_context(context)
          width = ::HighLine.new.output_cols
          puts(usage.long_string(recursive: context[:_recursive_subcommands],
                                 search: context[:_search_subcommands],
                                 show_path: context[Context::VERBOSITY] > 0,
                                 wrap_width: width))
        else
          yield
        end
      end

      private

      def add_recursive_switches(tool)
        recursive_switches = Middleware.resolve_switches_spec(@recursive_switches, tool,
                                                              DEFAULT_RECURSIVE_SWITCHES)
        unless recursive_switches.empty?
          tool.add_switch(:_recursive_subcommands, *recursive_switches,
                          default: @default_recursive,
                          desc: "Show all subcommands recursively" \
                                " (default is #{@default_recursive})",
                          only_unique: true)
        end
      end

      def add_search_switches(tool)
        search_switches = Middleware.resolve_switches_spec(@search_switches, tool,
                                                           DEFAULT_SEARCH_SWITCHES)
        unless search_switches.empty?
          tool.add_switch(:_search_subcommands, *search_switches,
                          desc: "Search subcommands for the given term",
                          only_unique: true)
        end
      end
    end
  end
end
