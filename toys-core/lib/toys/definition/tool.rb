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
  module Definition
    ##
    # A Tool is a single command that can be invoked using Toys.
    # It has a name, a series of one or more words that you use to identify
    # the tool on the command line. It also has a set of formal flags and
    # command line arguments supported, and a block that gets run when the
    # tool is executed.
    #
    class Tool
      ##
      # Built-in acceptors (i.e. those recognized by OptionParser).
      # You can reference these acceptors directly. Otherwise, you have to add
      # one explicitly to the tool using {Tool#add_acceptor}.
      #
      OPTPARSER_ACCEPTORS = [
        ::Object,
        ::NilClass,
        ::String,
        ::Integer,
        ::Float,
        ::Numeric,
        ::TrueClass,
        ::FalseClass,
        ::Array,
        ::Regexp,
        ::OptionParser::DecimalInteger,
        ::OptionParser::OctalInteger,
        ::OptionParser::DecimalNumeric
      ].freeze

      ##
      # Create a new tool.
      # @private
      #
      def initialize(loader, parent, full_name, priority, middleware_stack)
        @parent = parent
        @full_name = full_name.dup.freeze
        @tool_class = DSL::Tool.new_class(@full_name, priority, loader)
        @priority = priority
        @middleware_stack = middleware_stack

        @source_path = nil
        @definition_finished = false

        @desc = Utils::WrappableString.new("")
        @long_desc = []

        @default_data = {}
        @acceptors = create_initial_acceptors
        @used_flags = []

        @mixins = {}
        @templates = {}

        @flag_definitions = []
        @required_arg_definitions = []
        @optional_arg_definitions = []
        @remaining_args_definition = nil

        @disable_argument_parsing = false
        @runnable = false
      end

      ##
      # Return the name of the tool as an array of strings.
      # This array may not be modified.
      # @return [Array<String>]
      #
      attr_reader :full_name

      ##
      # Return the priority of this tool definition.
      # @return [Integer]
      #
      attr_reader :priority

      ##
      # Return the tool class.
      # @return [Class]
      #
      attr_reader :tool_class

      ##
      # Returns the short description string.
      # @return [Toys::Utils::WrappableString]
      #
      attr_reader :desc

      ##
      # Returns the long description strings as an array.
      # @return [Array<Toys::Utils::WrappableString>]
      #
      attr_reader :long_desc

      ##
      # Return a list of all defined flags.
      # @return [Array<Toys::Definition::Flag>]
      #
      attr_reader :flag_definitions

      ##
      # Return a list of all defined required positional arguments.
      # @return [Array<Toys::Definition::Arg>]
      #
      attr_reader :required_arg_definitions

      ##
      # Return a list of all defined optional positional arguments.
      # @return [Array<Toys::Definition::Arg>]
      #
      attr_reader :optional_arg_definitions

      ##
      # Return the remaining arguments specification, or `nil` if remaining
      # arguments are currently not supported by this tool.
      # @return [Toys::Definition::Arg,nil]
      #
      attr_reader :remaining_args_definition

      ##
      # Return a list of flags that have been used in the flag definitions.
      # @return [Array<String>]
      #
      attr_reader :used_flags

      ##
      # Return the default argument data.
      # @return [Hash]
      #
      attr_reader :default_data

      ##
      # Returns the middleware stack
      # @return [Array<Object>]
      #
      attr_reader :middleware_stack

      ##
      # Returns the path to the file that contains the definition of this tool.
      # @return [String]
      #
      attr_reader :source_path

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
      # Returns true if this tool is marked as runnable.
      # @return [Boolean]
      #
      def runnable?
        @runnable
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
      # Returns true if this tool has any definition information.
      # @return [Boolean]
      #
      def includes_definition?
        includes_arguments? || runnable?
      end

      ##
      # Returns true if this tool's definition has been finished and is locked.
      # @return [Boolean]
      #
      def definition_finished?
        @definition_finished
      end

      ##
      # Returns true if this tool has disabled argument parsing.
      # @return [Boolean]
      #
      def argument_parsing_disabled?
        @disable_argument_parsing
      end

      ##
      # Returns all arg definitions in order: required, optional, remaining.
      # @return [Array<Toys::Definition::Arg>]
      #
      def arg_definitions
        result = required_arg_definitions + optional_arg_definitions
        result << remaining_args_definition if remaining_args_definition
        result
      end

      ##
      # Returns a list of all custom acceptors used by this tool.
      # @return [Array<Toys::Definition::Acceptor>]
      #
      def custom_acceptors
        result = []
        flag_definitions.each do |f|
          result << f.accept if f.accept.is_a?(Acceptor)
        end
        arg_definitions.each do |a|
          result << a.accept if a.accept.is_a?(Acceptor)
        end
        result.uniq
      end

      ##
      # Get the named template from this tool or its ancestors.
      #
      # @param [String] name The template name
      # @return [Class,nil] The template class, or `nil` if not found.
      #
      def resolve_template(name)
        @templates.fetch(name.to_s) { |k| @parent ? @parent.resolve_template(k) : nil }
      end

      ##
      # Get the named mixin from this tool or its ancestors.
      #
      # @param [String] name The mixin name
      # @return [Module,nil] The mixin module, or `nil` if not found.
      #
      def resolve_mixin(name)
        @mixins.fetch(name.to_s) { |k| @parent ? @parent.resolve_mixin(k) : nil }
      end

      ##
      # Include the given mixin in the tool class.
      #
      # @param [String,Symbol,Module] name The mixin name or module
      #
      def include_mixin(name)
        tool_class.include(name)
        self
      end

      ##
      # Sets the path to the file that defines this tool.
      # A tool may be defined from at most one path. If a different path is
      # already set, raises {Toys::ToolDefinitionError}
      #
      # @param [String] path The path to the file defining this tool
      #
      def lock_source_path(path)
        if source_path && source_path != path
          raise ToolDefinitionError,
                "Cannot redefine tool #{display_name.inspect} in #{path}" \
                " (already defined in #{source_path})"
        end
        @source_path = path
      end

      ##
      # Set the short description string.
      #
      # The description may be provided as a {Toys::Utils::WrappableString}, a
      # single string (which will be wrapped), or an array of strings, which will
      # be interpreted as string fragments that will be concatenated and wrapped.
      #
      # @param [Toys::Utils::WrappableString,String,Array<String>] desc
      #
      def desc=(desc)
        check_definition_state
        @desc = Utils::WrappableString.make(desc)
      end

      ##
      # Set the long description strings.
      #
      # Each string may be provided as a {Toys::Utils::WrappableString}, a single
      # string (which will be wrapped), or an array of strings, which will be
      # interpreted as string fragments that will be concatenated and wrapped.
      #
      # @param [Array<Toys::Utils::WrappableString,String,Array<String>>] long_desc
      #
      def long_desc=(long_desc)
        check_definition_state
        @long_desc = Utils::WrappableString.make_array(long_desc)
      end

      ##
      # Add an acceptor to the tool. This acceptor may be refereneced by name
      # when adding a flag or an arg.
      #
      # @param [Toys::Definition::Acceptor] acceptor The acceptor to add.
      #
      def add_acceptor(acceptor)
        @acceptors[acceptor.name] = acceptor
        self
      end

      ##
      # Add a named mixin module to this tool.
      #
      # @param [String] name The name of the mixin.
      # @param [Module] mixin_module The mixin module.
      #
      def add_mixin(name, mixin_module)
        @mixins[name.to_s] = mixin_module
        self
      end

      ##
      # Add a named template class to this tool.
      #
      # @param [String] name The name of the template.
      # @param [Class] template_class The template class.
      #
      def add_template(name, template_class)
        @templates[name.to_s] = template_class
        self
      end

      ##
      # Disable argument parsing for this tool
      #
      def disable_argument_parsing
        check_definition_state
        if includes_arguments?
          raise ToolDefinitionError,
                "Cannot disable argument parsing for tool #{display_name.inspect}" \
                " because arguments have already been defined."
        end
        @disable_argument_parsing = true
        self
      end

      ##
      # Add a flag to the current tool. Each flag must specify a key which
      # the script may use to obtain the flag value from the context.
      # You may then provide the flags themselves in `OptionParser` form.
      #
      # @param [Symbol] key The key to use to retrieve the value from the
      #     execution context.
      # @param [Array<String>] flags The flags in OptionParser format.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param [Object] default The default value. This is the value that will
      #     be set in the context if this flag is not provided on the command
      #     line. Defaults to `nil`.
      # @param [Proc,nil] handler An optional handler for setting/updating the
      #     value. If given, it should take two arguments, the new given value
      #     and the previous value, and it should return the new value that
      #     should be set. The default handler simply replaces the previous
      #     value. i.e. the default is effectively `-> (val, _prev) { val }`.
      # @param [Boolean] report_collisions Raise an exception if a flag is
      #     requested that is already in use or marked as disabled. Default is
      #     true.
      # @param [String,Array<String>,Toys::Utils::WrappableString] desc Short
      #     description for the flag. See {Toys::Definition::Tool#desc=} for a
      #     description of  allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::Utils::WrappableString>] long_desc
      #     Long description for the flag. See
      #     {Toys::Definition::Tool#long_desc=} for a description of allowed
      #     formats. Defaults to the empty array.
      #
      def add_flag(key, flags = [],
                   accept: nil, default: nil, handler: nil,
                   report_collisions: true,
                   desc: nil, long_desc: nil)
        check_definition_state(is_arg: true)
        accept = resolve_acceptor(accept)
        flag_def = Definition::Flag.new(key, flags, @used_flags, report_collisions,
                                        accept, handler, default)
        flag_def.desc = desc if desc
        flag_def.long_desc = long_desc if long_desc
        @flag_definitions << flag_def if flag_def.active?
        @default_data[key] = default
        self
      end

      ##
      # Mark one or more flags as disabled, preventing their use by any
      # subsequent flag definition. This may be used to prevent middleware from
      # defining a particular flag.
      #
      # @param [String...] flags The flags to disable
      #
      def disable_flag(*flags)
        check_definition_state(is_arg: true)
        flags = flags.uniq
        intersection = @used_flags & flags
        unless intersection.empty?
          raise ToolDefinitionError, "Cannot disable flags already used: #{intersection.inspect}"
        end
        @used_flags.concat(flags)
        self
      end

      ##
      # Add a required positional argument to the current tool. You must specify
      # a key which the script may use to obtain the argument value from the
      # context.
      #
      # @param [Symbol] key The key to use to retrieve the value from the
      #     execution context.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param [String] display_name A name to use for display (in help text and
      #     error reports). Defaults to the key in upper case.
      # @param [String,Array<String>,Toys::Utils::WrappableString] desc Short
      #     description for the arg. See {Toys::Definition::Tool#desc=} for a
      #     description of  allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::Utils::WrappableString>] long_desc
      #     Long description for the arg. See
      #     {Toys::Definition::Tool#long_desc=} for a description of allowed
      #     formats. Defaults to the empty array.
      #
      def add_required_arg(key, accept: nil, display_name: nil, desc: nil, long_desc: nil)
        check_definition_state(is_arg: true)
        accept = resolve_acceptor(accept)
        arg_def = Definition::Arg.new(key, :required, accept, nil, desc, long_desc, display_name)
        @required_arg_definitions << arg_def
        self
      end

      ##
      # Add an optional positional argument to the current tool. You must specify
      # a key which the script may use to obtain the argument value from the
      # context. If an optional argument is not given on the command line, the
      # value is set to the given default.
      #
      # @param [Symbol] key The key to use to retrieve the value from the
      #     execution context.
      # @param [Object] default The default value. This is the value that will
      #     be set in the context if this argument is not provided on the command
      #     line. Defaults to `nil`.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param [String] display_name A name to use for display (in help text and
      #     error reports). Defaults to the key in upper case.
      # @param [String,Array<String>,Toys::Utils::WrappableString] desc Short
      #     description for the arg. See {Toys::Definition::Tool#desc=} for a
      #     description of  allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::Utils::WrappableString>] long_desc
      #     Long description for the arg. See
      #     {Toys::Definition::Tool#long_desc=} for a description of allowed
      #     formats. Defaults to the empty array.
      #
      def add_optional_arg(key, default: nil, accept: nil, display_name: nil,
                           desc: nil, long_desc: nil)
        check_definition_state(is_arg: true)
        accept = resolve_acceptor(accept)
        arg_def = Definition::Arg.new(key, :optional, accept, default,
                                      desc, long_desc, display_name)
        @optional_arg_definitions << arg_def
        @default_data[key] = default
        self
      end

      ##
      # Specify what should be done with unmatched positional arguments. You must
      # specify a key which the script may use to obtain the remaining args
      # from the context.
      #
      # @param [Symbol] key The key to use to retrieve the value from the
      #     execution context.
      # @param [Object] default The default value. This is the value that will
      #     be set in the context if no unmatched arguments are provided on the
      #     command line. Defaults to the empty array `[]`.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param [String] display_name A name to use for display (in help text and
      #     error reports). Defaults to the key in upper case.
      # @param [String,Array<String>,Toys::Utils::WrappableString] desc Short
      #     description for the arg. See {Toys::Definition::Tool#desc=} for a
      #     description of  allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::Utils::WrappableString>] long_desc
      #     Long description for the arg. See
      #     {Toys::Definition::Tool#long_desc=} for a description of allowed
      #     formats. Defaults to the empty array.
      #
      def set_remaining_args(key, default: [], accept: nil, display_name: nil,
                             desc: nil, long_desc: nil)
        check_definition_state(is_arg: true)
        accept = resolve_acceptor(accept)
        arg_def = Definition::Arg.new(key, :remaining, accept, default,
                                      desc, long_desc, display_name)
        @remaining_args_definition = arg_def
        @default_data[key] = default
        self
      end

      ##
      # Set the runnable block
      #
      # @param [Proc] proc The runnable block
      #
      def runnable=(proc)
        @tool_class.run(&proc)
      end

      ##
      # Mark this tool as runnable. Should be called from the DSL only.
      # @private
      #
      def mark_runnable
        check_definition_state
        @runnable = true
        self
      end

      ##
      # Complete definition and run middleware configs. Should be called from
      # the Loader only.
      # @private
      #
      def finish_definition(loader)
        unless @definition_finished
          ContextualError.capture("Error installing tool middleware!", tool_name: full_name) do
            config_proc = proc {}
            middleware_stack.reverse.each do |middleware|
              config_proc = make_config_proc(middleware, loader, config_proc)
            end
            config_proc.call
          end
          @definition_finished = true
        end
        self
      end

      private

      def make_config_proc(middleware, loader, next_config)
        proc { middleware.config(self, loader, &next_config) }
      end

      def check_definition_state(is_arg: false)
        if @definition_finished
          raise ToolDefinitionError,
                "Defintion of tool #{display_name.inspect} is already finished"
        end
        if is_arg && argument_parsing_disabled?
          raise ToolDefinitionError,
                "Tool #{display_name.inspect} has disabled argument parsing"
        end
        self
      end

      def resolve_acceptor(accept)
        return accept if accept.nil? || accept.is_a?(Acceptor)
        unless @acceptors.key?(accept)
          raise ToolDefinitionError, "Unknown acceptor: #{accept.inspect}"
        end
        @acceptors[accept]
      end

      def create_initial_acceptors
        acceptors = {}
        OPTPARSER_ACCEPTORS.each { |a| acceptors[a] = a }
        acceptors
      end
    end
  end
end
