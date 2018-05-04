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
      # Create a usage helper given an execution context.
      #
      # @param [Toys::Context] context The current execution context.
      # @return [Toys::Utils::Usage]
      #
      def self.from_context(context)
        new(context[Context::TOOL], context[Context::BINARY_NAME], context[Context::LOADER])
      end

      ##
      # Create a usage helper.
      #
      # @param [Toys::Tool] tool The tool for which to generate documentation.
      # @param [String] binary_name The name of the binary. e.g. `"toys"`.
      # @param [Toys::Loader] loader A loader that can provide subcommands.
      #
      # @return [Toys::Utils::Usage]
      #
      def initialize(tool, binary_name, loader)
        @tool = tool
        @binary_name = binary_name
        @loader = loader
      end

      ##
      # Generate a usage string.
      #
      # @param [Boolean] recursive If true, and the tool is a group tool,
      #     display all subcommands recursively. Defaults to false.
      # @return [String] A usage string.
      #
      def string(recursive: false)
        optparse = ::OptionParser.new
        optparse.banner = @tool.includes_executor? ? tool_banner : group_banner
        unless @tool.effective_long_desc.empty?
          optparse.separator("")
          optparse.separator(@tool.effective_long_desc)
        end
        add_switches(optparse)
        if @tool.includes_executor?
          add_positional_arguments(optparse)
        elsif !@tool.alias?
          add_command_list(optparse, recursive)
        end
        optparse.to_s
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
        (["Usage:", @binary_name] + @tool.full_name + ["<command>", "[<options...>]"]).join(" ")
      end

      #
      # Add switches from the tool to the given optionparser. Causes the
      # optparser to generate documentation for those switches.
      #
      def add_switches(optparse)
        return if @tool.switch_definitions.empty?
        optparse.separator("")
        optparse.separator("Options:")
        @tool.switch_definitions.each do |switch|
          optparse.on(*switch.optparse_info)
        end
      end

      #
      # Add documentation for the tool's positional arguments, to the given
      # option parser.
      #
      def add_positional_arguments(optparse)
        args_to_display = @tool.required_arg_definitions + @tool.optional_arg_definitions
        args_to_display << @tool.remaining_args_definition if @tool.remaining_args_definition
        return if args_to_display.empty?
        optparse.separator("")
        optparse.separator("Positional arguments:")
        args_to_display.each do |arg_info|
          optparse.separator("    #{arg_info.canonical_name.ljust(31)}  #{arg_info.doc.first}")
          (arg_info.doc[1..-1] || []).each do |d|
            optparse.separator("                                     #{d}")
          end
        end
      end

      #
      # Add documentation for the tool's subcommands, to the given option
      # parser.
      #
      def add_command_list(optparse, recursive)
        name_len = @tool.full_name.length
        subtools = @loader.list_subtools(@tool.full_name, recursive: recursive)
        return if subtools.empty?
        optparse.separator("")
        optparse.separator("Commands:")
        subtools.each do |subtool|
          tool_name = subtool.full_name.slice(name_len..-1).join(" ").ljust(31)
          optparse.separator("    #{tool_name}  #{subtool.effective_desc}")
        end
      end
    end
  end
end
