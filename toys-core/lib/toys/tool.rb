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
  # A Tool is a single command that can be invoked using Toys.
  # It has a name, a series of one or more words that you use to identify
  # the tool on the command line. It also has a set of formal switches and
  # command line arguments supported, and a block that gets run when the
  # tool is executed.
  #
  class Tool
    ##
    # Create a new tool.
    #
    # @param [Array<String>] full_name The name of the tool
    #
    def initialize(full_name)
      @full_name = full_name.dup.freeze
      @middleware_stack = []

      @definition_path = nil
      @definition_finished = false

      @desc = nil
      @long_desc = nil

      @default_data = {}
      @switch_definitions = []
      @required_arg_definitions = []
      @optional_arg_definitions = []
      @remaining_args_definition = nil

      @helpers = {}
      @modules = []
      @executor = nil
    end

    ##
    # Return the name of the tool as an array of strings.
    # This array may not be modified.
    # @return [Array<String>]
    #
    attr_reader :full_name

    ##
    # Return a list of all defined switches.
    # @return [Array<Toys::Tool::SwitchDefinition>]
    #
    attr_reader :switch_definitions

    ##
    # Return a list of all defined required positional arguments.
    # @return [Array<Toys::Tool::ArgDefinition>]
    #
    attr_reader :required_arg_definitions

    ##
    # Return a list of all defined optional positional arguments.
    # @return [Array<Toys::Tool::ArgDefinition>]
    #
    attr_reader :optional_arg_definitions

    ##
    # Return the remaining arguments specification, or `nil` if remaining
    # arguments are currently not supported by this tool.
    # @return [Toys::Tool::ArgDefinition,nil]
    #
    attr_reader :remaining_args_definition

    ##
    # Return the default argument data.
    # @return [Hash]
    #
    attr_reader :default_data

    ##
    # Return a list of modules that will be available during execution.
    # @return [Array<Module>]
    #
    attr_reader :modules

    ##
    # Return a list of helper methods that will be available during execution.
    # @return [Hash{Symbol => Proc}]
    #
    attr_reader :helpers

    ##
    # Return the executor block, or `nil` if not present.
    # @return [Proc,nil]
    #
    attr_reader :executor

    ##
    # Returns the middleware stack
    # @return [Array<Object>]
    #
    attr_reader :middleware_stack

    ##
    # Returns the path to the file that contains the definition of this tool.
    # @return [String]
    #
    attr_reader :definition_path

    ##
    # Returns the local name of this tool.
    # @return [String]
    #
    def simple_name
      full_name.last
    end

    ##
    # Returns a displayable name of this tool, generally the full name
    # delimited by spaces.
    # @return [String]
    #
    def display_name
      full_name.join(" ")
    end

    ##
    # Returns true if this tool is a root tool.
    # @return [Boolean]
    #
    def root?
      full_name.empty?
    end

    ##
    # Returns true if this tool has an executor defined.
    # @return [Boolean]
    #
    def includes_executor?
      executor.is_a?(::Proc)
    end

    ##
    # Returns the effective short description for this tool. This will be
    # displayed when this tool is listed in a command list.
    # @return [String]
    #
    def effective_desc
      @desc || ""
    end

    ##
    # Returns the effective long description for this tool. This will be
    # displayed as part of the usage for this particular tool.
    # @return [String]
    #
    def effective_long_desc
      @long_desc || @desc || ""
    end

    ##
    # Returns true if there is a specific description set for this tool.
    # @return [Boolean]
    #
    def includes_description?
      !@long_desc.nil? || !@desc.nil?
    end

    ##
    # Returns true if at least one switch or positional argument is defined
    # for this tool.
    # @return [Boolean]
    #
    def includes_arguments?
      !default_data.empty? || !switch_definitions.empty? ||
        !required_arg_definitions.empty? || !optional_arg_definitions.empty? ||
        !remaining_args_definition.nil?
    end

    ##
    # Returns true if at least one helper method or module is added to this
    # tool.
    # @return [Boolean]
    #
    def includes_helpers?
      !helpers.empty? || !modules.empty?
    end

    ##
    # Returns true if this tool has any definition information.
    # @return [Boolean]
    #
    def includes_definition?
      includes_arguments? || includes_executor? || includes_helpers?
    end

    ##
    # Returns a list of switch flags used by this tool.
    # @return [Array<String>]
    #
    def used_switches
      @switch_definitions.reduce([]) { |used, sdef| used + sdef.switches }.uniq
    end

    ##
    # Sets the path to the file that defines this tool.
    # A tool may be defined from at most one path. If a different path is
    # already set, raises {Toys::ToolDefinitionError}
    #
    # @param [String] path The path to the file defining this tool
    #
    def definition_path=(path)
      if @definition_path && @definition_path != path
        raise ToolDefinitionError,
              "Cannot redefine tool #{display_name.inspect} in #{path}" \
              " (already defined in #{@definition_path})"
      end
      @definition_path = path
    end

    ##
    # Set the short description.
    #
    # @param [String] str The short description
    #
    def desc=(str)
      check_definition_state
      @desc = str
    end

    ##
    # Set the long description.
    #
    # @param [String] str The long description
    #
    def long_desc=(str)
      check_definition_state
      @long_desc = str
    end

    ##
    # Define a helper method that will be available during execution.
    # Pass the name of the method in the argument, and provide a block with
    # the method body. Note the method name may not start with an underscore.
    #
    # @param [String] name The method name
    #
    def add_helper(name, &block)
      check_definition_state
      name_str = name.to_s
      unless name_str =~ /^[a-z]\w+$/
        raise ToolDefinitionError, "Illegal helper name: #{name_str.inspect}"
      end
      @helpers[name.to_sym] = block
      self
    end

    ##
    # Mix in the given module during execution. You may provide the module
    # itself, or the name of a well-known module under {Toys::Helpers}.
    #
    # @param [Module,String] name The module or module name.
    #
    def use_module(name)
      check_definition_state
      case name
      when ::Module
        @modules << name
      when ::Symbol
        mod = Helpers.lookup(name.to_s)
        if mod.nil?
          raise ToolDefinitionError, "Module not found: #{name.inspect}"
        end
        @modules << mod
      else
        raise ToolDefinitionError, "Illegal helper module name: #{name.inspect}"
      end
      self
    end

    ##
    # Add a switch to the current tool. Each switch must specify a key which
    # the executor may use to obtain the switch value from the context.
    # You may then provide the switches themselves in `OptionParser` form.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [String...] switches The switches in OptionParser format.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if this switch is not provided on the command
    #     line. Defaults to `nil`.
    # @param [String,nil] doc The documentation for the switch, which appears
    #     in the usage documentation. Defaults to `nil` for no documentation.
    # @param [Boolean] only_unique If true, any switches that are already
    #     defined in this tool are removed from this switch. For example, if
    #     an earlier switch uses `-a`, and this switch wants to use both
    #     `-a` and `-b`, then only `-b` will be assigned to this switch.
    #     Defaults to false.
    # @param [Proc,nil] handler An optional handler for setting/updating the
    #     value. If given, it should take two arguments, the new given value
    #     and the previous value, and it should return the new value that
    #     should be set. The default handler simply replaces the previous
    #     value. i.e. the default is effectively `-> (val, _prev) { val }`.
    #
    def add_switch(key, *switches,
                   accept: nil, default: nil, doc: nil, only_unique: false, handler: nil)
      check_definition_state
      switches << "--#{Tool.canonical_switch(key)}=VALUE" if switches.empty?
      bad_switch = switches.find { |s| Tool.extract_switch(s).empty? }
      if bad_switch
        raise ToolDefinitionError, "Illegal switch: #{bad_switch.inspect}"
      end
      switch_info = SwitchDefinition.new(key, switches + Array(accept) + Array(doc), handler)
      if only_unique
        switch_info.remove_switches(used_switches)
      end
      if switch_info.active?
        @default_data[key] = default
        @switch_definitions << switch_info
      end
      self
    end

    ##
    # Add a required positional argument to the current tool. You must specify
    # a key which the executor may use to obtain the argument value from the
    # context.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [String,nil] doc The documentation for the switch, which appears
    #     in the usage documentation. Defaults to `nil` for no documentation.
    #
    def add_required_arg(key, accept: nil, doc: nil)
      check_definition_state
      @default_data[key] = nil
      @required_arg_definitions << ArgDefinition.new(key, accept, Array(doc))
      self
    end

    ##
    # Add an optional positional argument to the current tool. You must specify
    # a key which the executor may use to obtain the argument value from the
    # context. If an optional argument is not given on the command line, the
    # value is set to the given default.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if this argument is not provided on the command
    #     line. Defaults to `nil`.
    # @param [String,nil] doc The documentation for the argument, which appears
    #     in the usage documentation. Defaults to `nil` for no documentation.
    #
    def add_optional_arg(key, accept: nil, default: nil, doc: nil)
      check_definition_state
      @default_data[key] = default
      @optional_arg_definitions << ArgDefinition.new(key, accept, Array(doc))
      self
    end

    ##
    # Specify what should be done with unmatched positional arguments. You must
    # specify a key which the executor may use to obtain the remaining args
    # from the context.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if no unmatched arguments are provided on the
    #     command line. Defaults to the empty array `[]`.
    # @param [String,nil] doc The documentation for the remaining arguments,
    #     which appears in the usage documentation. Defaults to `nil` for no
    #     documentation.
    #
    def set_remaining_args(key, accept: nil, default: [], doc: nil)
      check_definition_state
      @default_data[key] = default
      @remaining_args_definition = ArgDefinition.new(key, accept, Array(doc))
      self
    end

    ##
    # Set the executor for this tool. This is a proc that will be called,
    # with `self` set to a {Toys::Context}.
    #
    # @param [Proc] executor The executor for this tool.
    #
    def executor=(executor)
      check_definition_state
      @executor = executor
    end

    ##
    # Execute this tool in the given context.
    #
    # @param [Toys::Context::Base] context_base The execution context
    # @param [Array<String>] args The arguments to pass to the tool. Should
    #     not include the tool name.
    # @param [Integer] verbosity The starting verbosity. Defaults to 0.
    #
    # @return [Integer] The result code.
    #
    def execute(context_base, args, verbosity: 0)
      finish_definition unless @definition_finished
      Execution.new(self).execute(context_base, args, verbosity: verbosity)
    end

    ##
    # Complete definition and run middleware configs
    #
    # @private
    #
    def finish_definition
      unless @definition_finished
        config_proc = proc {}
        middleware_stack.reverse.each do |middleware|
          config_proc = make_config_proc(middleware, config_proc)
        end
        config_proc.call
        @definition_finished = true
      end
      self
    end

    private

    def make_config_proc(middleware, next_config)
      proc { middleware.config(self, &next_config) }
    end

    def check_definition_state
      if @definition_finished
        raise ToolDefinitionError,
              "Defintion of tool #{display_name.inspect} is already finished"
      end
    end

    class << self
      ## @private
      def canonical_switch(name)
        name.to_s.downcase.tr("_", "-").gsub(/[^a-z0-9-]/, "")
      end

      ## @private
      def extract_switch(str)
        if !str.is_a?(String)
          []
        elsif str =~ /^(-[\?\w])(\s?\w+)?$/
          [$1]
        elsif str =~ /^--\[no-\](\w[\?\w-]*)$/
          ["--#{$1}", "--no-#{$1}"]
        elsif str =~ /^(--\w[\?\w-]*)([=\s]\w+)?$/
          [$1]
        else
          []
        end
      end
    end

    ##
    # Representation of a formal switch.
    #
    class SwitchDefinition
      ##
      # Create a SwitchDefinition
      #
      # @param [Symbol] key This switch will set the given context key.
      # @param [Array<String>] optparse_info The switch definition in
      #     OptionParser format
      # @param [Proc,nil] handler An optional handler for setting/updating the
      #     value. If given, it should take two arguments, the new given value
      #     and the previous value, and it should return the new value that
      #     should be set. If `nil`, uses a default handler that just replaces
      #     the previous value. i.e. the default is effectively
      #     `-> (val, _prev) { val }`.
      #
      def initialize(key, optparse_info, handler = nil)
        @key = key
        @optparse_info = optparse_info
        @handler = handler || ->(val, _prev) { val }
        @switches = nil
      end

      ##
      # Returns the key.
      # @return [Symbol]
      #
      attr_reader :key

      ##
      # Returns the OptionParser definition.
      # @return [Array<String>]
      #
      attr_reader :optparse_info

      ##
      # Returns the handler.
      # @return [Proc]
      #
      attr_reader :handler

      ##
      # Returns the list of switches used.
      # @return [Array<String>]
      #
      def switches
        @switches ||= optparse_info.map { |s| Tool.extract_switch(s) }.flatten
      end

      ##
      # Returns true if this switch is active. That is, it has a nonempty
      # switches list.
      # @return [Boolean]
      #
      def active?
        !switches.empty?
      end

      ##
      # Removes the given switches.
      # @param [Array<String>] switches
      #
      def remove_switches(switches)
        @optparse_info.select! do |s|
          Tool.extract_switch(s).all? { |ss| !switches.include?(ss) }
        end
        @switches = nil
        self
      end
    end

    ##
    # Representation of a formal positional argument
    #
    class ArgDefinition
      ##
      # Create an ArgDefinition
      #
      # @param [Symbol] key This argument will set the given context key.
      # @param [Object] accept An OptionParser acceptor
      # @param [Array<String>] doc An array of documentation strings
      #
      def initialize(key, accept, doc)
        @key = key
        @accept = accept
        @doc = doc
      end

      ##
      # Returns the key.
      # @return [Symbol]
      #
      attr_reader :key

      ##
      # Returns the acceptor.
      # @return [Object]
      #
      attr_reader :accept

      ##
      # Returns the documentation strings.
      # @return [Array<String>]
      #
      attr_reader :doc

      ##
      # Return a canonical name for this arg. Used in usage documentation.
      #
      # @return [String]
      #
      def canonical_name
        Tool.canonical_switch(key)
      end

      ##
      # Process the given value through the acceptor.
      #
      # @private
      #
      def process_value(val)
        return val unless accept
        n = canonical_name
        result = val
        optparse = ::OptionParser.new
        optparse.on("--#{n}=VALUE", accept) { |v| result = v }
        optparse.parse(["--#{n}", val])
        result
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
        @data[Context::TOOL] = tool
        @data[Context::TOOL_NAME] = tool.full_name
      end

      def execute(context_base, args, verbosity: 0)
        parse_args(args, verbosity)
        context = create_child_context(context_base)

        original_level = context.logger.level
        context.logger.level = context_base.base_level - @data[Context::VERBOSITY]
        begin
          perform_execution(context)
        ensure
          context.logger.level = original_level
        end
      end

      private

      def parse_args(args, base_verbosity)
        optparse = create_option_parser
        @data[Context::VERBOSITY] = base_verbosity
        @data[Context::ARGS] = args
        @data[Context::USAGE_ERROR] = nil
        remaining = optparse.parse(args)
        remaining = parse_required_args(remaining, args)
        remaining = parse_optional_args(remaining)
        parse_remaining_args(remaining, args)
      rescue ::OptionParser::ParseError => e
        @data[Context::USAGE_ERROR] = e.message
      end

      def create_option_parser
        optparse = ::OptionParser.new
        # The following clears out the Officious (hidden default switches).
        optparse.remove
        optparse.remove
        optparse.new
        optparse.new
        @tool.switch_definitions.each do |switch|
          optparse.on(*switch.optparse_info) do |val|
            @data[switch.key] = switch.handler.call(val, @data[switch.key])
          end
        end
        optparse
      end

      def parse_required_args(remaining, args)
        @tool.required_arg_definitions.each do |arg_info|
          if remaining.empty?
            reason = "No value given for required argument named <#{arg_info.canonical_name}>"
            raise create_parse_error(args, reason)
          end
          @data[arg_info.key] = arg_info.process_value(remaining.shift)
        end
        remaining
      end

      def parse_optional_args(remaining)
        @tool.optional_arg_definitions.each do |arg_info|
          break if remaining.empty?
          @data[arg_info.key] = arg_info.process_value(remaining.shift)
        end
        remaining
      end

      def parse_remaining_args(remaining, args)
        return if remaining.empty?
        unless @tool.remaining_args_definition
          if @tool.includes_executor?
            raise create_parse_error(remaining, "Extra arguments provided")
          else
            raise create_parse_error(@tool.full_name + args, "Tool not found")
          end
        end
        @data[@tool.remaining_args_definition.key] =
          remaining.map { |arg| @tool.remaining_args_definition.process_value(arg) }
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
          if @tool.includes_executor?
            context.instance_eval(&@tool.executor)
          else
            context.logger.fatal("No implementation for #{@tool.display_name.inspect}")
            context.exit(-1)
          end
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
    end
  end
end
