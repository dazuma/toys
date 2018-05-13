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

require "toys/utils/wrappable_string"

module Toys
  ##
  # A Tool is a single command that can be invoked using Toys.
  # It has a name, a series of one or more words that you use to identify
  # the tool on the command line. It also has a set of formal flags and
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

      @desc = ""
      @long_desc = []

      @default_data = {}
      @flag_definitions = []
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
    # Returns the short description string.
    # @return [String,Toys::Utils::WrappableString]
    #
    attr_reader :desc

    ##
    # Returns the long description strings as an array.
    # @return [Array<String,Toys::Utils::WrappableString>]
    #
    attr_reader :long_desc

    ##
    # Return a list of all defined flags.
    # @return [Array<Toys::Tool::FlagDefinition>]
    #
    attr_reader :flag_definitions

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
    # Returns the short description string with wrapping resolved.
    #
    # @param [Integer,nil] width Wrapping width, or `nil` for infinite.
    # @param [Integer,nil] width2 Width in characters for the second and
    #     subsequent lines, or `nil` to use the same as width.
    # @return [Array<String>]
    #
    def wrapped_desc(width, width2 = nil)
      Utils::WrappableString.wrap_lines([desc], width, width2)
    end

    ##
    # Returns the long description strings with wrapping resolved.
    #
    # @param [Integer,nil] width Wrapping width, or `nil` for infinite.
    # @param [Integer,nil] width2 Width in characters for the second and
    #     subsequent lines, or `nil` to use the same as width.
    # @return [Array<String>]
    #
    def wrapped_long_desc(width, width2 = nil)
      Utils::WrappableString.wrap_lines(long_desc, width, width2)
    end

    ##
    # Returns true if there is a specific description set for this tool.
    # @return [Boolean]
    #
    def includes_description?
      !long_desc.empty? || !desc.empty?
    end

    ##
    # Returns true if at least one flag or positional argument is defined
    # for this tool.
    # @return [Boolean]
    #
    def includes_arguments?
      !default_data.empty? || !flag_definitions.empty? ||
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
    # Returns all arg definitions in order: required, optional, remaining.
    # @return [Array<Toys::Tool::ArgDefinition>]
    #
    def arg_definitions
      result = required_arg_definitions + optional_arg_definitions
      result << remaining_args_definition if remaining_args_definition
      result
    end

    ##
    # Returns a list of flags used by this tool.
    # @return [Array<String>]
    #
    def used_flags
      flag_definitions.reduce([]) { |used, fdef| used + fdef.effective_flags }.uniq
    end

    ##
    # Sets the path to the file that defines this tool.
    # A tool may be defined from at most one path. If a different path is
    # already set, raises {Toys::ToolDefinitionError}
    #
    # @param [String] path The path to the file defining this tool
    #
    def definition_path=(path)
      if definition_path && definition_path != path
        raise ToolDefinitionError,
              "Cannot redefine tool #{display_name.inspect} in #{path}" \
              " (already defined in #{definition_path})"
      end
      @definition_path = path
    end

    ##
    # Set the short description string.
    # @param [String,Toys::Utils::WrappableString] desc Short description
    #
    def desc=(desc)
      check_definition_state
      @desc = Tool.canonicalize_desc(desc)
    end

    ##
    # Set the long description strings.
    # @param [String,Toys::Utils::WrappableString,
    #     Array<String,Toys::Utils::WrappableString>] desc Long description
    #
    def long_desc=(desc)
      check_definition_state
      @long_desc = Tool.canonicalize_long_desc(desc)
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
    # Add a flag to the current tool. Each flag must specify a key which
    # the executor may use to obtain the flag value from the context.
    # You may then provide the flags themselves in `OptionParser` form.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [String...] flags The flags in OptionParser format.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if this flag is not provided on the command
    #     line. Defaults to `nil`.
    # @param [String,Toys::Utils::WrappableString,
    #     Array<String,Toys::Utils::WrappableString>] desc Short description
    #     for the flag. Defaults to empty array.
    # @param [String,Toys::Utils::WrappableString,
    #     Array<String,Toys::Utils::WrappableString>] long_desc Long
    #     description for the flag. Defaults to empty array.
    # @param [Boolean] only_unique If true, any flags that are already
    #     defined in this tool are removed from this flag. For example, if
    #     an earlier flag uses `-a`, and this flag wants to use both
    #     `-a` and `-b`, then only `-b` will be assigned to this flag.
    #     Defaults to false.
    # @param [Proc,nil] handler An optional handler for setting/updating the
    #     value. If given, it should take two arguments, the new given value
    #     and the previous value, and it should return the new value that
    #     should be set. The default handler simply replaces the previous
    #     value. i.e. the default is effectively `-> (val, _prev) { val }`.
    #
    def add_flag(key, *flags,
                 accept: nil, default: nil, desc: nil, long_desc: nil,
                 only_unique: false, handler: nil)
      check_definition_state
      flag_def = FlagDefinition.new(key, flags, accept)
      flag_def.desc = desc unless desc.nil?
      flag_def.long_desc = long_desc unless long_desc.nil?
      flag_def.handler = handler unless handler.nil?
      yield flag_def if block_given?
      if only_unique
        flag_def.remove_flags(used_flags)
      end
      if flag_def.active?
        @default_data[key] = default
        @flag_definitions << flag_def
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
    # @param [String,Toys::Utils::WrappableString,
    #     Array<String,Toys::Utils::WrappableString>] desc Short description
    #     for the arg. Defaults to empty array.
    # @param [String,Toys::Utils::WrappableString,
    #     Array<String,Toys::Utils::WrappableString>] long_desc Long
    #     description for the arg. Defaults to empty array.
    #
    def add_required_arg(key, accept: nil, desc: nil, long_desc: nil)
      check_definition_state
      arg_def = ArgDefinition.new(key, :required)
      arg_def.accept = accept unless accept.nil?
      arg_def.desc = desc unless desc.nil?
      arg_def.long_desc = long_desc unless long_desc.nil?
      yield arg_def if block_given?
      @required_arg_definitions << arg_def
      @default_data[key] = nil
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
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if this argument is not provided on the command
    #     line. Defaults to `nil`.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [String,Toys::Utils::WrappableString,
    #     Array<String,Toys::Utils::WrappableString>] desc Short description
    #     for the arg. Defaults to empty array.
    # @param [String,Toys::Utils::WrappableString,
    #     Array<String,Toys::Utils::WrappableString>] long_desc Long
    #     description for the arg. Defaults to empty array.
    #
    def add_optional_arg(key, default: nil, accept: nil, desc: nil, long_desc: nil)
      check_definition_state
      arg_def = ArgDefinition.new(key, :optional)
      arg_def.accept = accept unless accept.nil?
      arg_def.desc = desc unless desc.nil?
      arg_def.long_desc = long_desc unless long_desc.nil?
      yield arg_def if block_given?
      @optional_arg_definitions << arg_def
      @default_data[key] = default
      self
    end

    ##
    # Specify what should be done with unmatched positional arguments. You must
    # specify a key which the executor may use to obtain the remaining args
    # from the context.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if no unmatched arguments are provided on the
    #     command line. Defaults to the empty array `[]`.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [String,Toys::Utils::WrappableString,
    #     Array<String,Toys::Utils::WrappableString>] desc Short description
    #     for the arg. Defaults to empty array.
    # @param [String,Toys::Utils::WrappableString,
    #     Array<String,Toys::Utils::WrappableString>] long_desc Long
    #     description for the arg. Defaults to empty array.
    #
    def set_remaining_args(key, default: [], accept: nil, desc: nil, long_desc: nil)
      check_definition_state
      arg_def = ArgDefinition.new(key, :remaining)
      arg_def.accept = accept unless accept.nil?
      arg_def.desc = desc unless desc.nil?
      arg_def.long_desc = long_desc unless long_desc.nil?
      yield arg_def if block_given?
      @remaining_args_definition = arg_def
      @default_data[key] = default
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
    # @param [Toys::CLI] cli The CLI execution context
    # @param [Array<String>] args The arguments to pass to the tool. Should
    #     not include the tool name.
    # @param [Integer] verbosity The starting verbosity. Defaults to 0.
    #
    # @return [Integer] The result code.
    #
    def execute(cli, args, verbosity: 0)
      ContextualError.capture_path(
        "Error during tool execution!", definition_path,
        tool_name: full_name, tool_args: args
      ) do
        Execution.new(self).execute(cli, args, verbosity: verbosity)
      end
    end

    ##
    # Complete definition and run middleware configs
    #
    # @private
    #
    def finish_definition
      unless @definition_finished
        ContextualError.capture("Error installing tool middleware!", tool_name: full_name) do
          config_proc = proc {}
          middleware_stack.reverse.each do |middleware|
            config_proc = make_config_proc(middleware, config_proc)
          end
          config_proc.call
        end
        @definition_finished = true
      end
      self
    end

    ##
    # Representation of a single flag
    #
    class FlagSyntax
      ##
      # Parse flag syntax
      # @param [String] str syntax.
      #
      def initialize(str)
        if str =~ /^(-[\?\w])(\s?(\w+))?$/
          setup(str, [$1], $1, "-", " ", $3)
        elsif str =~ /^--\[no-\](\w[\?\w-]*)$/
          setup(str, ["--#{$1}", "--no-#{$1}"], "--[no-]#{$1}", "--", nil, nil)
        elsif str =~ /^(--\w[\?\w-]*)(([=\s])(\w+))?$/
          setup(str, [$1], $1, "--", $3, $4)
        else
          raise ToolDefinitionError, "Illegal flag: #{str.inspect}"
        end
      end

      attr_reader :original_str
      attr_reader :str_without_value
      attr_reader :flags
      attr_reader :flag_style
      attr_reader :value_delim
      attr_reader :value_label

      private

      def setup(original_str, flags, str_without_value, flag_style, value_delim, value_label)
        @original_str = original_str
        @flags = flags
        @str_without_value = str_without_value
        @flag_style = flag_style
        @value_delim = value_delim
        @value_label = value_label ? value_label.upcase : value_label
      end
    end

    ##
    # Representation of a formal set of flags.
    #
    class FlagDefinition
      ##
      # The default handler replaces the previous value.
      # @return [Proc]
      #
      DEFAULT_HANDLER = ->(val, _prev) { val }

      ##
      # Create a FlagDefinition
      # @private
      #
      # @param [Symbol] key This flag will set the given context key.
      # @param [Array<String>] flags Flags in OptionParser format
      # @param [Object] accept The acceptor, which may be nil.
      #
      def initialize(key, flags, accept)
        @key = key
        @flag_syntax = flags.map { |s| FlagSyntax.new(s) }
        @accept = accept
        if @flag_syntax.empty?
          create_default_flag
        else
          add_missing_values
        end
        @desc = ""
        @long_desc = []
        @handler = DEFAULT_HANDLER
        reset_data
      end

      ##
      # Returns the key.
      # @return [Symbol]
      #
      attr_reader :key

      ##
      # Returns an array of FlagSyntax for the flags.
      # @return [Array<FlagSyntax>]
      #
      attr_reader :flag_syntax

      ##
      # Returns the acceptor, which may be `nil`.
      # @return [Object]
      #
      attr_reader :accept

      ##
      # Returns the short description string.
      # @return [String,Toys::Utils::WrappableString]
      #
      attr_reader :desc

      ##
      # Set the short description string.
      # @param [String,Toys::Utils::WrappableString] desc Short description
      #
      def desc=(desc)
        @desc = Tool.canonicalize_desc(desc)
      end

      ##
      # Returns the long description strings as an array.
      # @return [Array<String,Toys::Utils::WrappableString>]
      #
      attr_reader :long_desc

      ##
      # Set the long description strings.
      # @param [String,Toys::Utils::WrappableString,
      #     Array<String,Toys::Utils::WrappableString>] desc Long description
      #
      def long_desc=(desc)
        @long_desc = Tool.canonicalize_long_desc(desc)
      end

      ##
      # Returns the handler.
      # @return [Proc]
      #
      attr_reader :handler

      ##
      # Set the handler
      # @param [Proc,nil] handler The handler for setting/updating the value.
      #     The handler should take two arguments, the new given value and the
      #     previous value, and it should return the new value that should be
      #     set. If `nil`, uses {DEFAULT_HANDLER}.
      #
      def handler=(handler)
        @handler = handler || DEFAULT_HANDLER
      end

      ##
      # Returns an array of FlagSyntax including only single-dash flags
      # @return [Array<FlagSyntax>]
      #
      def single_flag_syntax
        @single_flag_syntax ||= flag_syntax.find_all { |ss| ss.flag_style == "-" }
      end

      ##
      # Returns an array of FlagSyntax including only double-dash flags
      # @return [Array<FlagSyntax>]
      #
      def double_flag_syntax
        @double_flag_syntax ||= flag_syntax.find_all { |ss| ss.flag_style == "--" }
      end

      ##
      # Returns the list of effective flags used.
      # @return [Array<String>]
      #
      def effective_flags
        @effective_flags ||= flag_syntax.map(&:flags).flatten
      end

      ##
      # Returns the short description string with wrapping resolved.
      #
      # @param [Integer,nil] width Wrapping width, or `nil` for infinite.
      # @param [Integer,nil] width2 Width in characters for the second and
      #     subsequent lines, or `nil` to use the same as width.
      # @return [Array<String>]
      #
      def wrapped_desc(width, width2 = nil)
        Utils::WrappableString.wrap_lines([desc], width, width2)
      end

      ##
      # Returns the long description strings with wrapping resolved.
      #
      # @param [Integer,nil] width Wrapping width, or `nil` for infinite.
      # @param [Integer,nil] width2 Width in characters for the second and
      #     subsequent lines, or `nil` to use the same as width.
      # @return [Array<String>]
      #
      def wrapped_long_desc(width, width2 = nil)
        Utils::WrappableString.wrap_lines(long_desc, width, width2)
      end

      ##
      # All optparser flags and acceptor if present
      # @return [Array]
      #
      def optparser_info
        @optparser_info ||= flag_syntax.map(&:original_str) + Array(accept)
      end

      ##
      # Returns true if this flag is active. That is, it has a nonempty
      # flags list.
      # @return [Boolean]
      #
      def active?
        !effective_flags.empty?
      end

      ##
      # Return the value label if one exists
      # @return [String,nil]
      #
      def value_label
        find_canonical_value_label
        @value_label
      end

      ##
      # Return the value delimiter if one exists
      # @return [String,nil]
      #
      def value_delim
        find_canonical_value_label
        @value_delim
      end

      ##
      # Removes the given flags.
      # @param [Array<String>] flags
      #
      def remove_flags(flags)
        @flag_syntax.select! do |ss|
          ss.flags.all? { |s| !flags.include?(s) }
        end
        reset_data
        self
      end

      private

      def create_default_flag
        canonical_flag = key.to_s.downcase.tr("_", "-").gsub(/[^a-z0-9-]/, "")
        unless canonical_flag.empty?
          flag = @accept ? "--#{canonical_flag}=VALUE" : "--#{canonical_flag}"
          @flag_syntax << FlagSyntax.new(flag)
        end
      end

      def add_missing_values
        if @accept && @flag_syntax.all? { |fs| fs.value_label.nil? }
          @flag_syntax.map! do |fs|
            begin
              FlagSyntax.new("#{fs.original_str} VALUE")
            rescue ToolDefinitionError
              fs
            end
          end
        end
      end

      def reset_data
        @effective_flags = nil
        @optparser_info = nil
        @single_flag_syntax = nil
        @double_flag_syntax = nil
        @value_label = nil
        @value_delim = nil
      end

      def find_canonical_value_label
        return if @value_delim
        double_flag_syntax.reverse_each do |ss|
          next unless ss.value_label
          @value_label = ss.value_label
          @value_delim = ss.value_delim
          break
        end
        return if @value_delim
        single_flag_syntax.reverse_each do |ss|
          next unless ss.value_label
          @value_label = ss.value_label
          @value_delim = ss.value_delim
          break
        end
        return if @value_delim
        @value_label = nil
        @value_delim = ""
      end
    end

    ##
    # Representation of a formal positional argument
    #
    class ArgDefinition
      ##
      # Create an ArgDefinition
      # @private
      #
      # @param [Symbol] key This argument will set the given context key.
      # @param [:required,:optional,:remaining] type Type of this argument
      #
      def initialize(key, type)
        @key = key
        @type = type
        @accept = nil
        @desc = ""
        @long_desc = []
      end

      ##
      # Returns the key.
      # @return [Symbol]
      #
      attr_reader :key

      ##
      # Returns the acceptor, which may be `nil`.
      # @return [Object]
      #
      attr_accessor :accept

      ##
      # Returns the short description string.
      # @return [String,Toys::Utils::WrappableString]
      #
      attr_reader :desc

      ##
      # Type of this argument.
      # @return [:required,:optional,:remaining]
      #
      attr_reader :type

      ##
      # Set the short description string.
      # @param [String,Toys::Utils::WrappableString] desc Short description
      #
      def desc=(desc)
        @desc = Tool.canonicalize_desc(desc)
      end

      ##
      # Returns the long description strings as an array.
      # @return [Array<String,Toys::Utils::WrappableString>]
      #
      attr_reader :long_desc

      ##
      # Set the long description strings.
      # @param [String,Toys::Utils::WrappableString,
      #     Array<String,Toys::Utils::WrappableString>] desc Long description
      #
      def long_desc=(desc)
        @long_desc = Tool.canonicalize_long_desc(desc)
      end

      ##
      # Return a display name for this arg. Used in usage documentation.
      #
      # @return [String]
      #
      def display_name
        key.to_s.tr("-", "_").gsub(/\W/, "").upcase
      end

      ##
      # Returns the short description string with wrapping resolved.
      #
      # @param [Integer,nil] width Wrapping width, or `nil` for infinite.
      # @param [Integer,nil] width2 Width in characters for the second and
      #     subsequent lines, or `nil` to use the same as width.
      # @return [Array<String>]
      #
      def wrapped_desc(width, width2 = nil)
        Utils::WrappableString.wrap_lines([desc], width, width2)
      end

      ##
      # Returns the long description strings with wrapping resolved.
      #
      # @param [Integer,nil] width Wrapping width, or `nil` for infinite.
      # @param [Integer,nil] width2 Width in characters for the second and
      #     subsequent lines, or `nil` to use the same as width.
      # @return [Array<String>]
      #
      def wrapped_long_desc(width, width2 = nil)
        Utils::WrappableString.wrap_lines(long_desc, width, width2)
      end

      ##
      # Process the given value through the acceptor.
      # May raise an exception if the acceptor rejected the input.
      #
      # @param [String] input Input value
      # @return [Object] Accepted value
      #
      def process_value(input)
        return input unless accept
        result = input
        optparse = ::OptionParser.new
        optparse.on("--abc=VALUE", accept) { |v| result = v }
        optparse.parse(["--abc", input])
        result
      end
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
      def canonicalize_desc(desc)
        desc.is_a?(Utils::WrappableString) ? desc : desc.gsub(/\s/, " ")
      end

      ## @private
      def canonicalize_long_desc(desc)
        Array(desc).map do |d|
          d.is_a?(Utils::WrappableString) ? d : d.split("\n")
        end.flatten.freeze
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

      def execute(cli, args, verbosity: 0)
        parse_args(args, verbosity)
        context = create_child_context(cli)

        original_level = context.logger.level
        context.logger.level = cli.base_level - @data[Context::VERBOSITY]
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
        # The following clears out the Officious (hidden default flags).
        optparse.remove
        optparse.remove
        optparse.new
        optparse.new
        @tool.flag_definitions.each do |flag|
          optparse.on(*flag.optparser_info) do |val|
            @data[flag.key] = flag.handler.call(val, @data[flag.key])
          end
        end
        optparse
      end

      def parse_required_args(remaining, args)
        @tool.required_arg_definitions.each do |arg_info|
          if remaining.empty?
            reason = "No value given for required argument #{arg_info.display_name}"
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

      def create_child_context(cli)
        context = Context.new(cli, @data)
        modules = @tool.modules
        context.extend(*modules) unless modules.empty?
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
            context.logger.fatal("No implementation for tool #{@tool.display_name.inspect}")
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
