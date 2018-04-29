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

module Toys::Utils
  ##
  # Helper that generates usage text
  #
  class Usage
    def self.from_context(context)
      new(context[:__tool], context[:__binary_name], context[:__loader])
    end

    def initialize(tool, binary_name, loader)
      @tool = tool
      @binary_name = binary_name
      @loader = loader
    end

    def string(recursive: false)
      optparse = ::OptionParser.new
      optparse.banner = @tool.includes_executor? ? tool_banner : collection_banner
      unless @tool.effective_long_desc.empty?
        optparse.separator("")
        optparse.separator(@tool.effective_long_desc)
      end
      add_switches(optparse)
      if @tool.includes_executor?
        add_positional_arguments(optparse)
      else
        add_command_list(optparse, recursive)
      end
      optparse.to_s
    end

    private

    def tool_banner
      banner = ["Usage:", @binary_name] + @tool.full_name
      banner << "[<options...>]" unless @tool.switches.empty?
      @tool.required_args.each do |arg_info|
        banner << "<#{arg_info.canonical_name}>"
      end
      @tool.optional_args.each do |arg_info|
        banner << "[<#{arg_info.canonical_name}>]"
      end
      if @tool.remaining_args
        banner << "[<#{@tool.remaining_args.canonical_name}...>]"
      end
      banner.join(" ")
    end

    def collection_banner
      (["Usage:", @binary_name] + @tool.full_name + ["<command>", "[<options...>]"]).join(" ")
    end

    def add_switches(optparse)
      return if @tool.switches.empty?
      optparse.separator("")
      optparse.separator("Options:")
      @tool.switches.each do |switch|
        optparse.on(*switch.optparse_info)
      end
    end

    def add_positional_arguments(optparse)
      args_to_display = @tool.required_args + @tool.optional_args
      args_to_display << @tool.remaining_args if @tool.remaining_args
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

    def add_command_list(optparse, recursive)
      name_len = @tool.full_name.length
      subtools = @loader.list_subtools(@tool.full_name, recursive)
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
