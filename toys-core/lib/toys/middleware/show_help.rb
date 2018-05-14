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
require "toys/utils/help_text"
require "toys/utils/line_output"

module Toys
  module Middleware
    ##
    # A middleware that shows help text for the tool when a flag (typically
    # `--help`) is provided. It can also be configured to show help by
    # default if the tool is a group with no executor.
    #
    # If a tool has no executor, this middleware can also add a
    # `--[no-]recursive` flag, which, when set to `true` (the default), shows
    # all subtools recursively rather than only immediate subtools. This
    # middleware can also search for keywords in its subtools.
    #
    class ShowHelp < Base
      ##
      # Default help flags
      # @return [Array<String>]
      #
      DEFAULT_HELP_FLAGS = ["-?", "--help"].freeze

      ##
      # Default usage flags
      # @return [Array<String>]
      #
      DEFAULT_USAGE_FLAGS = ["--usage"].freeze

      ##
      # Default recursive flags
      # @return [Array<String>]
      #
      DEFAULT_RECURSIVE_FLAGS = ["-r", "--[no-]recursive"].freeze

      ##
      # Default search flags
      # @return [Array<String>]
      #
      DEFAULT_SEARCH_FLAGS = ["-s WORD", "--search=WORD"].freeze

      ##
      # Create a ShowHelp middleware.
      #
      # @param [Boolean,Array<String>,Proc] help_flags Specify flags to
      #     display help. The value may be any of the following:
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_HELP_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      # @param [Boolean,Array<String>,Proc] usage_flags Specify flags to
      #     display usage. The value may be any of the following:
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_USAGE_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      # @param [Boolean,Array<String>,Proc] recursive_flags Specify flags
      #     to control recursive subtool search. The value may be any of the
      #     following:
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_RECURSIVE_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      # @param [Boolean,Array<String>,Proc] search_flags Specify flags
      #     to search subtools for a search term. The value may be any of
      #     the following:
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_SEARCH_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      # @param [Boolean] default_recursive Whether to search recursively for
      #     subtools by default. Default is `false`.
      # @param [Boolean] fallback_execution Cause the tool to display its own
      #     help text if it does not otherwise have an executor. This is
      #     mostly useful for groups, which have children but no executor.
      #     Default is `false`.
      # @param [Boolean] allow_root_args If the root tool includes flags for
      #     help or usage, and doesn't otherwise use positional arguments,
      #     then a tool name can be passed as arguments to display help for
      #     that tool.
      # @param [IO] stream Output stream to write to. Default is stdout.
      # @param [Boolean,nil] styled_output Cause the tool to display help text
      #     with ansi styles. If `nil`, display styles if the output stream is
      #     a tty. Default is `nil`.
      #
      def initialize(help_flags: false,
                     usage_flags: false,
                     recursive_flags: false,
                     search_flags: false,
                     default_recursive: false,
                     fallback_execution: false,
                     allow_root_args: false,
                     stream: $stdout,
                     styled_output: nil)
        @help_flags = help_flags
        @usage_flags = usage_flags
        @recursive_flags = recursive_flags
        @search_flags = search_flags
        @default_recursive = default_recursive ? true : false
        @fallback_execution = fallback_execution
        @allow_root_args = allow_root_args
        @stream = stream
        @styled_output = styled_output
      end

      ##
      # Configure flags and default data.
      #
      def config(tool, loader)
        help_flags = add_help_flags(tool)
        usage_flags = add_usage_flags(tool)
        if @allow_root_args && (!help_flags.empty? || !usage_flags.empty?)
          if tool.root? && tool.arg_definitions.empty?
            tool.set_remaining_args(:_tool_name, display_name: "TOOL_NAME",
                                                 desc: "The tool for which to display help")
          end
        end
        if (!help_flags.empty? || @fallback_execution) && loader.has_subtools?(tool.full_name)
          add_recursive_flags(tool)
          add_search_flags(tool)
        end
        yield
      end

      ##
      # Display help text if requested.
      #
      def execute(context)
        if context[:_show_usage]
          help_text = get_help_text(context)
          str = help_text.usage_string(wrap_width: output_cols)
          output.puts(str)
        elsif @fallback_execution && !context[Context::TOOL].includes_executor? ||
              context[:_show_help]
          help_text = get_help_text(context)
          str = help_text.help_string(recursive: context[:_recursive_subtools],
                                      search: context[:_search_subtools],
                                      wrap_width: output_cols)
          output.puts(str)
        else
          yield
        end
      end

      private

      def output_cols
        @output_cols ||= ::HighLine.new(nil, @stream).output_cols
      end

      def output
        @output ||= Utils::LineOutput.new(@stream, styled: @styled_output)
      end

      def get_help_text(context)
        tool_name = context[:_tool_name]
        return Utils::HelpText.from_context(context) if tool_name.nil? || tool_name.empty?
        loader = context[Context::LOADER]
        tool, rest = loader.lookup(tool_name)
        help_text = Utils::HelpText.new(tool, loader, context[Context::BINARY_NAME])
        report_usage_error(tool_name, help_text) unless rest.empty?
        help_text
      end

      def report_usage_error(tool_name, help_text)
        output.puts("Tool not found: #{tool_name.join(' ')}", :bright_red, :bold)
        output.puts
        output.puts help_text.usage_string(wrap_width: output_cols)
        context.exit(1)
      end

      def add_help_flags(tool)
        help_flags = Middleware.resolve_flags_spec(@help_flags, tool,
                                                   DEFAULT_HELP_FLAGS)
        unless help_flags.empty?
          tool.add_flag(:_show_help, *help_flags,
                        desc: "Display help for this tool", only_unique: true)
        end
        help_flags
      end

      def add_usage_flags(tool)
        usage_flags = Middleware.resolve_flags_spec(@usage_flags, tool,
                                                    DEFAULT_USAGE_FLAGS)
        unless usage_flags.empty?
          tool.add_flag(:_show_usage, *usage_flags,
                        desc: "Display a brief usage string for this tool", only_unique: true)
        end
        usage_flags
      end

      def add_recursive_flags(tool)
        recursive_flags = Middleware.resolve_flags_spec(@recursive_flags, tool,
                                                        DEFAULT_RECURSIVE_FLAGS)
        unless recursive_flags.empty?
          tool.add_flag(:_recursive_subtools, *recursive_flags,
                        default: @default_recursive,
                        desc: "Show all subtools recursively (default is #{@default_recursive})",
                        only_unique: true)
        end
      end

      def add_search_flags(tool)
        search_flags = Middleware.resolve_flags_spec(@search_flags, tool,
                                                     DEFAULT_SEARCH_FLAGS)
        unless search_flags.empty?
          tool.add_flag(:_search_subtools, *search_flags,
                        desc: "Search subtools for the given regular expression",
                        only_unique: true)
        end
      end
    end
  end
end
