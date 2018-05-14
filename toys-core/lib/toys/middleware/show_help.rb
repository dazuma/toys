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
      #     Default is `true`.
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
                     stream: $stdout,
                     styled_output: nil)
        @help_flags = help_flags
        @usage_flags = usage_flags
        @fallback_execution = fallback_execution
        @recursive_flags = recursive_flags
        @search_flags = search_flags
        @default_recursive = default_recursive ? true : false
        @output = Utils::LineOutput.new(stream, styled: styled_output)
      end

      ##
      # Configure flags and default data.
      #
      def config(tool, loader)
        help_flags = Middleware.resolve_flags_spec(@help_flags, tool,
                                                   DEFAULT_HELP_FLAGS)
        unless help_flags.empty?
          desc = "Display help for this tool"
          tool.add_flag(:_show_help, *help_flags, desc: desc, only_unique: true)
        end
        usage_flags = Middleware.resolve_flags_spec(@usage_flags, tool,
                                                    DEFAULT_USAGE_FLAGS)
        unless usage_flags.empty?
          desc = "Display a brief usage string for this tool"
          tool.add_flag(:_show_usage, *usage_flags, desc: desc, only_unique: true)
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
        if @fallback_execution && !context[Context::TOOL].includes_executor? || context[:_show_help]
          help_text = Utils::HelpText.from_context(context)
          str = help_text.help_string(recursive: context[:_recursive_subtools],
                                      search: context[:_search_subtools],
                                      show_path: context[Context::VERBOSITY] > 0,
                                      wrap_width: ::HighLine.new.output_cols)
          @output.puts(str)
        elsif context[:_show_usage]
          help_text = Utils::HelpText.from_context(context)
          str = help_text.usage_string(wrap_width: ::HighLine.new.output_cols)
          @output.puts(str)
        else
          yield
        end
      end

      private

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
