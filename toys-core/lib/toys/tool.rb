# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

require "set"

module Toys
  ##
  # A Tool describes a single command that can be invoked using Toys.
  # It has a name, a series of one or more words that you use to identify
  # the tool on the command line. It also has a set of formal flags and
  # command line arguments supported, and a block that gets run when the
  # tool is executed.
  #
  class Tool
    ##
    # Create a new tool.
    # Should be created only from the DSL via the Loader.
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
      @completions = {}

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

      default_flag_group = FlagGroup::Base.new(nil, nil, nil)
      @flag_groups = [default_flag_group]
      @flag_group_names = {nil => default_flag_group}

      @flags = []
      @required_args = []
      @optional_args = []
      @remaining_arg = nil

      @disable_argument_parsing = false
      @enforce_flags_before_args = false
      @includes_modules = false
      @custom_context_directory = nil

      @completion = StandardCompletion.new
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
    # @return [Array<Toys::FlagGroup>]
    #
    attr_reader :flag_groups

    ##
    # Return a list of all defined flags.
    # @return [Array<Toys::Flag>]
    #
    attr_reader :flags

    ##
    # Return a list of all defined required positional arguments.
    # @return [Array<Toys::PositionalArg>]
    #
    attr_reader :required_args

    ##
    # Return a list of all defined optional positional arguments.
    # @return [Array<Toys::PositionalArg>]
    #
    attr_reader :optional_args

    ##
    # Return the remaining arguments specification, or `nil` if remaining
    # arguments are currently not supported by this tool.
    # @return [Toys::PositionalArg,nil]
    #
    attr_reader :remaining_arg

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
    # @return [Toys::SourceInfo,nil]
    #
    attr_reader :source_info

    ##
    # Returns the custom context directory set for this tool, or nil if none
    # is set.
    # @return [String,nil]
    #
    attr_reader :custom_context_directory

    ##
    # Returns the completion strategy for this tool.
    # @return [Toys::Completion::Base,Proc]
    #
    attr_reader :completion

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
      !default_data.empty? || !flags.empty? ||
        !required_args.empty? || !optional_args.empty? ||
        !remaining_arg.nil? || flags_before_args_enforced?
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
    # Returns true if this tool enforces flags before args.
    # @return [Boolean]
    #
    def flags_before_args_enforced?
      @enforce_flags_before_args
    end

    ##
    # Returns all arg definitions in order: required, optional, remaining.
    # @return [Array<Toys::PositionalArg>]
    #
    def positional_args
      result = required_args + optional_args
      result << remaining_arg if remaining_arg
      result
    end

    ##
    # Resolve the given flag given the flag string. Returns an object that
    # describes the resolution result, including whether the resolution
    # matched a unique flag, the specific flag syntax that was matched, and
    # additional information.
    #
    # @param [String] str Flag string
    # @return [Toys::Flag::Resolution]
    #
    def resolve_flag(str)
      result = Flag::Resolution.new(str)
      flags.each do |flag_def|
        result.merge!(flag_def.resolve(str))
      end
      result
    end

    ##
    # Get the named acceptor from this tool or its ancestors.
    #
    # @param [String] name The acceptor name
    # @return [Tool::Acceptor::Base,nil] The acceptor, or `nil` if not found.
    #
    def lookup_acceptor(name)
      @acceptors.fetch(name.to_s) { |k| @parent ? @parent.lookup_acceptor(k) : nil }
    end

    ##
    # Get the named template from this tool or its ancestors.
    #
    # @param [String] name The template name
    # @return [Class,nil] The template class, or `nil` if not found.
    #
    def lookup_template(name)
      @templates.fetch(name.to_s) { |k| @parent ? @parent.lookup_template(k) : nil }
    end

    ##
    # Get the named mixin from this tool or its ancestors.
    #
    # @param [String] name The mixin name
    # @return [Module,nil] The mixin module, or `nil` if not found.
    #
    def lookup_mixin(name)
      @mixins.fetch(name.to_s) { |k| @parent ? @parent.lookup_mixin(k) : nil }
    end

    ##
    # Get the named completion from this tool or its ancestors.
    #
    # @param [String] name The completion name
    # @return [Tool::Completion::Base,Proc,nil] The completion proc, or `nil`
    #     if not found.
    #
    def lookup_completion(name)
      @completions.fetch(name.to_s) { |k| @parent ? @parent.lookup_completion(k) : nil }
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
    # @param [Toys::SourceInfo] source Source info
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
    # Add a named acceptor to the tool. This acceptor may be refereneced by
    # name when adding a flag or an arg. See {Toys::Acceptor.create} for
    # detailed information on how to specify an acceptor.
    #
    # @param [String] name The name of the acceptor.
    # @param [Toys::Acceptor::Base,Object] acceptor The acceptor to add. You
    #     can provide either an acceptor object, or a spec understood by
    #     {Toys::Acceptor.create}.
    # @param [String] type_desc Type description string, shown in help.
    #     Defaults to the acceptor name.
    #
    def add_acceptor(name, acceptor = nil, type_desc: nil, &block)
      name = name.to_s
      if @acceptors.key?(name)
        raise ToolDefinitionError,
              "An acceptor named #{name.inspect} has already been defined in tool" \
              " #{display_name.inspect}."
      end
      @acceptors[name] = Toys::Acceptor.create(acceptor, type_desc: type_desc, &block)
      self
    end

    ##
    # Add a named mixin module to this tool.
    # You may provide a mixin module or a block that configures one.
    #
    # @param [String] name The name of the mixin.
    # @param [Module] mixin_module The mixin module.
    #
    def add_mixin(name, mixin_module = nil, &block)
      name = name.to_s
      if @mixins.key?(name)
        raise ToolDefinitionError,
              "A mixin named #{name.inspect} has already been defined in tool" \
              " #{display_name.inspect}."
      end
      @mixins[name] = mixin_module || Mixin.create(&block)
      self
    end

    ##
    # Add a named completion proc to this tool. The completion may be
    # referenced by name when adding a flag or an arg. See
    # {Toys::Completion.create} for detailed information on how to specify a
    # completion.
    #
    # @param [String] name The name of the completion.
    # @param [Proc,Tool::Completion::Base,Object] completion The completion to
    #     add. You can provide either a completion object, or a spec understood
    #     by {Toys::Completion.create}.
    #
    def add_completion(name, completion = nil, &block)
      name = name.to_s
      if @completions.key?(name)
        raise ToolDefinitionError,
              "A completion named #{name.inspect} has already been defined in tool" \
              " #{display_name.inspect}."
      end
      @completions[name] = Toys::Completion.create(completion || block)
      self
    end

    ##
    # Add a named template class to this tool.
    # You may provide a template class or a block that configures one.
    #
    # @param [String] name The name of the template.
    # @param [Class] template_class The template class.
    #
    def add_template(name, template_class = nil, &block)
      name = name.to_s
      if @templates.key?(name)
        raise ToolDefinitionError,
              "A template named #{name.inspect} has already been defined in tool" \
              " #{display_name.inspect}."
      end
      @templates[name] = template_class || Template.create(&block)
      self
    end

    ##
    # Disable argument parsing for this tool.
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
    # Enforce that flags must come before args for this tool.
    # You may disable enforcement by passoing `false` for the state.
    # @param [Boolean] state
    #
    def enforce_flags_before_args(state = true)
      check_definition_state
      if argument_parsing_disabled?
        raise ToolDefinitionError,
              "Cannot enforce flags before args for tool #{display_name.inspect}" \
              " because parsing is disabled."
      end
      @enforce_flags_before_args = state
      self
    end

    ##
    # Add a flag group to the group list.
    #
    # The type should be one of the following symbols:
    # *   `:optional` All flags in the group are optional
    # *   `:required` All flags in the group are required
    # *   `:exactly_one` Exactly one flag in the group must be provided
    # *   `:at_least_one` At least one flag in the group must be provided
    # *   `:at_most_one` At most one flag in the group must be provided
    #
    # @param [Symbol] type The type of group. Default is `:optional`.
    # @param [String,Array<String>,Toys::WrappableString] desc Short
    #     description for the group. See {Toys::Tool#desc=} for a description
    #     of allowed formats. Defaults to `"Flags"`.
    # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
    #     Long description for the flag group. See {Toys::Tool#long_desc=} for
    #     a description of allowed formats. Defaults to the empty array.
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
      group = FlagGroup.create(type: type, name: name, desc: desc, long_desc: long_desc)
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
    # @param [Array<String>] flags The flags in OptionParser format. If empty,
    #     a flag will be inferred from the key.
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
    # @param [Object] complete_flags A specifier for shell tab completion
    #     for flag names associated with this flag. By default, a
    #     {Toys::Flag::StandardCompletion} is used, which provides the flag's
    #     names as completion candidates. To customize completion, set this to
    #     a hash of options to pass to the constructor for
    #     {Toys::Flag::StandardCompletion}, or pass any other spec recognized
    #     by {Toys::Completion.create}.
    # @param [Object] complete_values A specifier for shell tab completion
    #     for flag values associated with this flag. Pass any spec
    #     recognized by {Toys::Completion.create}.
    # @param [Boolean] report_collisions Raise an exception if a flag is
    #     requested that is already in use or marked as disabled. Default is
    #     true.
    # @param [Toys::FlagGroup,String,Symbol,nil] group Group for
    #     this flag. You may provide a group name, a FlagGroup object, or
    #     `nil` which denotes the default group.
    # @param [String,Array<String>,Toys::WrappableString] desc Short
    #     description for the flag. See {Toys::Tool#desc=} for a description of
    #     allowed formats. Defaults to the empty string.
    # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
    #     Long description for the flag. See {Toys::Tool#long_desc=} for a
    #     description of allowed formats. Defaults to the empty array.
    # @param [String] display_name A display name for this flag, used in help
    #     text and error messages.
    #
    def add_flag(key, flags = [],
                 accept: nil, default: nil, handler: nil, complete_flags: nil,
                 complete_values: nil, report_collisions: true, group: nil, desc: nil,
                 long_desc: nil, display_name: nil)
      unless group.is_a?(FlagGroup::Base)
        group_name = group
        group = @flag_group_names[group_name]
        raise ToolDefinitionError, "No such flag group: #{group_name.inspect}" if group.nil?
      end
      check_definition_state(is_arg: true)
      accept = resolve_acceptor_name(accept)
      complete_flags = resolve_completion_name(complete_flags)
      complete_values = resolve_completion_name(complete_values)
      flag_def = Flag.new(key, flags, @used_flags, report_collisions, accept, handler, default,
                          complete_flags, complete_values, desc, long_desc, display_name, group)
      if flag_def.active?
        @flags << flag_def
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
    # @param [Object] complete A specifier for shell tab completion. See
    #     {Toys::Completion.create} for recognized formats.
    # @param [String] display_name A name to use for display (in help text and
    #     error reports). Defaults to the key in upper case.
    # @param [String,Array<String>,Toys::WrappableString] desc Short
    #     description for the arg. See {Toys::Tool#desc=} for a description of
    #     allowed formats. Defaults to the empty string.
    # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
    #     Long description for the arg. See {Toys::Tool#long_desc=} for a
    #     description of allowed formats. Defaults to the empty array.
    #
    def add_required_arg(key, accept: nil, complete: nil, display_name: nil,
                         desc: nil, long_desc: nil)
      check_definition_state(is_arg: true)
      accept = resolve_acceptor_name(accept)
      complete = resolve_completion_name(complete)
      arg_def = PositionalArg.new(key, :required, accept, nil, complete,
                                  desc, long_desc, display_name)
      @required_args << arg_def
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
    # @param [Object] complete A specifier for shell tab completion. See
    #     {Toys::Completion.create} for recognized formats.
    # @param [String] display_name A name to use for display (in help text and
    #     error reports). Defaults to the key in upper case.
    # @param [String,Array<String>,Toys::WrappableString] desc Short
    #     description for the arg. See {Toys::Tool#desc=} for a description of
    #     allowed formats. Defaults to the empty string.
    # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
    #     Long description for the arg. See {Toys::Tool#long_desc=} for a
    #     description of allowed formats. Defaults to the empty array.
    #
    def add_optional_arg(key, default: nil, accept: nil, complete: nil,
                         display_name: nil, desc: nil, long_desc: nil)
      check_definition_state(is_arg: true)
      accept = resolve_acceptor_name(accept)
      complete = resolve_completion_name(complete)
      arg_def = PositionalArg.new(key, :optional, accept, default, complete,
                                  desc, long_desc, display_name)
      @optional_args << arg_def
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
    # @param [Object] complete A specifier for shell tab completion. See
    #     {Toys::Completion.create} for recognized formats.
    # @param [String] display_name A name to use for display (in help text and
    #     error reports). Defaults to the key in upper case.
    # @param [String,Array<String>,Toys::WrappableString] desc Short
    #     description for the arg. See {Toys::Tool#desc=} for a description of
    #     allowed formats. Defaults to the empty string.
    # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
    #     Long description for the arg. See {Toys::Tool#long_desc=} for a
    #     description of allowed formats. Defaults to the empty array.
    #
    def set_remaining_args(key, default: [], accept: nil, complete: nil,
                           display_name: nil, desc: nil, long_desc: nil)
      check_definition_state(is_arg: true)
      accept = resolve_acceptor_name(accept)
      complete = resolve_completion_name(complete)
      arg_def = PositionalArg.new(key, :remaining, accept, default, complete,
                                  desc, long_desc, display_name)
      @remaining_arg = arg_def
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
    # Set the completion strategy for this Tool. By default, a
    # {Toys::Tool::StandardCompletion} is used, providing a standard algorithm
    # that finds appropriate completions from flags, positional arguments, and
    # subtools. To customize completion, set this either to a hash of options
    # to pass to the {Toys::Tool::StandardCompletion} constructor, or any other
    # spec recognized by {Toys::Completion.create}.
    #
    # @param [Object] spec
    #
    def completion=(spec)
      @completion =
        case spec
        when nil
          StandardCompletion.new
        when ::Hash
          StandardCompletion.new(spec)
        else
          Completion.create(spec)
        end
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
    # Mark this tool as having at least one module included.
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
          flag_group.flags.sort_by!(&:sort_str)
        end
        @definition_finished = true
      end
      self
    end

    ##
    # Run all initializers against a context. Called from the Runner.
    # @private
    #
    def run_initializers(context)
      @initializers.each do |func, args|
        context.instance_exec(*args, &func)
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

    ##
    # A Completion that implements the standard algorithm for a tool.
    #
    class StandardCompletion < Completion::Base
      ##
      # Create a completion given configuration options.
      #
      # @param [Boolean] complete_subtools Whether to complete subtool names
      # @param [Boolean] include_hidden_subtools Whether to include hidden
      #     subtools (i.e. those beginning with an underscore)
      # @param [Boolean] complete_args Whether to complete positional args
      # @param [Boolean] complete_flags Whether to complete flag names
      # @param [Boolean] complete_flag_values Whether to complete flag values
      #
      def initialize(complete_subtools: true, include_hidden_subtools: false,
                     complete_args: true, complete_flags: true, complete_flag_values: true)
        @complete_subtools = complete_subtools
        @include_hidden_subtools = include_hidden_subtools
        @complete_flags = complete_flags
        @complete_args = complete_args
        @complete_flag_values = complete_flag_values
      end

      ##
      # Returns candidates for the current completion.
      #
      # @param [Toys::Completion::Context] context the current completion
      #     context including the string fragment.
      # @return [Array<Toys::Completion::Candidate>] an array of candidates
      #
      def call(context)
        candidates = valued_flag_candidates(context)
        return candidates if candidates
        candidates = subtool_or_arg_candidates(context)
        candidates += plain_flag_candidates(context)
        candidates += flag_value_candidates(context)
        candidates
      end

      private

      def valued_flag_candidates(context)
        return unless @complete_flag_values
        arg_parser = context.arg_parser
        return unless arg_parser.flags_allowed?
        active_flag_def = arg_parser.active_flag_def
        return if active_flag_def && active_flag_def.value_type == :required
        match = /\A(--\w[\?\w-]*)=(.*)\z/.match(context.fragment)
        return unless match

        flag_def = context.tool.resolve_flag(match[1]).unique_flag
        return [] unless flag_def
        context.fragment = match[2]
        flag_def.value_completion.call(context)
      end

      def subtool_or_arg_candidates(context)
        return [] if context.arg_parser.active_flag_def
        return [] if context.arg_parser.flags_allowed? && context.fragment.start_with?("-")
        subtool_candidates(context) || arg_candidates(context)
      end

      def subtool_candidates(context)
        return if !@complete_subtools || !context.args.empty?
        subtools = context.cli.loader.list_subtools(context.tool.full_name,
                                                    include_hidden: @include_hidden_subtools)
        return if subtools.empty?
        fragment = context.fragment
        candidates = []
        subtools.each do |subtool|
          name = subtool.simple_name
          candidates << Completion::Candidate.new(name) if name.start_with?(fragment)
        end
        candidates
      end

      def arg_candidates(context)
        return unless @complete_args
        arg_def = context.arg_parser.next_arg_def
        return [] unless arg_def
        arg_def.completion.call(context)
      end

      def plain_flag_candidates(context)
        return [] if !@complete_flags || context.params[:disable_flags]
        arg_parser = context.arg_parser
        return [] unless arg_parser.flags_allowed?
        flag_def = arg_parser.active_flag_def
        return [] if flag_def && flag_def.value_type == :required
        return [] if context.fragment =~ /\A[^-]/ || context.fragment.include?("=")
        context.tool.flags.flat_map do |flag|
          flag.flag_completion.call(context)
        end
      end

      def flag_value_candidates(context)
        return unless @complete_flag_values
        arg_parser = context.arg_parser
        flag_def = arg_parser.active_flag_def
        return [] unless flag_def
        return [] if @complete_flags && arg_parser.flags_allowed? &&
                     flag_def.value_type == :optional && context.fragment.start_with?("-")
        flag_def.value_completion.call(context)
      end
    end

    private

    def make_config_proc(middleware, loader, next_config)
      proc { middleware.config(self, loader, &next_config) }
    end

    def resolve_acceptor_name(name)
      return name unless name.is_a?(::String)
      accept = lookup_acceptor(name)
      raise ToolDefinitionError, "Unknown acceptor: #{name.inspect}" if accept.nil?
      accept
    end

    def resolve_completion_name(name)
      return name unless name.is_a?(::String)
      completion = lookup_completion(name)
      raise ToolDefinitionError, "Unknown completion: #{name.inspect}" if completion.nil?
      completion
    end
  end
end
