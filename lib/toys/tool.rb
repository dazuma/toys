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

require "optparse"

module Toys
  ##
  # A tool definition
  #
  class Tool
    def initialize(lookup, full_name)
      @lookup = lookup
      @full_name = full_name

      @definition_path = nil
      @cur_path = nil

      @alias_target = nil

      @long_desc = nil
      @short_desc = nil

      @default_data = {}
      @switches = []
      @required_args = []
      @optional_args = []
      @remaining_args = nil

      @helpers = {}
      @modules = []
      @executor = nil
    end

    attr_reader :lookup
    attr_reader :full_name
    attr_reader :switches
    attr_reader :required_args
    attr_reader :optional_args
    attr_reader :remaining_args
    attr_reader :default_data
    attr_reader :modules
    attr_reader :helpers
    attr_reader :executor
    attr_reader :alias_target

    def simple_name
      full_name.last
    end

    def display_name
      full_name.join(" ")
    end

    def root?
      full_name.empty?
    end

    def leaf?
      @executor.is_a?(::Proc)
    end

    def alias?
      !alias_target.nil?
    end

    def only_collection?
      @executor == false
    end

    def parent
      return nil if root?
      @lookup.exact_tool(full_name.slice(0..-2))
    end

    def effective_short_desc
      @short_desc || default_desc
    end

    def effective_long_desc
      @long_desc || @short_desc || default_desc
    end

    def includes_description?
      !@long_desc.nil? || !@short_desc.nil?
    end

    def includes_definition?
      !@default_data.empty? || !@switches.empty? ||
        !@required_args.empty? || !@optional_args.empty? ||
        !@remaining_args.nil? || leaf? ||
        !@helpers.empty? || !@modules.empty?
    end

    def defining_from(path)
      raise ToolDefinitionError, "Already being defined" if @cur_path
      @cur_path = path
      begin
        yield
      ensure
        @definition_path = @cur_path if includes_description? || includes_definition?
        @cur_path = nil
      end
    end

    def yield_definition
      saved_path = @cur_path
      @cur_path = nil
      begin
        yield
      ensure
        @cur_path = saved_path
      end
    end

    def make_alias_of(target_word)
      if root?
        raise ToolDefinitionError, "Cannot make the root tool an alias"
      end
      if only_collection?
        raise ToolDefinitionError, "Tool #{display_name.inspect} is already" \
          " a collection and cannot be made an alias"
      end
      if includes_description? || includes_definition?
        raise ToolDefinitionError, "Tool #{display_name.inspect} already has" \
          " a definition and cannot be made an alias"
      end
      parent.ensure_collection_only(full_name) unless root?
      @alias_target = target_word
      self
    end

    def short_desc=(str)
      check_definition_state
      @short_desc = str
    end

    def long_desc=(str)
      check_definition_state
      @long_desc = str
    end

    def add_helper(name, &block)
      check_definition_state(true)
      name_str = name.to_s
      unless name_str =~ /^[a-z]\w+$/
        raise ToolDefinitionError, "Illegal helper name: #{name_str.inspect}"
      end
      @helpers[name.to_sym] = block
    end

    def use_module(mod)
      check_definition_state(true)
      case mod
      when ::Module
        @modules << mod
      when ::Symbol
        mod = mod.to_s
        file_name =
          mod
          .gsub(/([a-zA-Z])([A-Z])/) { |_m| "#{$1}_#{$2.downcase}" }
          .downcase
        require "toys/helpers/#{file_name}"
        const_name = mod.gsub(/(^|_)([a-zA-Z0-9])/) { |_m| $2.upcase }
        @modules << Helpers.const_get(const_name)
      else
        raise ToolDefinitionError, "Illegal helper module name: #{mod.inspect}"
      end
    end

    def add_switch(key, *switches, accept: nil, default: nil, doc: nil)
      check_definition_state(true)
      @default_data[key] = default
      switches << "--#{Tool.canonical_switch(key)}=VALUE" if switches.empty?
      switches << accept unless accept.nil?
      switches += Array(doc)
      @switches << SwitchInfo.new(key, switches)
    end

    def add_required_arg(key, accept: nil, doc: nil)
      check_definition_state(true)
      @default_data[key] = nil
      @required_args << ArgInfo.new(key, accept, Array(doc))
    end

    def add_optional_arg(key, accept: nil, default: nil, doc: nil)
      check_definition_state(true)
      @default_data[key] = default
      @optional_args << ArgInfo.new(key, accept, Array(doc))
    end

    def set_remaining_args(key, accept: nil, default: [], doc: nil)
      check_definition_state(true)
      @default_data[key] = default
      @remaining_args = ArgInfo.new(key, accept, Array(doc))
    end

    def executor=(executor)
      check_definition_state(true)
      @executor = executor
    end

    def execute(context_base, args)
      Execution.new(self).execute(context_base, args)
    end

    protected

    def ensure_collection_only(source_name)
      if includes_definition?
        raise ToolDefinitionError, "Cannot create tool #{source_name.inspect}" \
          " because #{display_name.inspect} is already a tool."
      end
      unless @executor == false
        @executor = false
        parent.ensure_collection_only(source_name) unless root?
      end
    end

    private

    def default_desc
      if alias?
        "(Alias of #{@alias_target.inspect})"
      elsif leaf?
        "(No description available)"
      else
        "(A collection of commands)"
      end
    end

    def check_definition_state(execution_field = false)
      if alias?
        raise ToolDefinitionError, "Tool #{display_name.inspect} is an alias"
      end
      if @definition_path
        in_clause = @cur_path ? "in #{@cur_path} " : ""
        raise ToolDefinitionError,
              "Cannot redefine tool #{display_name.inspect} #{in_clause}" \
              "(already defined in #{@definition_path})"
      end
      if execution_field
        if only_collection?
          raise ToolDefinitionError,
                "Cannot make tool #{display_name.inspect} executable because" \
                " a descendant is already executable"
        end
        parent.ensure_collection_only(full_name) unless root?
      end
    end

    class << self
      def canonical_switch(name)
        name.to_s.downcase.tr("_", "-").gsub(/[^a-z0-9-]/, "")
      end
    end

    ##
    # Representation of a formal switch
    #
    class SwitchInfo
      def initialize(key, optparse_info)
        @key = key
        @optparse_info = optparse_info
      end

      attr_reader :key
      attr_reader :optparse_info
    end

    ##
    # Representation of a formal argument
    #
    class ArgInfo
      def initialize(key, accept, doc)
        @key = key
        @accept = accept
        @doc = doc
      end

      attr_reader :key
      attr_reader :accept
      attr_reader :doc

      def process_value(val)
        return val unless accept
        n = canonical_switch(key)
        result = val
        optparse = ::OptionParser.new
        optparse.on("--#{n}=VALUE", accept) { |v| result = v }
        optparse.parse(["--#{n}", val])
        result
      end

      def canonical_name
        Tool.canonical_switch(key)
      end
    end

    ##
    # An internal class that manages execution of a tool
    # @private
    #
    class Execution
      def initialize(tool)
        @tool = tool
      end

      def execute(context_base, args)
        return execute_alias(context_base, args) if @tool.alias?

        parsed_args = ParsedArgs.new(@tool, context_base.binary_name, args)
        context = create_child_context(context_base, parsed_args, args)

        if parsed_args.usage_error
          puts(parsed_args.usage_error)
          puts("")
          show_usage(parsed_args.optparse)
          -1
        elsif parsed_args.show_help
          show_usage(parsed_args.optparse, recursive: parsed_args.recursive)
          0
        else
          catch(:result) do
            context.instance_eval(&@tool.executor)
            0
          end
        end
      end

      private

      def create_child_context(context_base, parsed_args, args)
        context = context_base.create_context(@tool.full_name, args, parsed_args.data)
        context.logger.level += parsed_args.delta_severity
        @tool.modules.each do |mod|
          context.extend(mod)
        end
        @tool.helpers.each do |name, block|
          context.define_singleton_method(name, &block)
        end
        context
      end

      def show_usage(optparse, recursive: false)
        puts(optparse.to_s)
        if @tool.leaf?
          required_args = @tool.required_args
          optional_args = @tool.optional_args
          remaining_args = @tool.remaining_args
          if !required_args.empty? || !optional_args.empty? || remaining_args
            show_positional_arguments(required_args, optional_args, remaining_args)
          end
        else
          show_command_list(recursive)
        end
      end

      def show_positional_arguments(required_args, optional_args, remaining_args)
        puts("")
        puts("Positional arguments:")
        args_to_display = required_args + optional_args
        args_to_display << remaining_args if remaining_args
        args_to_display.each do |arg_info|
          puts("    #{arg_info.canonical_name.ljust(31)}  #{arg_info.doc.first}")
          next if arg_info.doc.empty?
          arg_info.doc[1..-1].each do |d|
            puts("                                     #{d}")
          end
        end
      end

      def show_command_list(recursive)
        puts("")
        puts("Commands:")
        name_len = @tool.full_name.length
        @tool.lookup.list_subtools(@tool.full_name, recursive).each do |subtool|
          desc = subtool.effective_short_desc
          tool_name = subtool.full_name.slice(name_len..-1).join(" ").ljust(31)
          puts("    #{tool_name}  #{desc}")
        end
      end

      def execute_alias(context_base, args)
        target_name = @tool.full_name.slice(0..-2) + [@tool.alias_target]
        target_tool = @tool.lookup.lookup(target_name)
        if target_tool.full_name == target_name
          target_tool.execute(context_base, args)
        else
          logger.fatal("Alias target #{@tool.alias_target.inspect} not found")
          -1
        end
      end
    end

    ##
    # An internal class that manages parsing of tool arguments
    # @private
    #
    class ParsedArgs
      def initialize(tool, binary_name, args)
        binary_name ||= ::File.basename($PROGRAM_NAME)
        @show_help = !tool.leaf?
        @usage_error = nil
        @delta_severity = 0
        @recursive = false
        @data = tool.default_data.dup
        @optparse = create_option_parser(tool, binary_name)
        parse_args(args, tool)
      end

      attr_reader :show_help
      attr_reader :usage_error
      attr_reader :delta_severity
      attr_reader :recursive
      attr_reader :data
      attr_reader :optparse

      private

      ##
      # Well-known flags
      # @private
      #
      SPECIAL_FLAGS = %w[
        -q
        --quiet
        -v
        --verbose
        -?
        -h
        --help
      ].freeze

      def parse_args(args, tool)
        remaining = @optparse.parse(args)
        remaining = parse_required_args(remaining, tool, args)
        remaining = parse_optional_args(remaining, tool)
        parse_remaining_args(remaining, tool, args)
      rescue ::OptionParser::ParseError => e
        @usage_error = e
      end

      def create_option_parser(tool, binary_name)
        optparse = ::OptionParser.new
        optparse.banner =
          if tool.leaf?
            leaf_banner(tool, binary_name)
          else
            collection_banner(tool, binary_name)
          end
        unless tool.effective_long_desc.empty?
          optparse.separator("")
          optparse.separator(tool.effective_long_desc)
        end
        optparse.separator("")
        optparse.separator("Options:")
        if tool.leaf?
          leaf_switches(tool, optparse)
        else
          collection_switches(optparse)
        end
        optparse
      end

      def leaf_banner(tool, binary_name)
        banner = ["Usage:", binary_name] + tool.full_name
        banner << "[<options...>]" unless tool.switches.empty?
        tool.required_args.each do |arg_info|
          banner << "<#{arg_info.canonical_name}>"
        end
        tool.optional_args.each do |arg_info|
          banner << "[<#{arg_info.canonical_name}>]"
        end
        if tool.remaining_args
          banner << "[<#{tool.remaining_args.canonical_name}...>]"
        end
        banner.join(" ")
      end

      def collection_banner(tool, binary_name)
        (["Usage:", binary_name] + tool.full_name + ["<command>", "[<options...>]"]).join(" ")
      end

      def leaf_switches(tool, optparse)
        found_special_flags = []
        leaf_normal_switches(tool.switches, optparse, found_special_flags)
        leaf_verbose_switch(optparse, found_special_flags)
        leaf_quiet_switch(optparse, found_special_flags)
        leaf_help_switch(optparse, found_special_flags)
      end

      def collection_switches(optparse)
        optparse.on("-?", "--help", "Show help message")
        optparse.on("-r", "--[no-]recursive", "Show all subcommands recursively") do |val|
          @recursive = val
        end
      end

      def leaf_normal_switches(switches, optparse, found_special_flags)
        switches.each do |switch|
          found_special_flags |= (switch.optparse_info & SPECIAL_FLAGS)
          optparse.on(*switch.optparse_info) do |val|
            @data[switch.key] = val
          end
        end
      end

      def leaf_verbose_switch(optparse, found_special_flags)
        flags = ["-v", "--verbose"] - found_special_flags
        return if flags.empty?
        optparse.on(*(flags + ["Increase verbosity"])) do
          @delta_severity -= 1
        end
      end

      def leaf_quiet_switch(optparse, found_special_flags)
        flags = ["-q", "--quiet"] - found_special_flags
        return if flags.empty?
        optparse.on(*(flags + ["Decrease verbosity"])) do
          @delta_severity += 1
        end
      end

      def leaf_help_switch(optparse, found_special_flags)
        flags = ["-?", "-h", "--help"] - found_special_flags
        return if flags.empty?
        optparse.on(*(flags + ["Show help message"])) do
          @show_help = true
        end
      end

      def parse_required_args(remaining, tool, args)
        tool.required_args.each do |arg_info|
          if !@show_help && remaining.empty?
            reason = "No value given for required argument named <#{arg_info.canonical_name}>"
            raise create_parse_error(args, reason)
          end
          @data[arg_info.key] = arg_info.process_value(remaining.shift)
        end
        remaining
      end

      def parse_optional_args(remaining, tool)
        tool.optional_args.each do |arg_info|
          break if remaining.empty?
          @data[arg_info.key] = arg_info.process_value(remaining.shift)
        end
        remaining
      end

      def parse_remaining_args(remaining, tool, args)
        return if remaining.empty?
        unless tool.remaining_args
          if tool.leaf?
            raise create_parse_error(remaining, "Extra arguments provided")
          else
            raise create_parse_error(tool.full_name + args, "Tool not found")
          end
        end
        @data[tool.remaining_args.key] =
          remaining.map { |arg| tool.remaining_args.process_value(arg) }
      end

      def create_parse_error(path, reason)
        OptionParser::ParseError.new(*path).tap do |e|
          e.reason = reason
        end
      end
    end
  end
end
