# frozen_string_literal: true

module Toys
  module Utils
    ##
    # A helper class that generates usage documentation for a tool.
    #
    # This class generates full usage documentation, including description,
    # flags, and arguments. It is used by middleware that implements help
    # and related options.
    #
    # This class is not loaded by default. Before using it directly, you should
    # `require "toys/utils/help_text"`
    #
    class HelpText
      ##
      # A catch-all usage error emitted during help generation that should be
      # logged by the caller
      #
      class HelpGenerationError < ::StandardError
      end

      ##
      # Default width of first column
      # @return [Integer]
      #
      DEFAULT_LEFT_COLUMN_WIDTH = 32

      ##
      # Default indent
      # @return [Integer]
      #
      DEFAULT_INDENT = 4

      ##
      # Create a usage helper given an execution context.
      #
      # @param context [Toys::Context] The current context.
      # @return [Toys::Utils::HelpText]
      #
      def self.from_context(context)
        delegates = []
        cur = context
        while (cur = cur[Context::Key::DELEGATED_FROM])
          delegates << cur[Context::Key::TOOL]
        end
        cli = context[Context::Key::CLI]
        new(context[Context::Key::TOOL], cli.loader, cli.executable_name, delegates: delegates)
      end

      ##
      # Create a usage helper.
      #
      # @param tool [Toys::ToolDefinition] The tool to document.
      # @param loader [Toys::Loader] A loader that can provide subcommands.
      # @param executable_name [String] The name of the executable.
      #     e.g. `"toys"`.
      # @param delegates [Array<Toys::ToolDefinition>] The delegation path to
      #     the tool.
      #
      # @return [Toys::Utils::HelpText]
      #
      def initialize(tool, loader, executable_name, delegates: [])
        @tool = tool
        @loader = loader
        @executable_name = executable_name
        @delegates = delegates
      end

      ##
      # The ToolDefinition being documented.
      # @return [Toys::ToolDefinition]
      #
      attr_reader :tool

      ##
      # Generate a short usage string.
      #
      # @param recursive [boolean] If true, and the tool is a namespace,
      #     display all subtools recursively. Defaults to false.
      # @param include_hidden [boolean] Include hidden subtools (i.e. whose
      #     names begin with underscore.) Default is false.
      # @param separate_sources [boolean] Split up tool list by source root.
      #     Defaults to false.
      # @param left_column_width [Integer] Width of the first column. Default
      #     is {DEFAULT_LEFT_COLUMN_WIDTH}.
      # @param indent [Integer] Indent width. Default is {DEFAULT_INDENT}.
      # @param wrap_width [Integer,nil] Overall width to wrap to. Default is
      #     `nil` indicating no wrapping.
      #
      # @return [String] A usage string.
      #
      def usage_string(recursive: false, include_hidden: false, separate_sources: false,
                       left_column_width: nil, indent: nil, wrap_width: nil)
        left_column_width ||= DEFAULT_LEFT_COLUMN_WIDTH
        indent ||= DEFAULT_INDENT
        subtools = collect_subtool_info(recursive, nil, include_hidden, separate_sources)
        assembler = UsageStringAssembler.new(
          @tool, @executable_name, subtools, separate_sources,
          indent, left_column_width, wrap_width
        )
        assembler.result
      end

      ##
      # Generate a long help string.
      #
      # @param recursive [boolean] If true, and the tool is a namespace,
      #     display all subtools recursively. Defaults to false.
      # @param search [String,nil] An optional string to search for when
      #     listing subtools. Defaults to `nil` which finds all subtools.
      # @param include_hidden [boolean] Include hidden subtools (i.e. whose
      #     names begin with underscore.) Default is false.
      # @param show_source_path [boolean] If true, shows the source path
      #     section. Defaults to false.
      # @param separate_sources [boolean] Split up tool list by source root.
      #     Defaults to false.
      # @param indent [Integer] Indent width. Default is {DEFAULT_INDENT}.
      # @param indent2 [Integer] Second indent width. Default is
      #     {DEFAULT_INDENT}.
      # @param wrap_width [Integer,nil] Wrap width of the column, or `nil` to
      #     disable wrap. Default is `nil`.
      # @param styled [boolean] Output ansi styles. Default is `true`.
      #
      # @return [String] A usage string.
      #
      def help_string(recursive: false, search: nil, include_hidden: false,
                      show_source_path: false, separate_sources: false,
                      indent: nil, indent2: nil, wrap_width: nil, styled: true)
        indent ||= DEFAULT_INDENT
        indent2 ||= DEFAULT_INDENT
        subtools = collect_subtool_info(recursive, search, include_hidden, separate_sources)
        assembler = HelpStringAssembler.new(
          @tool, @executable_name, @delegates, subtools, search,
          show_source_path, separate_sources,
          indent, indent2, wrap_width, styled
        )
        assembler.result
      end

      ##
      # Generate a subtool list string.
      #
      # @param recursive [boolean] If true, and the tool is a namespace,
      #     display all subtools recursively. Defaults to false.
      # @param search [String,nil] An optional string to search for when
      #     listing subtools. Defaults to `nil` which finds all subtools.
      # @param include_hidden [boolean] Include hidden subtools (i.e. whose
      #     names begin with underscore.) Default is false.
      # @param separate_sources [boolean] Split up tool list by source root.
      #     Defaults to false.
      # @param indent [Integer] Indent width. Default is {DEFAULT_INDENT}.
      # @param wrap_width [Integer,nil] Wrap width of the column, or `nil` to
      #     disable wrap. Default is `nil`.
      # @param styled [boolean] Output ansi styles. Default is `true`.
      #
      # @return [String] A usage string.
      #
      def list_string(recursive: false, search: nil, include_hidden: false,
                      separate_sources: false, indent: nil, wrap_width: nil, styled: true)
        indent ||= DEFAULT_INDENT
        subtools = collect_subtool_info(recursive, search, include_hidden, separate_sources)
        assembler = ListStringAssembler.new(@tool, subtools, recursive, search, separate_sources,
                                            indent, wrap_width, styled)
        assembler.result
      end

      private

      ##
      # Orchestrates subtool collection: lists, filters, and arranges into assembler-ready form.
      #
      # @param recursive [boolean] whether to list subtools recursively
      # @param search [String, nil] regex search string, or nil for no filtering
      # @param include_hidden [boolean] whether to include hidden subtools and namespaces
      # @param separate_sources [boolean] whether to group results by source root
      # @return [Array<[String, Array<[String, ToolDefinition]>]>] list of
      #     `[source_name, [[local_name, subtool], ...]]` pairs, sorted by source priority
      #
      def collect_subtool_info(recursive, search, include_hidden, separate_sources)
        subtools_by_name = list_subtools(recursive, include_hidden)
        filter_subtools(subtools_by_name, search)
        arrange_subtools(subtools_by_name, separate_sources)
      end

      ##
      # Queries the loader for all subtools of the tool and its delegates, building a flat map.
      # When a delegate and the tool share a subtool local name, the delegate's entry wins.
      #
      # @param recursive [boolean] whether to list subtools at all depths
      # @param include_hidden [boolean] whether to include hidden tools and namespaces
      # @return [Hash{String => ToolDefinition}] local subtool name to tool definition
      #
      def list_subtools(recursive, include_hidden)
        subtools_by_name = {}
        ([@tool] + @delegates).each do |tool|
          name_len = tool.full_name.length
          subtools = @loader.list_subtools(tool.full_name,
                                           recursive: recursive,
                                           include_hidden: include_hidden,
                                           include_namespaces: include_hidden,
                                           include_non_runnable: include_hidden)
          subtools.each do |subtool|
            local_name = subtool.full_name.slice(name_len..-1).join(" ")
            subtools_by_name[local_name] = subtool
          end
        end
        subtools_by_name
      end

      ##
      # Removes entries from the map that do not match the search string, checked
      # case-insensitively against local name and short description. Mutates the map in place.
      # Raises {HelpGenerationError} if the search string is not a valid regex.
      #
      # @param subtools_by_name [Hash{String => ToolDefinition}] mutated in place
      # @param search [String, nil] regex search string, or nil to skip filtering
      # @return [void]
      #
      def filter_subtools(subtools_by_name, search)
        if !search.nil? && !search.empty?
          regex = begin
            ::Regexp.new(search, ::Regexp::IGNORECASE)
          rescue ::RegexpError => e
            raise HelpGenerationError, "Bad search regex: #{e.message}"
          end
          subtools_by_name.delete_if do |local_name, tool|
            !regex.match?(local_name) && !regex.match?(tool.desc.to_s)
          end
        end
      end

      ##
      # Sorts subtools alphabetically, groups them by source root (or into a single group if
      # separate_sources is false), and sorts groups by descending source priority.
      #
      # @param subtools_by_name [Hash{String => ToolDefinition}] already-filtered subtool map
      # @param separate_sources [boolean] whether to group by source root
      # @return [Array<[String, Array<[String, ToolDefinition]>]>] list of
      #     `[source_name, [[local_name, subtool], ...]]` pairs
      #
      def arrange_subtools(subtools_by_name, separate_sources)
        subtool_list = subtools_by_name.sort_by { |(local_name, _tool)| local_name }
        result = {}
        subtool_list.each do |(local_name, subtool)|
          key = separate_sources ? subtool.source_root : nil
          (result[key] ||= []) << [local_name, subtool]
        end
        result.sort_by { |source, _subtools| -(source&.priority || -999_999) }
              .map { |source, subtools| [source&.source_name || "unknown source", subtools] }
      end

      ##
      # @private
      #
      class UsageStringAssembler
        ##
        # @private
        #
        def initialize(tool, executable_name, subtools, separate_sources,
                       indent, left_column_width, wrap_width)
          @tool = tool
          @executable_name = executable_name
          @subtools = subtools
          @separate_sources = separate_sources
          @indent = indent
          @left_column_width = left_column_width
          @wrap_width = wrap_width
          @right_column_wrap_width = wrap_width ? wrap_width - left_column_width - indent - 1 : nil
          @lines = []
          assemble
        end

        ##
        # @private
        #
        attr_reader :result

        private

        ##
        # Runs all section-building methods and joins the accumulated lines into the result string.
        #
        # @return [void]
        #
        def assemble
          add_synopsis_section
          add_flag_group_sections
          add_positional_arguments_section if @tool.runnable?
          add_subtool_list_section
          joined_lines = @lines.join("\n")
          @result = "#{joined_lines}\n"
        end

        ##
        # Appends "Usage: ..." lines for the namespace synopsis (if the tool has subtools)
        # followed by the tool-specific synopsis.
        #
        # @return [void]
        #
        def add_synopsis_section
          synopses = []
          synopses << namespace_synopsis unless @subtools.empty?
          synopses << tool_synopsis
          first = true
          synopses.each do |synopsis|
            @lines << (first ? "Usage:  #{synopsis}" : "        #{synopsis}")
            first = false
          end
        end

        ##
        # Returns the synopsis line for the tool itself: executable name, optional `[FLAGS...]`,
        # and positional arg placeholders.
        #
        # @return [String]
        #
        def tool_synopsis
          synopsis = [@executable_name] + @tool.full_name
          synopsis << "[FLAGS...]" unless @tool.flags.empty?
          @tool.positional_args.each do |arg_info|
            synopsis << arg_name(arg_info)
          end
          synopsis.join(" ")
        end

        ##
        # Returns the synopsis line for dispatching to a subtool:
        # `executable name TOOL [ARGUMENTS...]`.
        #
        # @return [String]
        #
        def namespace_synopsis
          "#{@executable_name} #{@tool.display_name} TOOL [ARGUMENTS...]"
        end

        ##
        # Appends one labeled section per non-empty flag group, with each flag as a two-column row.
        #
        # @return [void]
        #
        def add_flag_group_sections
          @tool.flag_groups.each do |group|
            next if group.empty?
            @lines << ""
            desc_str = group.desc.to_s
            desc_str = "Flags" if desc_str.empty?
            @lines << "#{desc_str}:"
            group.flags.each do |flag|
              add_flag(flag)
            end
          end
        end

        ##
        # Appends one two-column row for a flag, showing all syntaxes joined by commas.
        # The value placeholder appears only on the last (canonical) form.
        #
        # @param flag [Flag]
        # @return [void]
        #
        def add_flag(flag)
          flags = flag.short_flag_syntax + flag.long_flag_syntax
          last_index = flags.size - 1
          flags_str = flags.each_with_index.map do |fs, i|
            i == last_index ? fs.canonical_str : fs.str_without_value
          end.join(", ")
          flags_str = "    #{flags_str}" if flag.short_flag_syntax.empty?
          add_right_column_desc(flags_str, wrap_desc(flag.desc))
        end

        ##
        # Appends the "Positional arguments:" section listing each arg as a two-column row.
        # Does nothing if the tool has no positional args.
        #
        # @return [void]
        #
        def add_positional_arguments_section
          args_to_display = @tool.positional_args
          return if args_to_display.empty?
          @lines << ""
          @lines << "Positional arguments:"
          args_to_display.each do |arg_info|
            add_right_column_desc(arg_name(arg_info), wrap_desc(arg_info.desc))
          end
        end

        ##
        # Appends a `"Tools:"` (or `"Tools from <source>:"`) section for each group of subtools.
        #
        # @return [void]
        #
        def add_subtool_list_section
          @subtools.each do |source_name, subtool_list|
            @lines << ""
            @lines << (@separate_sources ? "Tools from #{source_name}:" : "Tools:")
            subtool_list.each do |local_name, subtool|
              add_right_column_desc(local_name, wrap_desc(subtool.desc))
            end
          end
        end

        ##
        # Appends a two-column row to @lines. The left column is `initial` padded to
        # `@left_column_width`; if it overflows, the description starts on the next line.
        #
        # @param initial [String]
        # @param desc [Array<String>] pre-wrapped description lines
        # @return [void]
        #
        def add_right_column_desc(initial, desc)
          initial = indent_str(initial.ljust(@left_column_width))
          remaining_doc = desc
          if initial.size <= @indent + @left_column_width
            @lines << "#{initial} #{desc.first}"
            remaining_doc = desc[1..] || []
          else
            @lines << initial
          end
          remaining_doc.each do |d|
            @lines << "#{' ' * (@indent + @left_column_width)} #{d}"
          end
        end

        ##
        # Returns the display name for a positional arg, bracketed according to its type.
        #
        # @param arg_info [PositionalArg]
        # @return [String] e.g. `"NAME"`, `"[NAME]"`, or `"[NAME...]"`
        #
        def arg_name(arg_info)
          case arg_info.type
          when :required
            arg_info.display_name
          when :optional
            "[#{arg_info.display_name}]"
          when :remaining
            "[#{arg_info.display_name}...]"
          end
        end

        ##
        # Wraps a description to fit in the right-column width.
        #
        # @param desc [WrappableString, String, nil]
        # @return [Array<String>]
        #
        def wrap_desc(desc)
          WrappableString.wrap_lines(desc, @right_column_wrap_width)
        end

        ##
        # Prepends `@indent` spaces to a string.
        #
        # @param str [String]
        # @return [String]
        #
        def indent_str(str)
          "#{' ' * @indent}#{str}"
        end
      end

      ##
      # @private
      #
      class HelpStringAssembler
        ##
        # @private
        #
        def initialize(tool, executable_name, delegates, subtools, search_term,
                       show_source_path, separate_sources, indent, indent2, wrap_width, styled)
          require "toys/utils/terminal"
          require "stringio"
          @tool = tool
          @executable_name = executable_name
          @delegates = delegates
          @subtools = subtools
          @search_term = search_term
          @show_source_path = show_source_path
          @separate_sources = separate_sources
          @indent = indent
          @indent2 = indent2
          @wrap_width = wrap_width
          @lines = Utils::Terminal.new(output: ::StringIO.new, styled: styled)
          assemble
        end

        ##
        # @private
        #
        attr_reader :result

        private

        ##
        # Runs all section-building methods and captures the terminal output as the result string.
        #
        # @return [void]
        #
        def assemble
          add_name_section
          add_synopsis_section
          add_description_section
          add_flag_group_sections
          add_positional_arguments_section
          add_subtool_list_section
          add_source_section
          @result = @lines.output.string
        end

        ##
        # Appends the NAME section header and the tool name with its short description.
        #
        # @return [void]
        #
        def add_name_section
          @lines << bold("NAME")
          name_str = ([@executable_name] + @tool.full_name).join(" ")
          add_prefix_with_desc(name_str, @tool.desc)
        end

        ##
        # Appends a "prefix - desc" entry, wrapping desc onto continuation lines at `@indent2`
        # if desc is a {WrappableString}.
        #
        # @param prefix [String]
        # @param desc [WrappableString, String]
        # @return [void]
        #
        def add_prefix_with_desc(prefix, desc)
          if desc.empty?
            @lines << indent_str(prefix)
          elsif !desc.is_a?(WrappableString)
            @lines << indent_str("#{prefix} - #{desc}")
          else
            desc = wrap_indent_indent2(WrappableString.new(["#{prefix} -"] + desc.fragments))
            @lines << indent_str(desc[0])
            desc[1..].each do |line|
              @lines << indent2_str(line)
            end
          end
        end

        ##
        # Appends the SYNOPSIS section header and all synopsis clauses.
        #
        # @return [void]
        #
        def add_synopsis_section
          @lines << ""
          @lines << bold("SYNOPSIS")
          add_synopsis_clause(namespace_synopsis) unless @subtools.empty?
          add_synopsis_clause(tool_synopsis(@tool))
        end

        ##
        # Appends one synopsis clause, indenting the first line at `@indent` and continuation
        # lines at `@indent + @indent2`.
        #
        # @param synopsis [Array<String>] wrapped synopsis lines
        # @return [void]
        #
        def add_synopsis_clause(synopsis)
          first = true
          synopsis.each do |line|
            @lines << (first ? indent_str(line) : indent2_str(line))
            first = false
          end
        end

        ##
        # Builds a wrapped synopsis clause for the given tool: executable name, flag groups
        # formatted by constraint type, and positional arg placeholders.
        #
        # @param tool_for_name [ToolDefinition] tool whose name is rendered in the clause
        # @return [Array<String>] wrapped synopsis lines
        #
        def tool_synopsis(tool_for_name)
          synopsis = [full_executable_name(tool_for_name)]
          @tool.flag_groups.each do |flag_group|
            case flag_group
            when FlagGroup::Required
              add_required_group_to_synopsis(flag_group, synopsis)
            when FlagGroup::ExactlyOne
              add_exactly_one_group_to_synopsis(flag_group, synopsis)
            when FlagGroup::AtMostOne
              add_at_most_one_group_to_synopsis(flag_group, synopsis)
            when FlagGroup::AtLeastOne
              add_at_least_one_group_to_synopsis(flag_group, synopsis)
            else
              add_ordinary_group_to_synopsis(flag_group, synopsis)
            end
          end
          @tool.positional_args.each do |arg_info|
            synopsis << arg_name(arg_info)
          end
          wrap_indent_indent2(WrappableString.new(synopsis))
        end

        ##
        # Appends each flag in an ordinary (optional) group to the synopsis token list
        # as `"[flagspec]"`.
        #
        # @param flag_group [FlagGroup]
        # @param synopsis [Array<String>] token list being built
        # @return [void]
        #
        def add_ordinary_group_to_synopsis(flag_group, synopsis)
          flag_group.flags.each do |flag|
            synopsis << "[#{flag_spec_string(flag, true)}]"
          end
        end

        ##
        # Appends each flag in a required group to the synopsis token list as `"(flagspec)"`.
        #
        # @param flag_group [FlagGroup::Required]
        # @param synopsis [Array<String>] token list being built
        # @return [void]
        #
        def add_required_group_to_synopsis(flag_group, synopsis)
          flag_group.flags.each do |flag|
            synopsis << "(#{flag_spec_string(flag, true)})"
          end
        end

        ##
        # Appends an exactly-one flag group to the synopsis token list
        # as `"( flag1 | flag2 | ... )"`.
        #
        # @param flag_group [FlagGroup::ExactlyOne]
        # @param synopsis [Array<String>] token list being built
        # @return [void]
        #
        def add_exactly_one_group_to_synopsis(flag_group, synopsis)
          return if flag_group.empty?
          synopsis << "("
          first = true
          flag_group.flags.each do |flag|
            if first
              first = false
            else
              synopsis << "|"
            end
            synopsis << flag_spec_string(flag, true)
          end
          synopsis << ")"
        end

        ##
        # Appends an at-most-one flag group to the synopsis token list
        # as `"[ flag1 | flag2 | ... ]"`.
        #
        # @param flag_group [FlagGroup::AtMostOne]
        # @param synopsis [Array<String>] token list being built
        # @return [void]
        #
        def add_at_most_one_group_to_synopsis(flag_group, synopsis)
          return if flag_group.empty?
          synopsis << "["
          first = true
          flag_group.flags.each do |flag|
            if first
              first = false
            else
              synopsis << "|"
            end
            synopsis << flag_spec_string(flag, true)
          end
          synopsis << "]"
        end

        ##
        # Appends an at-least-one flag group to the synopsis token list
        # as `"( [flag1] [flag2] ... )"`.
        #
        # @param flag_group [FlagGroup::AtLeastOne]
        # @param synopsis [Array<String>] token list being built
        # @return [void]
        #
        def add_at_least_one_group_to_synopsis(flag_group, synopsis)
          return if flag_group.empty?
          synopsis << "("
          flag_group.flags.each do |flag|
            synopsis << "[#{flag_spec_string(flag, true)}]"
          end
          synopsis << ")"
        end

        ##
        # Builds a wrapped synopsis clause for dispatching to a subtool:
        # `executable TOOL [ARGUMENTS...]`.
        #
        # @return [Array<String>] wrapped synopsis lines
        #
        def namespace_synopsis
          synopsis = [full_executable_name(@tool),
                      underline("TOOL"),
                      "[#{underline('ARGUMENTS')}...]"]
          wrap_indent_indent2(WrappableString.new(synopsis))
        end

        ##
        # Returns the bold-styled full executable name string for the given tool.
        #
        # @param tool_for_name [ToolDefinition]
        # @return [String]
        #
        def full_executable_name(tool_for_name)
          bold(([@executable_name] + tool_for_name.full_name).join(" "))
        end

        ##
        # Appends the SOURCE section if `@show_source_path` is enabled and the tool has a source
        # name. Lists source paths for the tool and each delegate.
        #
        # @return [void]
        #
        def add_source_section
          return unless @show_source_path && @tool.source_info&.source_name
          @lines << ""
          @lines << bold("SOURCE")
          @lines << indent_str("Defined in #{@tool.source_info.source_name}")
          @delegates.each do |delegate|
            location = delegate.source_info&.source_name || "(unknown)"
            @lines << indent_str("Delegated from \"#{delegate.display_name}\" defined in #{location}")
          end
        end

        ##
        # Appends the DESCRIPTION section combining the tool's and any delegates' long
        # descriptions. Does nothing if all descriptions are empty.
        #
        # @return [void]
        #
        def add_description_section
          desc = @tool.long_desc.dup
          @delegates.each do |delegate|
            desc << "" << "Delegated from \"#{delegate.display_name}\""
            unless delegate.long_desc.empty?
              desc << ""
              desc += delegate.long_desc
            end
          end
          desc = desc[1..] if desc.first == ""
          desc = wrap_indent(desc)
          return if desc.empty?
          @lines << ""
          @lines << bold("DESCRIPTION")
          desc.each do |line|
            @lines << indent_str(line)
          end
        end

        ##
        # Appends one styled section per non-empty flag group with an uppercased header,
        # optional long description, and each flag as an indented entry.
        #
        # @return [void]
        #
        def add_flag_group_sections
          @tool.flag_groups.each do |group|
            next if group.empty?
            @lines << ""
            desc_str = group.desc.to_s.upcase
            desc_str = "FLAGS" if desc_str.empty?
            @lines << bold(desc_str)
            precede_with_blank = false
            unless group.long_desc.empty?
              wrap_indent(group.long_desc).each do |line|
                @lines << indent_str(line)
              end
              precede_with_blank = true
            end
            group.flags.each do |flag|
              add_indented_section(flag_spec_string(flag), flag, precede_with_blank)
              precede_with_blank = true
            end
          end
        end

        ##
        # Returns the formatted string of all flag syntaxes, joined by `" | "` (in synopsis)
        # or `", "` (in the flags section), with value labels underlined.
        #
        # @param flag [Flag]
        # @param in_synopsis [boolean] whether to use the `" | "` separator (default: false)
        # @return [String]
        #
        def flag_spec_string(flag, in_synopsis = false)
          flag.flag_syntax.map do |fs|
            str = bold(fs.str_without_value)
            if fs.flag_type != :value
              str
            elsif fs.value_type == :optional
              "#{str}#{fs.value_delim}[#{underline(fs.value_label)}]"
            else
              "#{str}#{fs.value_delim}#{underline(fs.value_label)}"
            end
          end.join(in_synopsis ? " | " : ", ")
        end

        ##
        # Appends the POSITIONAL ARGUMENTS section with each arg as an indented entry.
        # Does nothing if the tool has no positional args.
        #
        # @return [void]
        #
        def add_positional_arguments_section
          args_to_display = @tool.positional_args
          return if args_to_display.empty?
          @lines << ""
          @lines << bold("POSITIONAL ARGUMENTS")
          precede_with_blank = false
          args_to_display.each do |arg_info|
            add_indented_section(arg_name(arg_info), arg_info, precede_with_blank)
            precede_with_blank = true
          end
        end

        ##
        # Appends the TOOLS section with an optional search header, source labels if
        # `@separate_sources` is set, and each subtool with its short description.
        #
        # @return [void]
        #
        def add_subtool_list_section
          return if @subtools.empty?
          @lines << ""
          @lines << bold("TOOLS")
          if @search_term
            @lines << indent_str("Showing search results for \"#{@search_term}\"")
            @lines << ""
          end
          first_section = true
          @subtools.each do |source_name, subtool_list|
            @lines << "" unless first_section
            if @separate_sources
              @lines << indent_str(underline("From #{source_name}"))
              @lines << ""
            end
            subtool_list.each do |local_name, subtool|
              add_prefix_with_desc(bold(local_name), subtool.desc)
            end
            first_section = false
          end
        end

        ##
        # Appends a single flag or positional arg entry: header at `@indent`, description at
        # `@indent + @indent2`. Uses long_desc if present, falling back to desc.
        #
        # @param header [String] formatted flag spec or arg name
        # @param info [Flag, PositionalArg]
        # @param precede_with_blank [boolean] whether to insert a blank line before the entry
        # @return [void]
        #
        def add_indented_section(header, info, precede_with_blank)
          @lines << "" if precede_with_blank
          @lines << indent_str(header)
          desc = wrap_indent2(info.long_desc)
          desc = wrap_indent2(info.desc) if desc.empty?
          desc.each do |line|
            @lines << indent2_str(line)
          end
        end

        ##
        # Returns the underlined, bracketed display name for a positional arg.
        #
        # @param arg_info [PositionalArg]
        # @return [String] e.g. underlined `"NAME"`, `"[NAME]"`, or `"[NAME...]"`
        #
        def arg_name(arg_info)
          case arg_info.type
          when :required
            underline(arg_info.display_name)
          when :optional
            "[#{underline(arg_info.display_name)}]"
          when :remaining
            "[#{underline(arg_info.display_name)}...]"
          end
        end

        ##
        # Wraps text to fit within `@wrap_width - @indent` characters, or unwrapped if no
        # wrap width is set.
        #
        # @param input [WrappableString, Array, String]
        # @return [Array<String>]
        #
        def wrap_indent(input)
          return WrappableString.wrap_lines(input, nil) unless @wrap_width
          WrappableString.wrap_lines(input, @wrap_width - @indent)
        end

        ##
        # Wraps text to fit within `@wrap_width - @indent - @indent2` characters, or unwrapped
        # if no wrap width is set.
        #
        # @param input [WrappableString, Array, String]
        # @return [Array<String>]
        #
        def wrap_indent2(input)
          return WrappableString.wrap_lines(input, nil) unless @wrap_width
          WrappableString.wrap_lines(input, @wrap_width - @indent - @indent2)
        end

        ##
        # Wraps text using two column widths: first line at `@wrap_width - @indent`, continuation
        # lines at `@wrap_width - @indent - @indent2`. Returns unwrapped if no wrap width is set.
        #
        # @param input [WrappableString]
        # @return [Array<String>]
        #
        def wrap_indent_indent2(input)
          return WrappableString.wrap_lines(input, nil) unless @wrap_width
          WrappableString.wrap_lines(input, @wrap_width - @indent,
                                     @wrap_width - @indent - @indent2)
        end

        ##
        # Returns str with bold styling applied if styled output is enabled.
        #
        # @param str [String]
        # @return [String]
        #
        def bold(str)
          @lines.apply_styles(str, :bold)
        end

        ##
        # Returns str with underline styling applied if styled output is enabled.
        #
        # @param str [String]
        # @return [String]
        #
        def underline(str)
          @lines.apply_styles(str, :underline)
        end

        ##
        # Prepends `@indent` spaces to str.
        #
        # @param str [String]
        # @return [String]
        #
        def indent_str(str)
          "#{' ' * @indent}#{str}"
        end

        ##
        # Prepends `@indent + @indent2` spaces to str.
        #
        # @param str [String]
        # @return [String]
        #
        def indent2_str(str)
          "#{' ' * (@indent + @indent2)}#{str}"
        end
      end

      ##
      # @private
      #
      class ListStringAssembler
        ##
        # @private
        #
        def initialize(tool, subtools, recursive, search_term, separate_sources,
                       indent, wrap_width, styled)
          require "toys/utils/terminal"
          require "stringio"
          @tool = tool
          @subtools = subtools
          @recursive = recursive
          @search_term = search_term
          @separate_sources = separate_sources
          @indent = indent
          @wrap_width = wrap_width
          assemble(styled)
        end

        ##
        # @private
        #
        attr_reader :result

        private

        ##
        # Build the list string result, storing it in `@result`.
        #
        # @param styled [boolean] Whether to apply terminal styles.
        # @return [void]
        #
        def assemble(styled)
          @lines = Utils::Terminal.new(output: ::StringIO.new, styled: styled)
          add_header
          add_list
          @result = @lines.output.string
        end

        ##
        # Append the list header line (e.g. "List of tools under foo:") and,
        # if a search term is active, a blank line followed by a search
        # results notice.
        #
        # @return [void]
        #
        def add_header
          top_line = @recursive ? "Recursive list of tools" : "List of tools"
          @lines <<
            if @tool.root?
              "#{top_line}:"
            else
              "#{top_line} under #{bold(@tool.display_name)}:"
            end
          if @search_term
            @lines << ""
            @lines << "Showing search results for \"#{@search_term}\""
          end
        end

        ##
        # Append the full subtool listing, iterating over all source groups
        # and their subtool entries.
        #
        # @return [void]
        #
        def add_list
          @subtools.each do |source_name, subtool_list|
            @lines << ""
            if @separate_sources
              @lines << underline("From: #{source_name}")
              @lines << ""
            end
            subtool_list.each do |local_name, subtool|
              add_prefix_with_desc(bold(local_name), subtool.desc)
            end
          end
        end

        ##
        # Append a single subtool entry of the form "prefix - desc", with
        # word-wrapping and indentation applied to continuation lines when
        # the description is a {WrappableString}.
        #
        # @param prefix [String] The (possibly styled) tool name prefix.
        # @param desc [String, WrappableString] The tool description.
        # @return [void]
        #
        def add_prefix_with_desc(prefix, desc)
          if desc.empty?
            @lines << prefix
          elsif !desc.is_a?(WrappableString)
            @lines << "#{prefix} - #{desc}"
          else
            desc = wrap_indent(WrappableString.new(["#{prefix} -"] + desc.fragments))
            @lines << desc[0]
            desc[1..].each do |line|
              @lines << indent_str(line)
            end
          end
        end

        ##
        # Wrap a wrappable string using different widths for the first line
        # and continuation lines. If `@wrap_width` is nil, no wrapping is
        # applied.
        #
        # @param input [WrappableString] The string to wrap.
        # @return [Array<String>] The wrapped lines.
        #
        def wrap_indent(input)
          return WrappableString.wrap_lines(input, nil) unless @wrap_width
          WrappableString.wrap_lines(input, @wrap_width, @wrap_width - @indent)
        end

        ##
        # Apply bold styling to a string via the terminal.
        #
        # @param str [String] The string to style.
        # @return [String] The styled string.
        #
        def bold(str)
          @lines.apply_styles(str, :bold)
        end

        ##
        # Apply underline styling to a string via the terminal.
        #
        # @param str [String] The string to style.
        # @return [String] The styled string.
        #
        def underline(str)
          @lines.apply_styles(str, :underline)
        end

        ##
        # Prepend `@indent` spaces to a string for continuation-line
        # indentation.
        #
        # @param str [String] The string to indent.
        # @return [String] The indented string.
        #
        def indent_str(str)
          "#{' ' * @indent}#{str}"
        end
      end
    end
  end
end
