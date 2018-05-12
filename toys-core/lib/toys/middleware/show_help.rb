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
    # A middleware that shows help text for the tool.
    #
    # This can be configured to display help text when a flag (typically
    # `--help`) is provided. It can also be configured to display help text
    # automatically for tools that do not have an executor.
    #
    # If a tool has no executor, this middleware can also add a
    # `--[no-]recursive` flag, which, when set to `true` (the default), shows
    # all subtools recursively rather than only immediate subtools.
    #
    class ShowHelp < Base
      ##
      # Default help flags
      # @return [Array<String>]
      #
      DEFAULT_HELP_FLAGS = ["-?", "--help"].freeze

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
      #     activate help. The value may be any of the following:
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_HELP_FLAGS}. (Default)
      #     *  The `false` value for no flags.
      #     *  A proc that takes a tool and returns any of the above.
      # @param [Boolean,Array<String>,Proc] recursive_flags Specify flags
      #     to control recursive subtool search. The value may be any of the
      #     following:
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_RECURSIVE_FLAGS}. (Default)
      #     *  The `false` value for no flags.
      #     *  A proc that takes a tool and returns any of the above.
      # @param [Boolean,Array<String>,Proc] search_flags Specify flags
      #     to search subtools for a search term. The value may be any of
      #     the following:
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_SEARCH_FLAGS}. (Default)
      #     *  The `false` value for no flags.
      #     *  A proc that takes a tool and returns any of the above.
      # @param [Boolean] default_recursive Whether to search recursively for
      #     subtools by default. Default is `true`.
      # @param [Boolean] fallback_execution Cause the tool to display its own
      #     help text if it does not otherwise have an executor. This is
      #     mostly useful for groups, which have children but no executor.
      #     Default is `true`.
      # @param [IO] stream Output stream to write to. Default is stdout.
      # @param [Boolean,nil] styled_output Cause the tool to display help text
      #     with ansi styles. If `nil`, display styles if the output stream is
      #     a tty. Default is `nil`.
      #
      def initialize(help_flags: true,
                     recursive_flags: true,
                     search_flags: true,
                     default_recursive: true,
                     fallback_execution: true,
                     stream: $stdout,
                     styled_output: nil)
        @help_flags = help_flags
        @recursive_flags = recursive_flags
        @search_flags = search_flags
        @default_recursive = default_recursive ? true : false
        @fallback_execution = fallback_execution
        @output = Utils::LineOutput.new(stream, styled: styled_output)
      end

      ##
      # Configure flags and default data.
      #
      def config(tool)
        help_flags = Middleware.resolve_flags_spec(@help_flags, tool,
                                                   DEFAULT_HELP_FLAGS)
        is_default = !tool.includes_executor? && @fallback_execution
        if !help_flags.empty?
          desc = "Show help message"
          desc << " (default for groups)" if is_default
          tool.add_flag(:_help, *help_flags,
                        desc: desc, default: is_default, only_unique: true)
        elsif is_default
          tool.default_data[:_help] = true
        end
        if !tool.includes_executor? && (!help_flags.empty? || @fallback_execution)
          add_recursive_flags(tool)
          add_search_flags(tool)
        end
        yield
      end

      ##
      # Display help text if requested.
      #
      def execute(context)
        if context[:_help]
          help_text = Utils::HelpText.from_context(context)
          width = ::HighLine.new.output_cols
          str = help_text.long_string(recursive: context[:_recursive_subtools],
                                      search: context[:_search_subtools],
                                      show_path: context[Context::VERBOSITY] > 0,
                                      wrap_width: width)
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
                        desc: "Search subtools for the given term",
                        only_unique: true)
        end
      end
    end
  end
end
