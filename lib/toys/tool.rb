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
    def initialize(full_name, middleware_stack)
      @full_name = full_name
      @middleware_stack = middleware_stack.dup

      @definition_path = nil
      @cur_path = nil
      @alias_target = nil
      @definition_finished = false

      @desc = nil
      @long_desc = nil

      @default_data = {}
      @switches = []
      @used_switches = []
      @required_args = []
      @optional_args = []
      @remaining_args = nil

      @helpers = {}
      @modules = []
      @executor = nil
    end

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
    attr_reader :middleware_stack

    def simple_name
      full_name.last
    end

    def display_name
      full_name.join(" ")
    end

    def root?
      full_name.empty?
    end

    def includes_executor?
      @executor.is_a?(::Proc)
    end

    def alias?
      !alias_target.nil?
    end

    def effective_desc
      @desc || default_desc
    end

    def effective_long_desc
      @long_desc || @desc || default_desc
    end

    def includes_description?
      !@long_desc.nil? || !@desc.nil?
    end

    def includes_definition?
      !@default_data.empty? || !@switches.empty? ||
        !@required_args.empty? || !@optional_args.empty? ||
        !@remaining_args.nil? || includes_executor? ||
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
      if includes_description? || includes_definition?
        raise ToolDefinitionError, "Tool #{display_name.inspect} already has" \
          " a definition and cannot be made an alias"
      end
      @alias_target = target_word
      self
    end

    def desc=(str)
      check_definition_state
      @desc = str
    end

    def long_desc=(str)
      check_definition_state
      @long_desc = str
    end

    def add_helper(name, &block)
      check_definition_state
      name_str = name.to_s
      unless name_str =~ /^[a-z]\w+$/
        raise ToolDefinitionError, "Illegal helper name: #{name_str.inspect}"
      end
      @helpers[name.to_sym] = block
    end

    def use_module(mod)
      check_definition_state
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

    def add_switch(key, *switches,
                   accept: nil, default: nil, doc: nil, only_unique: false, handler: nil)
      check_definition_state
      switches << "--#{Tool.canonical_switch(key)}=VALUE" if switches.empty?
      switches << accept unless accept.nil?
      switches += Array(doc)
      switch_info = SwitchInfo.new(key, switches, handler)
      if only_unique
        switch_info.remove_switches(@used_switches)
      end
      if switch_info.active?
        @default_data[key] = default
        @switches << switch_info
        @used_switches += switch_info.switches
        @used_switches.uniq!
      end
    end

    def add_required_arg(key, accept: nil, doc: nil)
      check_definition_state
      @default_data[key] = nil
      @required_args << ArgInfo.new(key, accept, Array(doc))
    end

    def add_optional_arg(key, accept: nil, default: nil, doc: nil)
      check_definition_state
      @default_data[key] = default
      @optional_args << ArgInfo.new(key, accept, Array(doc))
    end

    def set_remaining_args(key, accept: nil, default: [], doc: nil)
      check_definition_state
      @default_data[key] = default
      @remaining_args = ArgInfo.new(key, accept, Array(doc))
    end

    def executor=(executor)
      check_definition_state
      @executor = executor
    end

    def finish_definition
      unless alias?
        config_proc = proc {}
        middleware_stack.reverse.each do |middleware|
          config_proc = make_config_proc(middleware, config_proc)
        end
        config_proc.call
      end
      @definition_finished = true
      self
    end

    def execute(context_base, args, verbosity: 0)
      finish_definition unless @definition_finished
      Execution.new(self).execute(context_base, args, verbosity: verbosity)
    end

    private

    def make_config_proc(middleware, next_config)
      proc { middleware.config(self, &next_config) }
    end

    def default_desc
      if alias?
        "(Alias of #{@alias_target.inspect})"
      elsif includes_executor?
        "(No description available)"
      else
        "(A collection of commands)"
      end
    end

    def check_definition_state
      if alias?
        raise ToolDefinitionError, "Tool #{display_name.inspect} is an alias"
      end
      if @definition_path
        in_clause = @cur_path ? "in #{@cur_path} " : ""
        raise ToolDefinitionError,
              "Cannot redefine tool #{display_name.inspect} #{in_clause}" \
              "(already defined in #{@definition_path})"
      end
      if @definition_finished
        raise ToolDefinitionError,
              "Defintion of tool #{display_name.inspect} is already finished"
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
      def initialize(key, optparse_info, handler = nil)
        @key = key
        @optparse_info = optparse_info
        @handler = handler || ->(val, _cur) { val }
        @switches = nil
      end

      attr_reader :key
      attr_reader :optparse_info
      attr_reader :handler

      def switches
        @switches ||= optparse_info.map { |s| extract_switch(s) }.flatten
      end

      def active?
        !switches.empty?
      end

      def remove_switches(switches)
        @optparse_info.select! do |s|
          extract_switch(s).all? { |ss| !switches.include?(ss) }
        end
        @switches = nil
        self
      end

      def extract_switch(str)
        if str =~ /^(-[\?\w])/
          [$1]
        elsif str =~ /^--\[no-\](\w[\w-]*)/
          ["--#{$1}", "--no-#{$1}"]
        elsif str =~ /^(--\w[\w-]*)/
          [$1]
        else
          []
        end
      end
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
        n = canonical_name
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
        @data = @tool.default_data.dup
        @data[:__tool] = tool
        @data[:__tool_name] = tool.full_name
      end

      def execute(context_base, args, verbosity: 0)
        return execute_alias(context_base, args) if @tool.alias?

        parse_args(args, verbosity)
        context = create_child_context(context_base)

        original_level = context.logger.level
        context.logger.level = context_base.base_level - @data[:__verbosity]
        begin
          perform_execution(context)
        ensure
          context.logger.level = original_level
        end
      end

      private

      def parse_args(args, base_verbosity)
        optparse = create_option_parser
        @data[:__optparse] = optparse
        @data[:__verbosity] = base_verbosity
        @data[:__args] = args
        @data[:__usage_error] = nil
        remaining = optparse.parse(args)
        remaining = parse_required_args(remaining, args)
        remaining = parse_optional_args(remaining)
        parse_remaining_args(remaining, args)
      rescue ::OptionParser::ParseError => e
        @data[:__usage_error] = e.message
      end

      def create_option_parser
        optparse = ::OptionParser.new
        optparse.remove
        optparse.remove
        optparse.new
        optparse.new
        @tool.switches.each do |switch|
          optparse.on(*switch.optparse_info) do |val|
            @data[switch.key] = switch.handler.call(val, @data[switch.key])
          end
        end
        optparse
      end

      def parse_required_args(remaining, args)
        @tool.required_args.each do |arg_info|
          if remaining.empty?
            reason = "No value given for required argument named <#{arg_info.canonical_name}>"
            raise create_parse_error(args, reason)
          end
          @data[arg_info.key] = arg_info.process_value(remaining.shift)
        end
        remaining
      end

      def parse_optional_args(remaining)
        @tool.optional_args.each do |arg_info|
          break if remaining.empty?
          @data[arg_info.key] = arg_info.process_value(remaining.shift)
        end
        remaining
      end

      def parse_remaining_args(remaining, args)
        return if remaining.empty?
        unless @tool.remaining_args
          if @tool.includes_executor?
            raise create_parse_error(remaining, "Extra arguments provided")
          else
            raise create_parse_error(@tool.full_name + args, "Tool not found")
          end
        end
        @data[@tool.remaining_args.key] =
          remaining.map { |arg| @tool.remaining_args.process_value(arg) }
      end

      def create_parse_error(path, reason)
        OptionParser::ParseError.new(*path).tap do |e|
          e.reason = reason
        end
      end

      def create_child_context(context_base)
        context = context_base.create_context(@data)
        @tool.modules.each do |mod|
          context.extend(mod)
        end
        @tool.helpers.each do |name, block|
          context.define_singleton_method(name, &block)
        end
        context
      end

      def perform_execution(context)
        executor = proc do
          context.instance_eval(&@tool.executor)
        end
        @tool.middleware_stack.reverse.each do |middleware|
          executor = make_executor(middleware, context, executor)
        end
        catch(:result) do
          executor.call
          0
        end
      end

      def make_executor(middleware, context, next_executor)
        proc { middleware.execute(context, &next_executor) }
      end

      def execute_alias(context_base, args)
        target_name = @tool.full_name.slice(0..-2) + [@tool.alias_target]
        target_tool = context_base.loader.lookup(target_name)
        if target_tool.full_name == target_name
          target_tool.execute(context_base, args)
        else
          context_base.logger.fatal("Alias target #{@tool.alias_target.inspect} not found")
          -1
        end
      end
    end
  end
end
