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
      # Default list subtools flags
      # @return [Array<String>]
      #
      DEFAULT_LIST_FLAGS = ["--tools"].freeze

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
      # Default show-all-subtools flags
      # @return [Array<String>]
      #
      DEFAULT_SHOW_ALL_SUBTOOLS_FLAGS = ["--all"].freeze

      ##
      # Key set when the show help flag is present
      # @return [Object]
      #
      SHOW_HELP_KEY = Object.new.freeze

      ##
      # Key set when the show usage flag is present
      # @return [Object]
      #
      SHOW_USAGE_KEY = Object.new.freeze

      ##
      # Key set when the show subtool list flag is present
      # @return [Object]
      #
      SHOW_LIST_KEY = Object.new.freeze

      ##
      # Key for the recursive setting
      # @return [Object]
      #
      RECURSIVE_SUBTOOLS_KEY = Object.new.freeze

      ##
      # Key for the search string
      # @return [Object]
      #
      SEARCH_STRING_KEY = Object.new.freeze

      ##
      # Key for the show-all-subtools setting
      # @return [Object]
      #
      SHOW_ALL_SUBTOOLS_KEY = Object.new.freeze

      ##
      # Key for the tool name
      # @return [Object]
      #
      TOOL_NAME_KEY = Object.new.freeze

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
      # @param [Boolean,Array<String>,Proc] list_flags Specify flags to
      #     display subtool list. The value may be any of the following:
      #
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_LIST_FLAGS}.
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
      # @param [Boolean,Array<String>,Proc] show_all_subtools_flags Specify
      #     flags to show all subtools, including hidden tools and non-runnable
      #     namespaces. The value may be any of the following:
      #
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_SHOW_ALL_SUBTOOLS_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      #
      # @param [Boolean] default_recursive Whether to search recursively for
      #     subtools by default. Default is `false`.
      # @param [Boolean] default_show_all_subtools Whether to show all subtools
      #     by default. Default is `false`.
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
                     list_flags: false,
                     recursive_flags: false,
                     search_flags: false,
                     show_all_subtools_flags: false,
                     default_recursive: false,
                     default_show_all_subtools: false,
                     fallback_execution: false,
                     allow_root_args: false,
                     show_source_path: false,
                     use_less: false,
                     stream: $stdout,
                     styled_output: nil)
        @help_flags = help_flags
        @usage_flags = usage_flags
        @list_flags = list_flags
        @recursive_flags = recursive_flags
        @search_flags = search_flags
        @show_all_subtools_flags = show_all_subtools_flags
        @default_recursive = default_recursive ? true : false
        @default_show_all_subtools = default_show_all_subtools ? true : false
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
          StandardMiddleware.append_common_flag_group(tool_definition)
          has_subtools = loader.has_subtools?(tool_definition.full_name)
          help_flags = add_help_flags(tool_definition)
          usage_flags = add_usage_flags(tool_definition)
          list_flags = has_subtools ? add_list_flags(tool_definition) : []
          if (!help_flags.empty? || !list_flags.empty? || @fallback_execution) && has_subtools
            add_recursive_flags(tool_definition)
            add_search_flags(tool_definition)
            add_show_all_subtools_flags(tool_definition)
          end
          if !help_flags.empty? || !usage_flags.empty? || !list_flags.empty?
            add_root_args(tool_definition)
          end
        end
        yield
      end

      ##
      # Display help text if requested.
      #
      def run(tool) # rubocop:disable Metrics/AbcSize
        if tool[SHOW_USAGE_KEY]
          terminal.puts(get_help_text(tool).usage_string(wrap_width: terminal.width))
        elsif tool[SHOW_LIST_KEY]
          terminal.puts(get_help_text(tool).list_string(recursive: tool[RECURSIVE_SUBTOOLS_KEY],
                                                        search: tool[SEARCH_STRING_KEY],
                                                        include_hidden: tool[SHOW_ALL_SUBTOOLS_KEY],
                                                        wrap_width: terminal.width))
        elsif should_show_help(tool)
          output_help(get_help_text(tool).help_string(recursive: tool[RECURSIVE_SUBTOOLS_KEY],
                                                      search: tool[SEARCH_STRING_KEY],
                                                      include_hidden: tool[SHOW_ALL_SUBTOOLS_KEY],
                                                      show_source_path: @show_source_path,
                                                      wrap_width: terminal.width))
        else
          yield
        end
      end

      private

      def terminal
        @terminal ||= Terminal.new(output: @stream, styled: @styled_output)
      end

      def should_show_help(tool)
        @fallback_execution && !tool[Tool::Keys::TOOL_DEFINITION].runnable? ||
          tool[SHOW_HELP_KEY]
      end

      def output_help(str)
        if less_path
          require "toys/utils/exec"
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
        require "toys/utils/help_text"
        tool_name = tool[TOOL_NAME_KEY]
        return Utils::HelpText.from_tool(tool) if tool_name.nil? || tool_name.empty?
        loader = tool[Tool::Keys::LOADER]
        tool_definition, rest = loader.lookup(tool_name)
        help_text = Utils::HelpText.new(tool_definition, loader, tool[Tool::Keys::BINARY_NAME])
        report_usage_error(tool_name, help_text) unless rest.empty?
        help_text
      end

      def report_usage_error(tool_name, help_text)
        terminal.puts("Tool not found: #{tool_name.join(' ')}", :bright_red, :bold)
        terminal.puts
        terminal.puts help_text.usage_string(wrap_width: terminal.width)
        Tool.exit(1)
      end

      def add_help_flags(tool_definition)
        flags = resolve_flags_spec(@help_flags, tool_definition, DEFAULT_HELP_FLAGS)
        unless flags.empty?
          tool_definition.add_flag(
            SHOW_HELP_KEY, flags,
            report_collisions: false,
            desc: "Display help for this tool",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
        flags
      end

      def add_usage_flags(tool_definition)
        flags = resolve_flags_spec(@usage_flags, tool_definition, DEFAULT_USAGE_FLAGS)
        unless flags.empty?
          tool_definition.add_flag(
            SHOW_USAGE_KEY, flags,
            report_collisions: false,
            desc: "Display a brief usage string for this tool",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
        flags
      end

      def add_list_flags(tool_definition)
        flags = resolve_flags_spec(@list_flags, tool_definition, DEFAULT_LIST_FLAGS)
        unless flags.empty?
          tool_definition.add_flag(
            SHOW_LIST_KEY, flags,
            report_collisions: false,
            desc: "List the subtools under this tool",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
        flags
      end

      def add_recursive_flags(tool_definition)
        flags = resolve_flags_spec(@recursive_flags, tool_definition, DEFAULT_RECURSIVE_FLAGS)
        if flags.empty?
          tool_definition.default_data[RECURSIVE_SUBTOOLS_KEY] = @default_recursive
        else
          tool_definition.add_flag(
            RECURSIVE_SUBTOOLS_KEY, flags,
            report_collisions: false, default: @default_recursive,
            desc: "List all subtools recursively when displaying help" \
                  " (default is #{@default_recursive})",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
        flags
      end

      def add_search_flags(tool_definition)
        flags = resolve_flags_spec(@search_flags, tool_definition, DEFAULT_SEARCH_FLAGS)
        unless flags.empty?
          tool_definition.add_flag(
            SEARCH_STRING_KEY, flags,
            report_collisions: false,
            desc: "Search subtools for the given regular expression when displaying help",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
        flags
      end

      def add_show_all_subtools_flags(tool_definition)
        flags = resolve_flags_spec(@show_all_subtools_flags, tool_definition,
                                   DEFAULT_SHOW_ALL_SUBTOOLS_FLAGS)
        if flags.empty?
          tool_definition.default_data[SHOW_ALL_SUBTOOLS_KEY] = @default_show_all_subtools
        else
          tool_definition.add_flag(
            SHOW_ALL_SUBTOOLS_KEY, flags,
            report_collisions: false, default: @default_show_all_subtools,
            desc: "List all subtools including hidden subtools and namespaces" \
                  " (default is #{@default_show_all_subtools})",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
        flags
      end

      def add_root_args(tool_definition)
        if @allow_root_args && tool_definition.root? && tool_definition.arg_definitions.empty?
          tool_definition.set_remaining_args(TOOL_NAME_KEY,
                                             display_name: "TOOL_NAME",
                                             desc: "The tool for which to display help")
        end
      end

      def resolve_flags_spec(flags, tool_definition, defaults)
        flags = flags.call(tool_definition) if flags.respond_to?(:call)
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
