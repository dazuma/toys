# frozen_string_literal: true

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
      # @param help_flags [Boolean,Array<String>,Proc] Specify flags to
      #     display help. The value may be any of the following:
      #
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_HELP_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      #
      # @param usage_flags [Boolean,Array<String>,Proc] Specify flags to
      #     display usage. The value may be any of the following:
      #
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_USAGE_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      #
      # @param list_flags [Boolean,Array<String>,Proc] Specify flags to
      #     display subtool list. The value may be any of the following:
      #
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_LIST_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      #
      # @param recursive_flags [Boolean,Array<String>,Proc] Specify flags
      #     to control recursive subtool search. The value may be any of the
      #     following:
      #
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_RECURSIVE_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      #
      # @param search_flags [Boolean,Array<String>,Proc] Specify flags
      #     to search subtools for a search term. The value may be any of
      #     the following:
      #
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_SEARCH_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      #
      # @param show_all_subtools_flags [Boolean,Array<String>,Proc] Specify
      #     flags to show all subtools, including hidden tools and non-runnable
      #     namespaces. The value may be any of the following:
      #
      #     *  An array of flags.
      #     *  The `true` value to use {DEFAULT_SHOW_ALL_SUBTOOLS_FLAGS}.
      #     *  The `false` value for no flags. (Default)
      #     *  A proc that takes a tool and returns any of the above.
      #
      # @param default_recursive [Boolean] Whether to search recursively for
      #     subtools by default. Default is `false`.
      # @param default_show_all_subtools [Boolean] Whether to show all subtools
      #     by default. Default is `false`.
      # @param fallback_execution [Boolean] Cause the tool to display its own
      #     help text if it is not otherwise runnable. This is mostly useful
      #     for namespaces, which have children are not runnable. Default is
      #     `false`.
      # @param allow_root_args [Boolean] If the root tool includes flags for
      #     help or usage, and doesn't otherwise use positional arguments,
      #     then a tool name can be passed as arguments to display help for
      #     that tool.
      # @param show_source_path [Boolean] Show the source path section. Default
      #     is `false`.
      # @param separate_sources [Boolean] Split up tool list by source root.
      #     Defaults to false.
      # @param use_less [Boolean] If the `less` tool is available, and the
      #     output stream is a tty, then use `less` to display help text.
      # @param stream [IO] Output stream to write to. Default is stdout.
      # @param styled_output [Boolean,nil] Cause the tool to display help text
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
                     separate_sources: false,
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
        @separate_sources = separate_sources
        @stream = stream
        @styled_output = styled_output
        @use_less = use_less && !Compat.jruby?
      end

      ##
      # Configure flags and default data.
      #
      # @private
      #
      def config(tool, loader)
        unless tool.argument_parsing_disabled?
          StandardMiddleware.append_common_flag_group(tool)
          has_subtools = loader.has_subtools?(tool.full_name)
          help_flags = add_help_flags(tool)
          usage_flags = add_usage_flags(tool)
          list_flags = has_subtools ? add_list_flags(tool) : []
          can_display_help = !help_flags.empty? || !list_flags.empty? ||
                             !usage_flags.empty? || @fallback_execution
          if can_display_help && has_subtools
            add_recursive_flags(tool)
            add_search_flags(tool)
            add_show_all_subtools_flags(tool)
          end
        end
        yield
      end

      ##
      # Display help text if requested.
      #
      # @private
      #
      def run(context)
        if context[SHOW_USAGE_KEY]
          show_usage(context)
        elsif context[SHOW_LIST_KEY]
          show_list(context)
        elsif context[SHOW_HELP_KEY]
          show_help(context, true)
        else
          begin
            yield
          rescue NotRunnableError => e
            raise e unless @fallback_execution
            show_help(context, false)
          end
        end
      end

      private

      def terminal
        require "toys/utils/terminal"
        @terminal ||= Utils::Terminal.new(output: @stream, styled: @styled_output)
      end

      def show_usage(context)
        help_text = get_help_text(context, true)
        str = help_text.usage_string(
          recursive: context[RECURSIVE_SUBTOOLS_KEY],
          include_hidden: context[SHOW_ALL_SUBTOOLS_KEY],
          separate_sources: @separate_sources,
          wrap_width: terminal.width
        )
        terminal.puts(str)
      end

      def show_list(context)
        help_text = get_help_text(context, true)
        str = help_text.list_string(
          recursive: context[RECURSIVE_SUBTOOLS_KEY],
          search: context[SEARCH_STRING_KEY],
          include_hidden: context[SHOW_ALL_SUBTOOLS_KEY],
          separate_sources: @separate_sources,
          wrap_width: terminal.width
        )
        terminal.puts(str)
      end

      def show_help(context, use_extra_args)
        help_text = get_help_text(context, use_extra_args)
        str = help_text.help_string(
          recursive: context[RECURSIVE_SUBTOOLS_KEY],
          search: context[SEARCH_STRING_KEY],
          include_hidden: context[SHOW_ALL_SUBTOOLS_KEY],
          show_source_path: @show_source_path,
          separate_sources: @separate_sources,
          wrap_width: terminal.width
        )
        require "toys/utils/pager"
        use_pager = @use_less && @stream.tty?
        Utils::Pager.start(command: use_pager, fallback_io: terminal) do |io|
          io.puts(str)
        end
      end

      def get_help_text(context, use_extra_args)
        require "toys/utils/help_text"
        if use_extra_args && @allow_root_args && context[Context::Key::TOOL].root?
          tool_name = Array(context[Context::Key::UNMATCHED_POSITIONAL])
          unless tool_name.empty?
            cli = context[Context::Key::CLI]
            loader = cli.loader
            tool, rest = loader.lookup(tool_name)
            help_text = Utils::HelpText.new(tool, loader, cli.executable_name)
            report_usage_error(help_text, loader, tool.full_name, rest.first) unless rest.empty?
            return help_text
          end
        end
        Utils::HelpText.from_context(context)
      end

      def report_usage_error(help_text, loader, tool_name, next_word)
        dict = loader.list_subtools(tool_name).map(&:simple_name)
        suggestions = Compat.suggestions(next_word, dict)
        tool_name = (tool_name + [next_word]).join(" ")
        message = "Tool not found: \"#{tool_name}\""
        unless suggestions.empty?
          suggestions_str = suggestions.join("\n                 ")
          message = "#{message}\nDid you mean...  #{suggestions_str}"
        end
        terminal.puts(message, :bright_red, :bold)
        terminal.puts
        terminal.puts help_text.usage_string(wrap_width: terminal.width)
        Context.exit(1)
      end

      def add_help_flags(tool)
        flags = resolve_flags_spec(@help_flags, tool, DEFAULT_HELP_FLAGS)
        unless flags.empty?
          tool.add_flag(
            SHOW_HELP_KEY, flags,
            report_collisions: false,
            desc: "Display help for this tool",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
        flags
      end

      def add_usage_flags(tool)
        flags = resolve_flags_spec(@usage_flags, tool, DEFAULT_USAGE_FLAGS)
        unless flags.empty?
          tool.add_flag(
            SHOW_USAGE_KEY, flags,
            report_collisions: false,
            desc: "Display a brief usage string for this tool",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
        flags
      end

      def add_list_flags(tool)
        flags = resolve_flags_spec(@list_flags, tool, DEFAULT_LIST_FLAGS)
        unless flags.empty?
          tool.add_flag(
            SHOW_LIST_KEY, flags,
            report_collisions: false,
            desc: "List the subtools under this tool",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
        flags
      end

      def add_recursive_flags(tool)
        flags = resolve_flags_spec(@recursive_flags, tool, DEFAULT_RECURSIVE_FLAGS)
        if flags.empty?
          tool.default_data[RECURSIVE_SUBTOOLS_KEY] = @default_recursive
        else
          tool.add_flag(
            RECURSIVE_SUBTOOLS_KEY, flags,
            report_collisions: false, default: @default_recursive,
            desc: "List all subtools recursively when displaying help" \
                  " (default is #{@default_recursive})",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
        flags
      end

      def add_search_flags(tool)
        flags = resolve_flags_spec(@search_flags, tool, DEFAULT_SEARCH_FLAGS)
        unless flags.empty?
          tool.add_flag(
            SEARCH_STRING_KEY, flags,
            report_collisions: false,
            desc: "Search subtools for the given regular expression when displaying help",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
        flags
      end

      def add_show_all_subtools_flags(tool)
        flags = resolve_flags_spec(@show_all_subtools_flags, tool, DEFAULT_SHOW_ALL_SUBTOOLS_FLAGS)
        if flags.empty?
          tool.default_data[SHOW_ALL_SUBTOOLS_KEY] = @default_show_all_subtools
        else
          tool.add_flag(
            SHOW_ALL_SUBTOOLS_KEY, flags,
            report_collisions: false, default: @default_show_all_subtools,
            desc: "List all subtools including hidden subtools and namespaces" \
                  " (default is #{@default_show_all_subtools})",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
        flags
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
