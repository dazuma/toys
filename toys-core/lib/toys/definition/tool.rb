# frozen_string_literal: true

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
require "set"

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
      OPTPARSER_ACCEPTORS = ::Set.new(
        [
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
        ]
      ).freeze

      ##
      # Create a new tool.
      # @private
      #
      def initialize(loader, parent, full_name, priority, middleware_stack)
        @parent = parent
        @full_name = full_name.dup.freeze
        @priority = priority
        @middleware_stack = middleware_stack

        @acceptors = {}
        @mixins = {}
        @templates = {}

        reset_definition(loader)
      end

      ##
      # Reset the definition of this tool, deleting all definition data but
      # leaving named acceptors, mixins, and templates intact.
      # Should be called only from the DSL.
      # @private
      #
      def reset_definition(loader)
        @tool_class = DSL::Tool.new_class(@full_name, @priority, loader)

        @source_info = nil
        @definition_finished = false

        @desc = WrappableString.new("")
        @long_desc = []

        @default_data = {}
        @used_flags = []
        @initializers = []

        default_flag_group = Definition::FlagGroup.new(nil, nil, nil)
        @flag_groups = [default_flag_group]
        @flag_group_names = {nil => default_flag_group}

        @flag_definitions = []
        @required_arg_definitions = []
        @optional_arg_definitions = []
        @remaining_args_definition = nil

        @disable_argument_parsing = false
        @includes_modules = false
        @custom_context_directory = nil
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
      # @return [Toys::WrappableString]
      #
      attr_reader :desc

      ##
      # Returns the long description strings as an array.
      # @return [Array<Toys::WrappableString>]
      #
      attr_reader :long_desc

      ##
      # Return a list of all defined flag groups, in order.
      # @return [Array<Toys::Definition::FlagGroup>]
      #
      attr_reader :flag_groups

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
      # Returns info on the source of this tool, or nil if the source is not
      # defined.
      # @return [Toys::Definition::SourceInfo,nil]
      #
      attr_reader :source_info

      ##
      # Returns the custom context directory set for this tool, or nil if none
      # is set.
      # @return [String,nil]
      #
      attr_reader :custom_context_directory

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
        tool_class.public_instance_methods(false).include?(:run)
      end

      ##
      # Returns true if this tool handles interrupts.
      # @return [Boolean]
      #
      def interruptable?
        tool_class.public_instance_methods(false).include?(:interrupt)
      end

      ##
      # Returns true if this tool has at least one included module.
      # @return [Boolean]
      #
      def includes_modules?
        @includes_modules
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
        includes_arguments? || runnable? || argument_parsing_disabled? ||
          includes_modules? || includes_description?
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
      # Resolve the given acceptor. You may pass in a
      # {Toys::Definition::Acceptor}, an acceptor name, a well-known acceptor
      # understood by OptionParser, or `nil`.
      #
      # Returns either `nil` or an acceptor that is usable by OptionParser.
      #
      # If an acceptor name is given, it may be resolved by this tool or any of
      # its ancestors. Raises {Toys::ToolDefinitionError} if the name is not
      # recognized.
      #
      # @param [Object] accept An acceptor input.
      # @return [Object] The resolved acceptor.
      #
      def resolve_acceptor(accept)
        return accept if accept.nil? || accept.is_a?(Acceptor)
        name = accept
        accept = @acceptors.fetch(name) do |k|
          if @parent
            @parent.resolve_acceptor(k)
          elsif OPTPARSER_ACCEPTORS.include?(k)
            k
          end
        end
        if accept.nil?
          raise ToolDefinitionError, "Unknown acceptor: #{name.inspect}"
        end
        accept
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
      # @param [Toys::Definition::SourceInfo] source Source info
      #
      def lock_source(source)
        if source_info && source_info.source != source.source
          raise ToolDefinitionError,
                "Cannot redefine tool #{display_name.inspect} in #{source.source_name}" \
                " (already defined in #{source_info.source_name})"
        end
        @source_info = source
      end

      ##
      # Set the short description string.
      #
      # The description may be provided as a {Toys::WrappableString}, a single
      # string (which will be wrapped), or an array of strings, which will be
      # interpreted as string fragments that will be concatenated and wrapped.
      #
      # @param [Toys::WrappableString,String,Array<String>] desc
      #
      def desc=(desc)
        check_definition_state
        @desc = WrappableString.make(desc)
      end

      ##
      # Set the long description strings.
      #
      # Each string may be provided as a {Toys::WrappableString}, a single
      # string (which will be wrapped), or an array of strings, which will be
      # interpreted as string fragments that will be concatenated and wrapped.
      #
      # @param [Array<Toys::WrappableString,String,Array<String>>] long_desc
      #
      def long_desc=(long_desc)
        check_definition_state
        @long_desc = WrappableString.make_array(long_desc)
      end

      ##
      # Append long description strings.
      #
      # Each string may be provided as a {Toys::WrappableString}, a single
      # string (which will be wrapped), or an array of strings, which will be
      # interpreted as string fragments that will be concatenated and wrapped.
      #
      # @param [Array<Toys::WrappableString,String,Array<String>>] long_desc
      #
      def append_long_desc(long_desc)
        check_definition_state
        @long_desc += WrappableString.make_array(long_desc)
      end

      ##
      # Add an acceptor to the tool. This acceptor may be refereneced by name
      # when adding a flag or an arg.
      #
      # @param [Toys::Definition::Acceptor] acceptor The acceptor to add.
      #
      def add_acceptor(acceptor)
        if @acceptors.key?(acceptor.name)
          raise ToolDefinitionError,
                "An acceptor named #{acceptor.name.inspect} has already been" \
                " defined in tool #{display_name.inspect}."
        end
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
        name = name.to_s
        if @mixins.key?(name)
          raise ToolDefinitionError,
                "A mixin named #{name.inspect} has already been defined in tool" \
                " #{display_name.inspect}."
        end
        @mixins[name] = mixin_module
        self
      end

      ##
      # Add a named template class to this tool.
      #
      # @param [String] name The name of the template.
      # @param [Class] template_class The template class.
      #
      def add_template(name, template_class)
        name = name.to_s
        if @templates.key?(name)
          raise ToolDefinitionError,
                "A template named #{name.inspect} has already been defined in tool" \
                " #{display_name.inspect}."
        end
        @templates[name] = template_class
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
      # Add a flag group to the group list.
      #
      # @param [Symbol] type The type of group. Allowed values: `:required`,
      #     `:optional`, `:exactly_one`, `:at_most_one`, `:at_least_one`.
      #     Default is `:optional`.
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the group. See {Toys::Definition::Tool#desc=} for a
      #     description of  allowed formats. Defaults to `"Flags"`.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
      #     Long description for the flag group. See
      #     {Toys::Definition::Tool#long_desc=} for a description of allowed
      #     formats. Defaults to the empty array.
      # @param [String,Symbol,nil] name The name of the group, or nil for no
      #     name.
      # @param [Boolean] report_collisions If `true`, raise an exception if a
      #     the given name is already taken. If `false`, ignore. Default is
      #     `true`.
      # @param [Boolean] prepend If `true`, prepend rather than append the
      #     group to the list. Default is `false`.
      #
      def add_flag_group(type: :optional, desc: nil, long_desc: nil,
                         name: nil, report_collisions: true, prepend: false)
        if !name.nil? && @flag_group_names.key?(name)
          return self unless report_collisions
          raise ToolDefinitionError, "Flag group #{name} already exists"
        end
        unless type.is_a?(::Class)
          type = ModuleLookup.to_module_name(type)
          type = Definition::FlagGroup.const_get(type)
        end
        group = type.new(name, desc, long_desc)
        @flag_group_names[name] = group unless name.nil?
        if prepend
          @flag_groups.unshift(group)
        else
          @flag_groups.push(group)
        end
        self
      end

      ##
      # Add a flag to the current tool. Each flag must specify a key which
      # the script may use to obtain the flag value from the context.
      # You may then provide the flags themselves in `OptionParser` form.
      #
      # @param [String,Symbol] key The key to use to retrieve the value from
      #     the execution context.
      # @param [Array<String>] flags The flags in OptionParser format.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param [Object] default The default value. This is the value that will
      #     be set in the context if this flag is not provided on the command
      #     line. Defaults to `nil`.
      # @param [Proc,nil,:set,:push] handler An optional handler for
      #     setting/updating the value. A handler is a proc taking two
      #     arguments, the given value and the previous value, returning the
      #     new value that should be set. You may also specify a predefined
      #     named handler. The `:set` handler (the default) replaces the
      #     previous value (effectively `-> (val, _prev) { val }`). The
      #     `:push` handler expects the previous value to be an array and
      #     pushes the given value onto it; it should be combined with setting
      #     `default: []` and is intended for "multi-valued" flags.
      # @param [Boolean] report_collisions Raise an exception if a flag is
      #     requested that is already in use or marked as disabled. Default is
      #     true.
      # @param [Toys::Definition::FlagGroup,String,Symbol,nil] group Group for
      #     this flag. You may provide a group name, a FlagGroup object, or
      #     `nil` which denotes the default group.
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the flag. See {Toys::Definition::Tool#desc=} for a
      #     description of  allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
      #     Long description for the flag. See
      #     {Toys::Definition::Tool#long_desc=} for a description of allowed
      #     formats. Defaults to the empty array.
      # @param [String] display_name A display name for this flag, used in help
      #     text and error messages.
      #
      def add_flag(key, flags = [],
                   accept: nil, default: nil, handler: nil,
                   report_collisions: true, group: nil,
                   desc: nil, long_desc: nil, display_name: nil)
        unless group.is_a?(Definition::FlagGroup)
          group_name = group
          group = @flag_group_names[group_name]
          raise ToolDefinitionError, "No such flag group: #{group_name.inspect}" if group.nil?
        end
        check_definition_state(is_arg: true)
        accept = resolve_acceptor(accept)
        flag_def = Definition::Flag.new(key, flags, @used_flags, report_collisions,
                                        accept, handler, default, display_name, group)
        flag_def.desc = desc if desc
        flag_def.long_desc = long_desc if long_desc
        if flag_def.active?
          @flag_definitions << flag_def
          group << flag_def
        end
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
      # @param [String,Symbol] key The key to use to retrieve the value from
      #     the execution context.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param [String] display_name A name to use for display (in help text and
      #     error reports). Defaults to the key in upper case.
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the arg. See {Toys::Definition::Tool#desc=} for a
      #     description of  allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
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
      # @param [String,Symbol] key The key to use to retrieve the value from
      #     the execution context.
      # @param [Object] default The default value. This is the value that will
      #     be set in the context if this argument is not provided on the command
      #     line. Defaults to `nil`.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param [String] display_name A name to use for display (in help text and
      #     error reports). Defaults to the key in upper case.
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the arg. See {Toys::Definition::Tool#desc=} for a
      #     description of  allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
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
      # @param [String,Symbol] key The key to use to retrieve the value from
      #     the execution context.
      # @param [Object] default The default value. This is the value that will
      #     be set in the context if no unmatched arguments are provided on the
      #     command line. Defaults to the empty array `[]`.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param [String] display_name A name to use for display (in help text and
      #     error reports). Defaults to the key in upper case.
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the arg. See {Toys::Definition::Tool#desc=} for a
      #     description of  allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
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
        @tool_class.to_run(&proc)
      end

      ##
      # Set the interruptable block
      #
      # @param [Proc] proc The interrupt block
      #
      def interruptable=(proc)
        @tool_class.to_interrupt(&proc)
      end

      ##
      # Add an initializer.
      #
      # @param [Proc] proc The initializer block
      # @param [Object...] args Arguments to pass to the initializer
      #
      def add_initializer(proc, *args)
        check_definition_state
        @initializers << [proc, args]
        self
      end

      ##
      # Set the custom context directory.
      #
      # @param [String] dir
      #
      def custom_context_directory=(dir)
        check_definition_state
        @custom_context_directory = dir
      end

      ##
      # Return the effective context directory.
      # If there is a custom context directory, uses that. Otherwise, looks for
      # a custom context directory up the tool ancestor chain. If none is
      # found, uses the default context directory from the source info. It is
      # possible for there to be no context directory at all, in which case,
      # returns nil.
      #
      # @return [String,nil]
      #
      def context_directory
        lookup_custom_context_directory || source_info&.context_directory
      end

      ##
      # Lookup the custom context directory in this tool and its ancestors.
      # @private
      #
      def lookup_custom_context_directory
        custom_context_directory || @parent&.lookup_custom_context_directory
      end

      ##
      # Mark this tool as having at least one module included
      # @private
      #
      def mark_includes_modules
        check_definition_state
        @includes_modules = true
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
            middleware_stack.reverse_each do |middleware|
              config_proc = make_config_proc(middleware, loader, config_proc)
            end
            config_proc.call
          end
          flag_groups.each do |flag_group|
            flag_group.flag_definitions.sort_by!(&:sort_str)
          end
          @definition_finished = true
        end
        self
      end

      ##
      # Run all initializers against a tool. Should be called from the Runner
      # only.
      # @private
      #
      def run_initializers(tool)
        @initializers.each do |func, args|
          tool.instance_exec(*args, &func)
        end
      end

      ##
      # Check that the tool can still be defined. Should be called internally
      # or from the DSL only.
      # @private
      #
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

      private

      def make_config_proc(middleware, loader, next_config)
        proc { middleware.config(self, loader, &next_config) }
      end
    end
  end
end
