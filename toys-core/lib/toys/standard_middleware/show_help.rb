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

module Toys
  module StandardMiddleware
    ##
    # A middleware that shows help text for the tool when a flag (typically
    # `--help`) is provided. It can also be configured to show help by
    # default if the tool is a namespace that is not runnable.
    #
    # If a tool is not runnable, this middleware can also add a
    # `--[no-]recursive` flag, which, when set to `true` (the default), shows
    # all subtools recursively rather than only immediate subtools. This
    # middleware can also search for keywords in its subtools.
    #
    class ShowHelp
      include Middleware

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
      #
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_HELP_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      #
      # @param [Boolean,Array<String>,Proc] usage_flags Specify flags to
      #     display usage. The value may be any of the following:
      #
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_USAGE_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      #
      # @param [Boolean,Array<String>,Proc] recursive_flags Specify flags
      #     to control recursive subtool search. The value may be any of the
      #     following:
      #
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_RECURSIVE_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      #
      # @param [Boolean,Array<String>,Proc] search_flags Specify flags
      #     to search subtools for a search term. The value may be any of
      #     the following:
      #
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_SEARCH_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      #
      # @param [Boolean] default_recursive Whether to search recursively for
      #     subtools by default. Default is `false`.
      # @param [Boolean] fallback_execution Cause the tool to display its own
      #     help text if it is not otherwise runnable. This is mostly useful
      #     for namespaces, which have children are not runnable. Default is
      #     `false`.
      # @param [Boolean] allow_root_args If the root tool includes flags for
      #     help or usage, and doesn't otherwise use positional arguments,
      #     then a tool name can be passed as arguments to display help for
      #     that tool.
      # @param [Boolean] show_source_path Show the source path section. Default
      #     is `false`.
      # @param [Boolean] use_less If the `less` tool is available, and the
      #     output stream is a tty, then use `less` to display help text.
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
                     show_source_path: false,
                     use_less: false,
                     stream: $stdout,
                     styled_output: nil)
        @help_flags = help_flags
        @usage_flags = usage_flags
        @recursive_flags = recursive_flags
        @search_flags = search_flags
        @default_recursive = default_recursive ? true : false
        @fallback_execution = fallback_execution
        @allow_root_args = allow_root_args
        @show_source_path = show_source_path
        @stream = stream
        @styled_output = styled_output
        @use_less = use_less
      end

      ##
      # Configure flags and default data.
      #
      def config(tool_definition, loader)
        unless tool_definition.argument_parsing_disabled?
          help_flags = add_help_flags(tool_definition)
          usage_flags = add_usage_flags(tool_definition)
          if @allow_root_args && (!help_flags.empty? || !usage_flags.empty?)
            if tool_definition.root? && tool_definition.arg_definitions.empty?
              tool_definition.set_remaining_args(:_tool_name,
                                                 display_name: "TOOL_NAME",
                                                 desc: "The tool for which to display help")
            end
          end
          if (!help_flags.empty? || @fallback_execution) &&
             loader.has_subtools?(tool_definition.full_name)
            add_recursive_flags(tool_definition)
            add_search_flags(tool_definition)
          end
        end
        yield
      end

      ##
      # Display help text if requested.
      #
      def run(tool)
        if tool[:_show_usage]
          help_text = get_help_text(tool)
          str = help_text.usage_string(wrap_width: terminal.width)
          terminal.puts(str)
        elsif @fallback_execution && !tool[Tool::Keys::TOOL_DEFINITION].runnable? ||
              tool[:_show_help]
          help_text = get_help_text(tool)
          str = help_text.help_string(recursive: tool[:_recursive_subtools],
                                      search: tool[:_search_subtools],
                                      show_source_path: @show_source_path,
                                      wrap_width: terminal.width)
          output_help(str)
        else
          yield
        end
      end

      private

      def terminal
        @terminal ||= Utils::Terminal.new(output: @stream, styled: @styled_output)
      end

      def output_help(str)
        if less_path
          Utils::Exec.new.exec([less_path, "-R"], in: [:string, str])
        else
          terminal.puts(str)
        end
      end

      def less_path
        unless defined? @less_path
          @less_path =
            if @use_less && @stream.tty?
              path = `which less`.strip
              path.empty? ? nil : path
            end
        end
        @less_path
      end

      def get_help_text(tool)
        tool_name = tool[:_tool_name]
        return Utils::HelpText.from_tool(tool) if tool_name.nil? || tool_name.empty?
        loader = tool[Tool::Keys::LOADER]
        tool_definition, rest = loader.lookup(tool_name)
        help_text = Utils::HelpText.new(tool_definition, loader, tool[Tool::Keys::BINARY_NAME])
        report_usage_error(tool, tool_name, help_text) unless rest.empty?
        help_text
      end

      def report_usage_error(tool, tool_name, help_text)
        terminal.puts("Tool not found: #{tool_name.join(' ')}", :bright_red, :bold)
        terminal.puts
        terminal.puts help_text.usage_string(wrap_width: terminal.width)
        tool.exit(1)
      end

      def add_help_flags(tool_definition)
        help_flags = resolve_flags_spec(@help_flags, tool_definition, DEFAULT_HELP_FLAGS)
        unless help_flags.empty?
          tool_definition.add_flag(
            :_show_help, help_flags,
            report_collisions: false,
            desc: "Display help for this tool"
          )
        end
        help_flags
      end

      def add_usage_flags(tool_definition)
        usage_flags = resolve_flags_spec(@usage_flags, tool_definition, DEFAULT_USAGE_FLAGS)
        unless usage_flags.empty?
          tool_definition.add_flag(
            :_show_usage, usage_flags,
            report_collisions: false,
            desc: "Display a brief usage string for this tool"
          )
        end
        usage_flags
      end

      def add_recursive_flags(tool_definition)
        recursive_flags = resolve_flags_spec(@recursive_flags, tool_definition,
                                             DEFAULT_RECURSIVE_FLAGS)
        unless recursive_flags.empty?
          tool_definition.add_flag(
            :_recursive_subtools, recursive_flags,
            report_collisions: false, default: @default_recursive,
            desc: "Show all subtools recursively (default is #{@default_recursive})"
          )
        end
      end

      def add_search_flags(tool_definition)
        search_flags = resolve_flags_spec(@search_flags, tool_definition, DEFAULT_SEARCH_FLAGS)
        unless search_flags.empty?
          tool_definition.add_flag(
            :_search_subtools, search_flags,
            report_collisions: false,
            desc: "Search subtools for the given regular expression"
          )
        end
      end

      def resolve_flags_spec(flags, tool, defaults)
        flags = flags.call(tool) if flags.respond_to?(:call)
        case flags
        when true, :default
          Array(defaults)
        when ::String
          [flags]
        when ::Array
          flags
        else
          []
        end
      end
    end
  end
end
