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
  module Utils
    ##
    # A helper class that generates usage documentation for a tool.
    #
    # This class generates full usage documentation, including description,
    # switches, and arguments. It is used by middleware that implements help
    # and related options.
    #
    class Usage
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
      # @return [Toys::Utils::Usage]
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
      # @return [Toys::Utils::Usage]
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
      # @param [String,nil] search An optional string to search for when
      #     listing subcommands. Defaults to `nil` which finds all subcommands.
      # @param [Integer] left_column_width Width of the first column. Default
      #     is {DEFAULT_LEFT_COLUMN_WIDTH}.
      # @param [Integer] indent Indent width. Default is {DEFAULT_INDENT}.
      #
      # @return [String] A usage string.
      #
      def short_string(recursive: false, search: nil,
                       left_column_width: nil, indent: nil, wrap_width: nil)
        left_column_width ||= DEFAULT_LEFT_COLUMN_WIDTH
        indent ||= DEFAULT_INDENT
        subtools = find_subtools(recursive, search)
        assembler = ShortHelpAssembler.new(@tool, @binary_name, subtools, search,
                                           indent, left_column_width, wrap_width)
        assembler.result
      end

      ##
      # Generate a long usage string.
      #
      # @param [Boolean] recursive If true, and the tool is a group tool,
      #     display all subcommands recursively. Defaults to false.
      # @param [String,nil] search An optional string to search for when
      #     listing subcommands. Defaults to `nil` which finds all subcommands.
      # @param [Boolean] show_path If true, shows the path to the config file
      #     containing the tool definition (if set). Defaults to false.
      # @param [Integer] indent Indent width. Default is {DEFAULT_INDENT}.
      # @param [Integer] indent2 Second indent width. Default is
      #     {DEFAULT_INDENT}.
      # @param [Integer,nil] wrap_width Wrap width of the column, or `nil` to
      #     disable wrap. Default is `nil`.
      #
      # @return [String] A usage string.
      #
      def long_string(recursive: false, search: nil, show_path: false,
                      indent: nil, indent2: nil, wrap_width: nil)
        indent ||= DEFAULT_INDENT
        indent2 ||= DEFAULT_INDENT
        subtools = find_subtools(recursive, search)
        assembler = LongHelpAssembler.new(@tool, @binary_name, subtools, search, show_path,
                                          indent, indent2, wrap_width)
        assembler.result
      end

      private

      def find_subtools(recursive, search)
        return [] if @tool.includes_executor?
        subtools = @loader.list_subtools(@tool.full_name, recursive: recursive)
        return subtools if search.nil? || search.empty?
        regex = Regexp.new("(^|\\s)#{Regexp.escape(search)}(\\s|$)", Regexp::IGNORECASE)
        subtools.find_all do |tool|
          regex =~ tool.display_name ||
            tool.desc.find { |d| regex =~ d.to_s } ||
            tool.long_desc.find { |d| regex =~ d.to_s }
        end
      end

      ## @private
      class ShortHelpAssembler
        def initialize(tool, binary_name, subtools, search_term,
                       indent, left_column_width, wrap_width)
          @tool = tool
          @binary_name = binary_name
          @subtools = subtools
          @search_term = search_term
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
          add_description_section
          add_flags_section
          if @tool.includes_executor?
            add_positional_arguments_section
          else
            add_subtool_list_section
          end
          @result = @lines.join("\n") + "\n"
        end

        def add_synopsis_section
          synopsis = @tool.includes_executor? ? tool_synopsis : group_synopsis
          @lines << "Usage: #{synopsis}"
        end

        def tool_synopsis
          synopsis = [@binary_name] + @tool.full_name
          synopsis << "[<options...>]" unless @tool.switch_definitions.empty?
          @tool.required_arg_definitions.each do |arg_info|
            synopsis << "<#{arg_info.canonical_name}>"
          end
          @tool.optional_arg_definitions.each do |arg_info|
            synopsis << "[<#{arg_info.canonical_name}>]"
          end
          if @tool.remaining_args_definition
            synopsis << "[<#{@tool.remaining_args_definition.canonical_name}...>]"
          end
          synopsis.join(" ")
        end

        def group_synopsis
          ([@binary_name] + @tool.full_name + ["<command>", "<command-arguments...>"]).join(" ")
        end

        def add_description_section
          desc = @tool.wrapped_desc(@wrap_width)
          unless desc.empty?
            @lines << ""
            @lines.concat(desc)
          end
        end

        def add_flags_section
          return if @tool.switch_definitions.empty?
          @lines << ""
          @lines << "Flags:"
          @tool.switch_definitions.each do |switch|
            add_flag(switch)
          end
        end

        def add_flag(switch)
          switches_str = (switch.single_switch_syntax.map(&:str_without_value) +
                          switch.double_switch_syntax.map(&:str_without_value)).join(", ")
          switches_str << switch.value_delim << switch.value_label if switch.value_label
          switches_str = "    #{switches_str}" if switch.single_switch_syntax.empty?
          add_right_column_desc(switches_str, switch.wrapped_desc(@right_column_wrap_width))
        end

        def add_positional_arguments_section
          args_to_display = @tool.required_arg_definitions + @tool.optional_arg_definitions
          args_to_display << @tool.remaining_args_definition if @tool.remaining_args_definition
          return if args_to_display.empty?
          @lines << ""
          @lines << "Positional arguments:"
          args_to_display.each do |arg_info|
            add_right_column_desc(arg_info.canonical_name,
                                  arg_info.wrapped_desc(@right_column_wrap_width))
          end
        end

        def add_subtool_list_section
          return if @subtools.empty?
          name_len = @tool.full_name.length
          @lines << ""
          @lines <<
            if @search_term
              "Tools with search term #{@search_term.inspect}:"
            else
              "Tools:"
            end
          @subtools.each do |subtool|
            tool_name = subtool.full_name.slice(name_len..-1).join(" ")
            desc =
              if subtool.is_a?(Alias)
                ["(Alias of #{subtool.display_target})"]
              else
                subtool.wrapped_desc(@right_column_wrap_width)
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

        def indent_str(str)
          "#{' ' * @indent}#{str}"
        end
      end

      ## @private
      class LongHelpAssembler
        def initialize(tool, binary_name, subtools, search_term, show_path,
                       indent, indent2, wrap_width)
          @tool = tool
          @binary_name = binary_name
          @subtools = subtools
          @search_term = search_term
          @show_path = show_path
          @indent = indent
          @indent2 = indent2
          @wrap_width = wrap_width
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
          if @tool.includes_executor?
            add_positional_arguments_section
          else
            add_subtool_list_section
          end
          add_source_section if @show_path
          @result = @lines.join("\n") + "\n"
        end

        def add_name_section
          @lines << "NAME"
          name_str = ([@binary_name] + @tool.full_name).join(" ")
          desc = prefix_with_desc(name_str, @tool)
          @lines << indent_str(desc[0])
          desc[1..-1].each do |line|
            @lines << indent2_str(line)
          end
        end

        def prefix_with_desc(prefix, object)
          return [prefix] if object.desc.empty?
          width1 = @wrap_width - prefix.size - @indent - 3
          if width1 <= 0
            ["#{name_str} -"] + object.wrapped_desc(@wrap_width - @indent - @indent2)
          else
            desc = object.wrapped_desc(width1, @wrap_width - @indent - @indent2)
            desc[0] = "#{prefix} - #{desc[0]}"
            desc
          end
        end

        def add_synopsis_section
          @lines << ""
          @lines << "SYNOPSIS"
          unless @tool.includes_executor?
            @lines << indent_str(group_synopsis)
          end
          @lines << indent_str(tool_synopsis)
        end

        def tool_synopsis
          # TODO: Expand this
          synopsis = [@binary_name] + @tool.full_name
          synopsis << "[<options...>]" unless @tool.switch_definitions.empty?
          @tool.required_arg_definitions.each do |arg_info|
            synopsis << "<#{arg_info.canonical_name}>"
          end
          @tool.optional_arg_definitions.each do |arg_info|
            synopsis << "[<#{arg_info.canonical_name}>]"
          end
          if @tool.remaining_args_definition
            synopsis << "[<#{@tool.remaining_args_definition.canonical_name}...>]"
          end
          synopsis.join(" ")
        end

        def group_synopsis
          ([@binary_name] + @tool.full_name + ["<command>", "<command-arguments...>"]).join(" ")
        end

        def add_source_section
          return unless @tool.definition_path
          @lines << ""
          @lines << "SOURCE"
          @lines << indent_str("Defined in #{@tool.definition_path}")
        end

        def add_description_section
          desc = @tool.wrapped_long_desc(@wrap_width - @indent)
          return if desc.empty?
          @lines << ""
          @lines << "DESCRIPTION"
          desc.each do |line|
            @lines << indent_str(line)
          end
        end

        def add_flags_section
          return if @tool.switch_definitions.empty?
          @lines << ""
          @lines << "FLAGS"
          precede_with_blank = false
          @tool.switch_definitions.each do |switch|
            add_flag(switch, precede_with_blank)
            precede_with_blank = true
          end
        end

        def add_flag(switch, precede_with_blank)
          switches_str = (switch.single_switch_syntax.map(&:str_without_value) +
                          switch.double_switch_syntax.map(&:str_without_value)).join(", ")
          switches_str << switch.value_delim << switch.value_label if switch.value_label
          add_indented_section(switches_str, switch, precede_with_blank)
        end

        def add_positional_arguments_section
          args_to_display = @tool.required_arg_definitions + @tool.optional_arg_definitions
          args_to_display << @tool.remaining_args_definition if @tool.remaining_args_definition
          return if args_to_display.empty?
          @lines << ""
          @lines << "POSITIONAL ARGUMENTS"
          precede_with_blank = false
          args_to_display.each do |arg_info|
            add_indented_section(arg_info.canonical_name, arg_info, precede_with_blank)
            precede_with_blank = true
          end
        end

        def add_subtool_list_section
          return if @subtools.empty?
          @lines << ""
          @lines << (@search_term ? "TOOLS with search term #{@search_term.inspect}:" : "TOOLS:")
          name_len = @tool.full_name.length
          precede_with_blank = false
          @subtools.each do |subtool|
            tool_name = subtool.full_name.slice(name_len..-1).join(" ")
            desc =
              if subtool.is_a?(Alias)
                ["(Alias of #{subtool.display_target})"]
              else
                subtool.wrapped_desc(@wrap_width - @indent - @indent2)
              end
            add_indented_section(tool_name, desc, precede_with_blank)
            precede_with_blank = true
          end
        end

        def add_indented_section(header, info, precede_with_blank)
          @lines << "" if precede_with_blank
          @lines << indent_str(header)
          desc = info
          unless desc.is_a?(::Array)
            desc = info.wrapped_long_desc(@wrap_width - @indent - @indent2)
            desc = info.wrapped_desc(@wrap_width - @indent - @indent2) if desc.empty?
          end
          desc.each do |line|
            @lines << indent2_str(line)
          end
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
