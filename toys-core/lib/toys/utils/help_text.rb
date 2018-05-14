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

module Toys
  module Utils
    ##
    # A helper class that generates usage documentation for a tool.
    #
    # This class generates full usage documentation, including description,
    # flags, and arguments. It is used by middleware that implements help
    # and related options.
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
      # @param [Toys::Context] context The current execution context.
      # @return [Toys::Utils::HelpText]
      #
      def self.from_context(context)
        new(context[Context::TOOL], context[Context::LOADER], context[Context::BINARY_NAME])
      end

      ##
      # Create a usage helper.
      #
      # @param [Toys::Tool] tool The tool for which to generate documentation.
      # @param [Toys::Loader] loader A loader that can provide subcommands.
      # @param [String] binary_name The name of the binary. e.g. `"toys"`.
      #
      # @return [Toys::Utils::HelpText]
      #
      def initialize(tool, loader, binary_name)
        @tool = tool
        @loader = loader
        @binary_name = binary_name
      end

      ##
      # Generate a short usage string.
      #
      # @param [Boolean] recursive If true, and the tool is a group tool,
      #     display all subcommands recursively. Defaults to false.
      # @param [Integer] left_column_width Width of the first column. Default
      #     is {DEFAULT_LEFT_COLUMN_WIDTH}.
      # @param [Integer] indent Indent width. Default is {DEFAULT_INDENT}.
      # @param [Integer,nil] wrap_width Overall width to wrap to. Default is
      #     `nil` indicating no wrapping.
      #
      # @return [String] A usage string.
      #
      def usage_string(recursive: false, left_column_width: nil, indent: nil, wrap_width: nil)
        left_column_width ||= DEFAULT_LEFT_COLUMN_WIDTH
        indent ||= DEFAULT_INDENT
        subtools = find_subtools(recursive, nil)
        assembler = UsageStringAssembler.new(@tool, @binary_name, subtools,
                                             indent, left_column_width, wrap_width)
        assembler.result
      end

      ##
      # Generate a long help string.
      #
      # @param [Boolean] recursive If true, and the tool is a group tool,
      #     display all subcommands recursively. Defaults to false.
      # @param [String,nil] search An optional string to search for when
      #     listing subcommands. Defaults to `nil` which finds all subcommands.
      # @param [Integer] indent Indent width. Default is {DEFAULT_INDENT}.
      # @param [Integer] indent2 Second indent width. Default is
      #     {DEFAULT_INDENT}.
      # @param [Integer,nil] wrap_width Wrap width of the column, or `nil` to
      #     disable wrap. Default is `nil`.
      # @param [Boolean] styled Output ansi styles. Default is `true`.
      #
      # @return [String] A usage string.
      #
      def help_string(recursive: false, search: nil,
                      indent: nil, indent2: nil, wrap_width: nil, styled: true)
        indent ||= DEFAULT_INDENT
        indent2 ||= DEFAULT_INDENT
        subtools = find_subtools(recursive, search)
        assembler = HelpStringAssembler.new(@tool, @binary_name, subtools, search,
                                            indent, indent2, wrap_width, styled)
        assembler.result
      end

      private

      def find_subtools(recursive, search)
        subtools = @loader.list_subtools(@tool.full_name, recursive: recursive)
        return subtools if search.nil? || search.empty?
        regex = Regexp.new(search, Regexp::IGNORECASE)
        subtools.find_all do |tool|
          regex =~ tool.display_name || regex =~ tool.desc.to_s
        end
      end

      ## @private
      class UsageStringAssembler
        def initialize(tool, binary_name, subtools,
                       indent, left_column_width, wrap_width)
          @tool = tool
          @binary_name = binary_name
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
          add_flags_section
          add_positional_arguments_section if @tool.includes_executor?
          add_subtool_list_section
          @result = @lines.join("\n") + "\n"
        end

        def add_synopsis_section
          synopses = []
          synopses << group_synopsis if !@subtools.empty? && !@tool.includes_executor?
          synopses << tool_synopsis
          synopses << group_synopsis if !@subtools.empty? && @tool.includes_executor?
          first = true
          synopses.each do |synopsis|
            @lines << (first ? "Usage:  #{synopsis}" : "        #{synopsis}")
            first = false
          end
        end

        def tool_synopsis
          synopsis = [@binary_name] + @tool.full_name
          synopsis << "[FLAGS...]" unless @tool.flag_definitions.empty?
          @tool.arg_definitions.each do |arg_info|
            synopsis << arg_name(arg_info)
          end
          synopsis.join(" ")
        end

        def group_synopsis
          ([@binary_name] + @tool.full_name + ["TOOL", "[ARGUMENTS...]"]).join(" ")
        end

        def add_flags_section
          return if @tool.flag_definitions.empty?
          @lines << ""
          @lines << "Flags:"
          @tool.flag_definitions.each do |flag|
            add_flag(flag)
          end
        end

        def add_flag(flag)
          flags_str = (flag.single_flag_syntax + flag.double_flag_syntax)
                      .map(&:str_without_value).join(", ")
          flags_str << flag.value_delim << flag.value_label if flag.value_label
          flags_str = "    #{flags_str}" if flag.single_flag_syntax.empty?
          add_right_column_desc(flags_str, wrap_desc(flag.desc))
        end

        def add_positional_arguments_section
          args_to_display = @tool.arg_definitions
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
          Utils::WrappableString.wrap_lines(desc, @right_column_wrap_width)
        end

        def indent_str(str)
          "#{' ' * @indent}#{str}"
        end
      end

      ## @private
      class HelpStringAssembler
        def initialize(tool, binary_name, subtools, search_term,
                       indent, indent2, wrap_width, styled)
          @tool = tool
          @binary_name = binary_name
          @subtools = subtools
          @search_term = search_term
          @indent = indent
          @indent2 = indent2
          @wrap_width = wrap_width
          @styled = styled
          @lines = []
          assemble
        end

        attr_reader :result

        private

        def assemble
          add_name_section
          add_synopsis_section
          add_description_section
          add_flags_section
          add_positional_arguments_section if @tool.includes_executor?
          add_subtool_list_section
          add_source_section
          @result = @lines.join("\n") + "\n"
        end

        def add_name_section
          @lines << bold("NAME")
          name_str = ([@binary_name] + @tool.full_name).join(" ")
          add_prefix_with_desc(name_str, @tool.desc)
        end

        def add_prefix_with_desc(prefix, desc)
          if desc.empty?
            @lines << indent_str(prefix)
          elsif !desc.is_a?(Utils::WrappableString)
            @lines << indent_str("#{prefix} - #{desc}")
          else
            desc = wrap_indent_indent2(Utils::WrappableString.new(["#{prefix} -"] + desc.fragments))
            @lines << indent_str(desc[0])
            desc[1..-1].each do |line|
              @lines << indent2_str(line)
            end
          end
        end

        def add_synopsis_section
          @lines << ""
          @lines << bold("SYNOPSIS")
          if !@subtools.empty? && !@tool.includes_executor?
            add_synopsis_clause(group_synopsis)
          end
          add_synopsis_clause(tool_synopsis)
          if !@subtools.empty? && @tool.includes_executor?
            add_synopsis_clause(group_synopsis)
          end
        end

        def add_synopsis_clause(synopsis)
          first = true
          synopsis.each do |line|
            @lines << (first ? indent_str(line) : indent2_str(line))
            first = false
          end
        end

        def tool_synopsis
          synopsis = [full_binary_name]
          @tool.flag_definitions.each do |flag_def|
            synopsis << "[#{flag_spec_string(flag_def)}]"
          end
          @tool.arg_definitions.each do |arg_info|
            synopsis << arg_name(arg_info)
          end
          wrap_indent_indent2(Utils::WrappableString.new(synopsis))
        end

        def group_synopsis
          synopsis = [full_binary_name, underline("TOOL"), "[#{underline('ARGUMENTS')}...]"]
          wrap_indent_indent2(Utils::WrappableString.new(synopsis))
        end

        def full_binary_name
          bold(([@binary_name] + @tool.full_name).join(" "))
        end

        def add_source_section
          return unless @tool.definition_path
          @lines << ""
          @lines << bold("SOURCE")
          @lines << indent_str("Defined in #{@tool.definition_path}")
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

        def add_flags_section
          return if @tool.flag_definitions.empty?
          @lines << ""
          @lines << bold("FLAGS")
          precede_with_blank = false
          @tool.flag_definitions.each do |flag|
            add_indented_section(flag_spec_string(flag), flag, precede_with_blank)
            precede_with_blank = true
          end
        end

        def flag_spec_string(flag)
          single_flags = flag.single_flag_syntax.map do |fs|
            str = bold(fs.str_without_value)
            flag.value_label ? "#{str} #{underline(flag.value_label)}" : str
          end
          double_flags = flag.double_flag_syntax.map do |fs|
            str = bold(fs.str_without_value)
            flag.value_label ? "#{str}#{flag.value_delim}#{underline(flag.value_label)}" : str
          end
          (single_flags + double_flags).join(", ")
        end

        def add_positional_arguments_section
          args_to_display = @tool.arg_definitions
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
            desc = subtool.is_a?(Alias) ? ["(Alias of #{subtool.display_target})"] : subtool.desc
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
          return Utils::WrappableString.wrap_lines(input, nil) unless @wrap_width
          Utils::WrappableString.wrap_lines(input, @wrap_width - @indent)
        end

        def wrap_indent2(input)
          return Utils::WrappableString.wrap_lines(input, nil) unless @wrap_width
          Utils::WrappableString.wrap_lines(input, @wrap_width - @indent - @indent2)
        end

        def wrap_indent_indent2(input)
          return Utils::WrappableString.wrap_lines(input, nil) unless @wrap_width
          Utils::WrappableString.wrap_lines(input, @wrap_width - @indent,
                                            @wrap_width - @indent - @indent2)
        end

        def bold(str)
          @styled ? ::HighLine.color(str, :bold) : str
        end

        def underline(str)
          @styled ? ::HighLine.color(str, :underline) : str
        end

        def indent_str(str)
          "#{' ' * @indent}#{str}"
        end

        def indent2_str(str)
          "#{' ' * (@indent + @indent2)}#{str}"
        end
      end
    end
  end
end
