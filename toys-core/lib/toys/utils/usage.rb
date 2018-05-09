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
      # Generate a usage string.
      #
      # @param [Boolean] recursive If true, and the tool is a group tool,
      #     display all subcommands recursively. Defaults to false.
      # @param [String,nil] search An optional string to search for when
      #     listing subcommands. Defaults to `nil` which finds all subcommands.
      # @param [Boolean] show_path If true, shows the path to the config file
      #     containing the tool definition (if set). Defaults to false.
      # @param [Integer] left_column_width Width of the first column. Default
      #     is {DEFAULT_LEFT_COLUMN_WIDTH}.
      # @param [Integer] indent Indent width. Default is {DEFAULT_INDENT}.
      #
      # @return [String] A usage string.
      #
      def string(recursive: false, search: nil, show_path: false,
                 left_column_width: nil, indent: nil,
                 wrap_width: nil, right_column_wrap_width: nil)
        left_column_width ||= DEFAULT_LEFT_COLUMN_WIDTH
        indent ||= DEFAULT_INDENT
        right_column_wrap_width ||= wrap_width - left_column_width - indent - 1 if wrap_width
        lines = []
        lines << (@tool.includes_executor? ? tool_banner : group_banner)
        add_description(lines, wrap_width, show_path)
        add_switches(lines, indent, left_column_width, right_column_wrap_width)
        if @tool.includes_executor?
          add_positional_arguments(lines, indent, left_column_width, right_column_wrap_width)
        else
          add_command_list(lines, recursive, search, indent,
                           left_column_width, right_column_wrap_width)
        end
        lines.join("\n") + "\n"
      end

      private

      #
      # Returns the banner string for a normal tool
      #
      def tool_banner
        banner = ["Usage:", @binary_name] + @tool.full_name
        banner << "[<options...>]" unless @tool.switch_definitions.empty?
        @tool.required_arg_definitions.each do |arg_info|
          banner << "<#{arg_info.canonical_name}>"
        end
        @tool.optional_arg_definitions.each do |arg_info|
          banner << "[<#{arg_info.canonical_name}>]"
        end
        if @tool.remaining_args_definition
          banner << "[<#{@tool.remaining_args_definition.canonical_name}...>]"
        end
        banner.join(" ")
      end

      #
      # Returns the banner string for a group
      #
      def group_banner
        banner = ["Usage:", @binary_name] +
                 @tool.full_name +
                 ["<command>", "<command-arguments...>"]
        banner.join(" ")
      end

      def add_description(lines, wrap_width, show_path)
        long_desc = @tool.effective_long_desc(wrap_width: wrap_width)
        unless long_desc.empty?
          lines << ""
          lines.concat(long_desc)
        end
        if show_path && @tool.definition_path
          lines << ""
          lines << "Defined in #{@tool.definition_path}"
        end
      end

      #
      # Add switches from the tool to the given optionparser. Causes the
      # optparser to generate documentation for those switches.
      #
      def add_switches(lines, indent, left_column_width, right_column_wrap_width)
        return if @tool.switch_definitions.empty?
        lines << ""
        lines << "Options:"
        @tool.switch_definitions.each do |switch|
          add_switch(lines, switch, indent, left_column_width, right_column_wrap_width)
        end
      end

      #
      # Add a single switch
      #
      def add_switch(lines, switch, indent, left_column_width, right_column_wrap_width)
        switches_str = (switch.single_switch_syntax.map(&:str_without_value) +
                        switch.double_switch_syntax.map(&:str_without_value)).join(", ")
        switches_str << switch.value_delim << switch.value_label if switch.value_label
        switches_str = "    #{switches_str}" if switch.single_switch_syntax.empty?
        add_doc(lines, switches_str, switch.wrapped_docs(right_column_wrap_width),
                indent, left_column_width)
      end

      #
      # Add documentation for the tool's positional arguments, to the given
      # option parser.
      #
      def add_positional_arguments(lines, indent, left_column_width, right_column_wrap_width)
        args_to_display = @tool.required_arg_definitions + @tool.optional_arg_definitions
        args_to_display << @tool.remaining_args_definition if @tool.remaining_args_definition
        return if args_to_display.empty?
        lines << ""
        lines << "Positional arguments:"
        args_to_display.each do |arg_info|
          add_doc(lines, arg_info.canonical_name, arg_info.wrapped_docs(right_column_wrap_width),
                  indent, left_column_width)
        end
      end

      #
      # Add documentation for the tool's subcommands, to the given option
      # parser.
      #
      def add_command_list(lines, recursive, search, indent,
                           left_column_width, right_column_wrap_width)
        name_len = @tool.full_name.length
        subtools = find_commands(recursive, search)
        return if subtools.empty?
        lines << ""
        lines << (search ? "Commands with search term #{search.inspect}:" : "Commands:")
        subtools.each do |subtool|
          tool_name = subtool.full_name.slice(name_len..-1).join(" ")
          doc =
            if subtool.is_a?(Alias)
              ["(Alias of #{subtool.display_target})"]
            else
              subtool.effective_desc(wrap_width: right_column_wrap_width)
            end
          add_doc(lines, tool_name, doc, indent, left_column_width)
        end
      end

      #
      # Add a line with possible documentation strings.
      #
      def add_doc(lines, initial, doc, indent, left_column_width)
        initial = "#{' ' * indent}#{initial.ljust(left_column_width)}"
        remaining_doc =
          if initial.size <= indent + left_column_width
            lines << "#{initial} #{doc.first}"
            doc[1..-1] || []
          else
            lines << initial
            doc
          end
        remaining_doc.each do |d|
          lines << "#{' ' * (indent + left_column_width)} #{d}"
        end
      end

      #
      # Find subcommands of the current tool
      #
      def find_commands(recursive, search)
        subtools = @loader.list_subtools(@tool.full_name, recursive: recursive)
        return subtools if search.nil? || search.empty?
        regex = Regexp.new("(^|\\s)#{Regexp.escape(search)}(\\s|$)", Regexp::IGNORECASE)
        subtools.find_all do |tool|
          regex =~ tool.display_name ||
            tool.effective_desc.find { |d| regex =~ d } ||
            tool.effective_long_desc.find { |d| regex =~ d }
        end
      end
    end
  end
end
