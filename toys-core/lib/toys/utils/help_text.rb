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
        new(context[Context::Key::TOOL], context[Context::Key::LOADER],
            context[Context::Key::EXECUTABLE_NAME])
      end

      ##
      # Create a usage helper.
      #
      # @param tool [Toys::Tool] The tool to document.
      # @param loader [Toys::Loader] A loader that can provide subcommands.
      # @param executable_name [String] The name of the executable.
      #     e.g. `"toys"`.
      #
      # @return [Toys::Utils::HelpText]
      #
      def initialize(tool, loader, executable_name)
        @tool = tool
        @loader = loader
        @executable_name = executable_name
      end

      ##
      # The Tool being documented.
      # @return [Toys::Tool]
      #
      attr_reader :tool

      ##
      # Generate a short usage string.
      #
      # @param recursive [Boolean] If true, and the tool is a namespace,
      #     display all subtools recursively. Defaults to false.
      # @param include_hidden [Boolean] Include hidden subtools (i.e. whose
      #     names begin with underscore.) Default is false.
      # @param left_column_width [Integer] Width of the first column. Default
      #     is {DEFAULT_LEFT_COLUMN_WIDTH}.
      # @param indent [Integer] Indent width. Default is {DEFAULT_INDENT}.
      # @param wrap_width [Integer,nil] Overall width to wrap to. Default is
      #     `nil` indicating no wrapping.
      #
      # @return [String] A usage string.
      #
      def usage_string(recursive: false, include_hidden: false,
                       left_column_width: nil, indent: nil, wrap_width: nil)
        left_column_width ||= DEFAULT_LEFT_COLUMN_WIDTH
        indent ||= DEFAULT_INDENT
        subtools = find_subtools(recursive, nil, include_hidden)
        assembler = UsageStringAssembler.new(@tool, @executable_name, subtools,
                                             indent, left_column_width, wrap_width)
        assembler.result
      end

      ##
      # Generate a long help string.
      #
      # @param recursive [Boolean] If true, and the tool is a namespace,
      #     display all subtools recursively. Defaults to false.
      # @param search [String,nil] An optional string to search for when
      #     listing subtools. Defaults to `nil` which finds all subtools.
      # @param include_hidden [Boolean] Include hidden subtools (i.e. whose
      #     names begin with underscore.) Default is false.
      # @param show_source_path [Boolean] If true, shows the source path
      #     section. Defaults to false.
      # @param indent [Integer] Indent width. Default is {DEFAULT_INDENT}.
      # @param indent2 [Integer] Second indent width. Default is
      #     {DEFAULT_INDENT}.
      # @param wrap_width [Integer,nil] Wrap width of the column, or `nil` to
      #     disable wrap. Default is `nil`.
      # @param styled [Boolean] Output ansi styles. Default is `true`.
      #
      # @return [String] A usage string.
      #
      def help_string(recursive: false, search: nil, include_hidden: false,
                      show_source_path: false,
                      indent: nil, indent2: nil, wrap_width: nil, styled: true)
        indent ||= DEFAULT_INDENT
        indent2 ||= DEFAULT_INDENT
        subtools = find_subtools(recursive, search, include_hidden)
        assembler = HelpStringAssembler.new(@tool, @executable_name, subtools, search,
                                            show_source_path, indent, indent2, wrap_width, styled)
        assembler.result
      end

      ##
      # Generate a subtool list string.
      #
      # @param recursive [Boolean] If true, and the tool is a namespace,
      #     display all subtools recursively. Defaults to false.
      # @param search [String,nil] An optional string to search for when
      #     listing subtools. Defaults to `nil` which finds all subtools.
      # @param include_hidden [Boolean] Include hidden subtools (i.e. whose
      #     names begin with underscore.) Default is false.
      # @param indent [Integer] Indent width. Default is {DEFAULT_INDENT}.
      # @param wrap_width [Integer,nil] Wrap width of the column, or `nil` to
      #     disable wrap. Default is `nil`.
      # @param styled [Boolean] Output ansi styles. Default is `true`.
      #
      # @return [String] A usage string.
      #
      def list_string(recursive: false, search: nil, include_hidden: false,
                      indent: nil, wrap_width: nil, styled: true)
        indent ||= DEFAULT_INDENT
        subtools = find_subtools(recursive, search, include_hidden)
        assembler = ListStringAssembler.new(@tool, subtools, recursive, search,
                                            indent, wrap_width, styled)
        assembler.result
      end

      private

      def find_subtools(recursive, search, include_hidden)
        subtools = @loader.list_subtools(@tool.full_name,
                                         recursive: recursive, include_hidden: include_hidden)
        return subtools if search.nil? || search.empty?
        regex = ::Regexp.new(search, ::Regexp::IGNORECASE)
        subtools.find_all do |tool|
          regex =~ tool.display_name || regex =~ tool.desc.to_s
        end
      end

      ## @private
      class UsageStringAssembler
        def initialize(tool, executable_name, subtools,
                       indent, left_column_width, wrap_width)
          @tool = tool
          @executable_name = executable_name
          @subtools = subtools
          @indent = indent
          @left_column_width = left_column_width
          @wrap_width = wrap_width
          @right_column_wrap_width = wrap_width ? wrap_width - left_column_width - indent - 1 : nil
          @lines = []
          assemble
        end

        attr_reader :result

        private

        def assemble
          add_synopsis_section
          add_flag_group_sections
          add_positional_arguments_section if @tool.runnable?
          add_subtool_list_section
          @result = @lines.join("\n") + "\n"
        end

        def add_synopsis_section
          synopses = []
          synopses << namespace_synopsis if !@subtools.empty? && !@tool.runnable?
          synopses << tool_synopsis
          synopses << namespace_synopsis if !@subtools.empty? && @tool.runnable?
          first = true
          synopses.each do |synopsis|
            @lines << (first ? "Usage:  #{synopsis}" : "        #{synopsis}")
            first = false
          end
        end

        def tool_synopsis
          synopsis = [@executable_name] + @tool.full_name
          synopsis << "[FLAGS...]" unless @tool.flags.empty?
          @tool.positional_args.each do |arg_info|
            synopsis << arg_name(arg_info)
          end
          synopsis.join(" ")
        end

        def namespace_synopsis
          ([@executable_name] + @tool.full_name + ["TOOL", "[ARGUMENTS...]"]).join(" ")
        end

        def add_flag_group_sections
          @tool.flag_groups.each do |group|
            next if group.empty?
            @lines << ""
            desc_str = group.desc.to_s
            desc_str = "Flags" if desc_str.empty?
            @lines << desc_str + ":"
            group.flags.each do |flag|
              add_flag(flag)
            end
          end
        end

        def add_flag(flag)
          flags = flag.short_flag_syntax + flag.long_flag_syntax
          last_index = flags.size - 1
          flags_str = flags.each_with_index.map do |fs, i|
            i == last_index ? fs.canonical_str : fs.str_without_value
          end.join(", ")
          flags_str = "    #{flags_str}" if flag.short_flag_syntax.empty?
          add_right_column_desc(flags_str, wrap_desc(flag.desc))
        end

        def add_positional_arguments_section
          args_to_display = @tool.positional_args
          return if args_to_display.empty?
          @lines << ""
          @lines << "Positional arguments:"
          args_to_display.each do |arg_info|
            add_right_column_desc(arg_name(arg_info), wrap_desc(arg_info.desc))
          end
        end

        def add_subtool_list_section
          return if @subtools.empty?
          name_len = @tool.full_name.length
          @lines << ""
          @lines << "Tools:"
          @subtools.each do |subtool|
            tool_name = subtool.full_name.slice(name_len..-1).join(" ")
            desc =
              if subtool.is_a?(Alias)
                ["(Alias of #{subtool.display_target})"]
              else
                wrap_desc(subtool.desc)
              end
            add_right_column_desc(tool_name, desc)
          end
        end

        def add_right_column_desc(initial, desc)
          initial = indent_str(initial.ljust(@left_column_width))
          remaining_doc = desc
          if initial.size <= @indent + @left_column_width
            @lines << "#{initial} #{desc.first}"
            remaining_doc = desc[1..-1] || []
          else
            @lines << initial
          end
          remaining_doc.each do |d|
            @lines << "#{' ' * (@indent + @left_column_width)} #{d}"
          end
        end

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

        def wrap_desc(desc)
          WrappableString.wrap_lines(desc, @right_column_wrap_width)
        end

        def indent_str(str)
          "#{' ' * @indent}#{str}"
        end
      end

      ## @private
      class HelpStringAssembler
        def initialize(tool, executable_name, subtools, search_term, show_source_path,
                       indent, indent2, wrap_width, styled)
          require "toys/utils/terminal"
          @tool = tool
          @executable_name = executable_name
          @subtools = subtools
          @search_term = search_term
          @show_source_path = show_source_path
          @indent = indent
          @indent2 = indent2
          @wrap_width = wrap_width
          @lines = Utils::Terminal.new(output: ::StringIO.new, styled: styled)
          assemble
        end

        attr_reader :result

        private

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

        def add_name_section
          @lines << bold("NAME")
          name_str = ([@executable_name] + @tool.full_name).join(" ")
          add_prefix_with_desc(name_str, @tool.desc)
        end

        def add_prefix_with_desc(prefix, desc)
          if desc.empty?
            @lines << indent_str(prefix)
          elsif !desc.is_a?(WrappableString)
            @lines << indent_str("#{prefix} - #{desc}")
          else
            desc = wrap_indent_indent2(WrappableString.new(["#{prefix} -"] + desc.fragments))
            @lines << indent_str(desc[0])
            desc[1..-1].each do |line|
              @lines << indent2_str(line)
            end
          end
        end

        def add_synopsis_section
          @lines << ""
          @lines << bold("SYNOPSIS")
          add_synopsis_clause(namespace_synopsis) if !@subtools.empty? && !@tool.runnable?
          add_synopsis_clause(tool_synopsis)
          add_synopsis_clause(namespace_synopsis) if !@subtools.empty? && @tool.runnable?
        end

        def add_synopsis_clause(synopsis)
          first = true
          synopsis.each do |line|
            @lines << (first ? indent_str(line) : indent2_str(line))
            first = false
          end
        end

        def tool_synopsis
          synopsis = [full_executable_name]
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

        def add_ordinary_group_to_synopsis(flag_group, synopsis)
          flag_group.flags.each do |flag|
            synopsis << "[#{flag_spec_string(flag, true)}]"
          end
        end

        def add_required_group_to_synopsis(flag_group, synopsis)
          flag_group.flags.each do |flag|
            synopsis << "(#{flag_spec_string(flag, true)})"
          end
        end

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

        def add_at_least_one_group_to_synopsis(flag_group, synopsis)
          return if flag_group.empty?
          synopsis << "("
          flag_group.flags.each do |flag|
            synopsis << "[#{flag_spec_string(flag, true)}]"
          end
          synopsis << ")"
        end

        def namespace_synopsis
          synopsis = [full_executable_name, underline("TOOL"), "[#{underline('ARGUMENTS')}...]"]
          wrap_indent_indent2(WrappableString.new(synopsis))
        end

        def full_executable_name
          bold(([@executable_name] + @tool.full_name).join(" "))
        end

        def add_source_section
          return unless @show_source_path && @tool.source_info&.source_name
          @lines << ""
          @lines << bold("SOURCE")
          @lines << indent_str("Defined in #{@tool.source_info.source_name}")
        end

        def add_description_section
          desc = wrap_indent(@tool.long_desc)
          return if desc.empty?
          @lines << ""
          @lines << bold("DESCRIPTION")
          desc.each do |line|
            @lines << indent_str(line)
          end
        end

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

        def add_subtool_list_section
          return if @subtools.empty?
          @lines << ""
          @lines << bold("TOOLS")
          if @search_term
            @lines << indent_str("Showing search results for \"#{@search_term}\"")
            @lines << ""
          end
          name_len = @tool.full_name.length
          @subtools.each do |subtool|
            tool_name = subtool.full_name.slice(name_len..-1).join(" ")
            desc =
              if subtool.is_a?(Alias)
                "(Alias of #{subtool.display_target})"
              else
                subtool.desc
              end
            add_prefix_with_desc(bold(tool_name), desc)
          end
        end

        def add_indented_section(header, info, precede_with_blank)
          @lines << "" if precede_with_blank
          @lines << indent_str(header)
          desc = info
          unless desc.is_a?(::Array)
            desc = wrap_indent2(info.long_desc)
            desc = wrap_indent2(info.desc) if desc.empty?
          end
          desc.each do |line|
            @lines << indent2_str(line)
          end
        end

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

        def wrap_indent(input)
          return WrappableString.wrap_lines(input, nil) unless @wrap_width
          WrappableString.wrap_lines(input, @wrap_width - @indent)
        end

        def wrap_indent2(input)
          return WrappableString.wrap_lines(input, nil) unless @wrap_width
          WrappableString.wrap_lines(input, @wrap_width - @indent - @indent2)
        end

        def wrap_indent_indent2(input)
          return WrappableString.wrap_lines(input, nil) unless @wrap_width
          WrappableString.wrap_lines(input, @wrap_width - @indent,
                                     @wrap_width - @indent - @indent2)
        end

        def bold(str)
          @lines.apply_styles(str, :bold)
        end

        def underline(str)
          @lines.apply_styles(str, :underline)
        end

        def indent_str(str)
          "#{' ' * @indent}#{str}"
        end

        def indent2_str(str)
          "#{' ' * (@indent + @indent2)}#{str}"
        end
      end

      ## @private
      class ListStringAssembler
        def initialize(tool, subtools, recursive, search_term, indent, wrap_width, styled)
          require "toys/utils/terminal"
          @tool = tool
          @subtools = subtools
          @recursive = recursive
          @search_term = search_term
          @indent = indent
          @wrap_width = wrap_width
          assemble(styled)
        end

        attr_reader :result

        private

        def assemble(styled)
          @lines = Utils::Terminal.new(output: ::StringIO.new, styled: styled)
          add_header
          add_list
          @result = @lines.output.string
        end

        def add_header
          top_line = @recursive ? "Recursive list of tools" : "List of tools"
          @lines <<
            if @tool.root?
              "#{top_line}:"
            else
              "#{top_line} under #{bold(@tool.display_name)}:"
            end
          @lines << ""
          if @search_term
            @lines << "Showing search results for \"#{@search_term}\""
            @lines << ""
          end
        end

        def add_list
          name_len = @tool.full_name.length
          @subtools.each do |subtool|
            tool_name = subtool.full_name.slice(name_len..-1).join(" ")
            desc =
              if subtool.is_a?(Alias)
                "(Alias of #{subtool.display_target})"
              else
                subtool.desc
              end
            add_prefix_with_desc(bold(tool_name), desc)
          end
        end

        def add_prefix_with_desc(prefix, desc)
          if desc.empty?
            @lines << prefix
          elsif !desc.is_a?(WrappableString)
            @lines << "#{prefix} - #{desc}"
          else
            desc = wrap_indent(WrappableString.new(["#{prefix} -"] + desc.fragments))
            @lines << desc[0]
            desc[1..-1].each do |line|
              @lines << indent_str(line)
            end
          end
        end

        def wrap_indent(input)
          return WrappableString.wrap_lines(input, nil) unless @wrap_width
          WrappableString.wrap_lines(input, @wrap_width, @wrap_width - @indent)
        end

        def bold(str)
          @lines.apply_styles(str, :bold)
        end

        def indent_str(str)
          "#{' ' * @indent}#{str}"
        end
      end
    end
  end
end
