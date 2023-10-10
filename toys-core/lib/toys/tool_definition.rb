# frozen_string_literal: true

require "set"

module Toys
  ##
  # A ToolDefinition describes a single command that can be invoked using Toys.
  # It has a name, a series of one or more words that you use to identify
  # the tool on the command line. It also has a set of formal flags and
  # command line arguments supported, and a block that gets run when the
  # tool is executed.
  #
  class ToolDefinition
    ##
    # A Completion that implements the default algorithm for a tool.
    #
    class DefaultCompletion < Completion::Base
      ##
      # Create a completion given configuration options.
      #
      # @param complete_subtools [true,false] Whether to complete subtool names
      # @param include_hidden_subtools [true,false] Whether to include hidden
      #     subtools (i.e. those beginning with an underscore)
      # @param complete_args [true,false] Whether to complete positional args
      # @param complete_flags [true,false] Whether to complete flag names
      # @param complete_flag_values [true,false] Whether to complete flag values
      # @param delegation_target [Array<String>,nil] Delegation target, or
      #     `nil` if none.
      #
      def initialize(complete_subtools: true, include_hidden_subtools: false,
                     complete_args: true, complete_flags: true, complete_flag_values: true,
                     delegation_target: nil)
        super()
        @complete_subtools = complete_subtools
        @include_hidden_subtools = include_hidden_subtools
        @complete_flags = complete_flags
        @complete_args = complete_args
        @complete_flag_values = complete_flag_values
        @delegation_target = delegation_target
      end

      ##
      # Whether to complete subtool names
      # @return [true,false]
      #
      def complete_subtools?
        @complete_subtools
      end

      ##
      # Whether to include hidden subtools
      # @return [true,false]
      #
      def include_hidden_subtools?
        @include_hidden_subtools
      end

      ##
      # Whether to complete flags
      # @return [true,false]
      #
      def complete_flags?
        @complete_flags
      end

      ##
      # Whether to complete positional args
      # @return [true,false]
      #
      def complete_args?
        @complete_args
      end

      ##
      # Whether to complete flag values
      # @return [true,false]
      #
      def complete_flag_values?
        @complete_flag_values
      end

      ##
      # Delegation target, or nil for none.
      # @return [Array<String>] if there is a delegation target
      # @return [nil] if there is no delegation target
      #
      attr_accessor :delegation_target

      ##
      # Returns candidates for the current completion.
      #
      # @param context [Toys::Completion::Context] the current completion
      #     context including the string fragment.
      # @return [Array<Toys::Completion::Candidate>] an array of candidates
      #
      def call(context)
        candidates = valued_flag_candidates(context)
        return candidates if candidates
        candidates = subtool_or_arg_candidates(context)
        candidates += plain_flag_candidates(context)
        candidates += flag_value_candidates(context)
        if delegation_target
          delegate_tool = context.cli.loader.lookup_specific(delegation_target)
          if delegate_tool
            context = context.with(previous_words: delegation_target)
            candidates += delegate_tool.completion.call(context)
          end
        end
        candidates
      end

      private

      def valued_flag_candidates(context)
        return unless @complete_flag_values
        arg_parser = context.arg_parser
        return unless arg_parser.flags_allowed?
        active_flag_def = arg_parser.active_flag_def
        return if active_flag_def && active_flag_def.value_type == :required
        match = /\A(--\w[?\w-]*)=(.*)\z/.match(context.fragment_prefix)
        return unless match
        flag_value_context = context.with(fragment_prefix: match[2])
        flag_def = flag_value_context.tool.resolve_flag(match[1]).unique_flag
        return [] unless flag_def
        flag_def.value_completion.call(flag_value_context)
      end

      def subtool_or_arg_candidates(context)
        return [] if context.arg_parser.active_flag_def
        return [] if context.arg_parser.flags_allowed? && context.fragment.start_with?("-")
        subtool_candidates(context) || arg_candidates(context)
      end

      def subtool_candidates(context)
        return if !@complete_subtools || !context.args.empty?
        tool_name, prefix, fragment = analyze_subtool_fragment(context)
        return unless tool_name
        subtools = context.cli.loader.list_subtools(tool_name,
                                                    include_namespaces: true,
                                                    include_hidden: @include_hidden_subtools,
                                                    include_non_runnable: @include_hidden_subtools)
        return if subtools.empty?
        candidates = []
        subtools.each do |subtool|
          name = subtool.simple_name
          candidates << Completion::Candidate.new("#{prefix}#{name}") if name.start_with?(fragment)
        end
        candidates
      end

      def analyze_subtool_fragment(context)
        tool_name = context.tool.full_name
        prefix = ""
        fragment = context.fragment
        delims = context.cli.extra_delimiters
        unless context.fragment_prefix.empty?
          if !context.fragment_prefix.end_with?(":") || !delims.include?(":")
            return [nil, nil, nil]
          end
          tool_name += context.fragment_prefix.split(":")
        end
        unless delims.empty?
          delims_regex = ::Regexp.escape(delims)
          if (match = /\A((.+)[#{delims_regex}])(.*)\z/.match(fragment))
            fragment = match[3]
            tool_name += match[2].split(/[#{delims_regex}]/)
            prefix = match[1]
          end
        end
        [tool_name, prefix, fragment]
      end

      def arg_candidates(context)
        return unless @complete_args
        arg_def = context.arg_parser.next_arg_def
        return [] unless arg_def
        arg_def.completion.call(context)
      end

      def plain_flag_candidates(context)
        return [] if !@complete_flags || context[:disable_flags]
        arg_parser = context.arg_parser
        return [] unless arg_parser.flags_allowed?
        flag_def = arg_parser.active_flag_def
        return [] if flag_def && flag_def.value_type == :required
        return [] if context.fragment =~ /\A[^-]/ || !context.fragment_prefix.empty?
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

    ##
    # Tool-based settings class.
    #
    # The following settings are supported:
    #
    #  *  `propagate_helper_methods` (_boolean_) - Whether subtools should
    #     inherit methods defined by parent tools. Defaults to `false`.
    #
    class Settings < ::Toys::Settings
      settings_attr :propagate_helper_methods, default: false
    end

    ##
    # Create a new tool.
    # Should be created only from the DSL via the Loader.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def initialize(parent, full_name, priority, source_root, middleware_stack, middleware_lookup,
                   tool_class = nil)
      @parent = parent
      @settings = Settings.new(parent: parent&.settings)
      @full_name = full_name.dup.freeze
      @priority = priority
      @source_root = source_root
      @built_middleware = middleware_stack.build(middleware_lookup)
      @subtool_middleware_stack = middleware_stack.dup

      @acceptors = {}
      @mixins = {}
      @templates = {}
      @completions = {}

      @precreated_class = tool_class

      reset_definition
    end

    ##
    # Reset the definition of this tool, deleting all definition data but
    # leaving named acceptors, mixins, and templates intact.
    # Should be called only from the DSL.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def reset_definition
      @tool_class = @precreated_class || create_class

      @source_info = nil
      @definition_finished = false

      @desc = WrappableString.new
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
      @require_exact_flag_match = false
      @includes_modules = false
      @custom_context_directory = nil

      @run_handler = :run
      @signal_handlers = {}
      @usage_error_handler = nil
      @delegate_target = nil

      @completion = DefaultCompletion.new
    end

    ##
    # Settings for this tool
    #
    # @return [Toys::Tool::Settings]
    #
    attr_reader :settings

    ##
    # The name of the tool as an array of strings.
    # This array may not be modified.
    #
    # @return [Array<String>]
    #
    attr_reader :full_name

    ##
    # The priority of this tool definition.
    #
    # @return [Integer]
    #
    attr_reader :priority

    ##
    # The root source info defining this tool, or nil if there is no source.
    #
    # @return [Toys::SourceInfo,nil]
    #
    attr_reader :source_root

    ##
    # The tool class.
    #
    # @return [Class]
    #
    attr_reader :tool_class

    ##
    # The short description string.
    #
    # When reading, this is always returned as a {Toys::WrappableString}.
    #
    # When setting, the description may be provided as any of the following:
    #  *  A {Toys::WrappableString}.
    #  *  A normal String, which will be transformed into a
    #     {Toys::WrappableString} using spaces as word delimiters.
    #  *  An Array of String, which will be transformed into a
    #     {Toys::WrappableString} where each array element represents an
    #     individual word for wrapping.
    #
    # @return [Toys::WrappableString]
    #
    attr_reader :desc

    ##
    # The long description strings.
    #
    # When reading, this is returned as an Array of {Toys::WrappableString}
    # representing the lines in the description.
    #
    # When setting, the description must be provided as an Array where *each
    # element* may be any of the following:
    #  *  A {Toys::WrappableString} representing one line.
    #  *  A normal String representing a line. This will be transformed into a
    #     {Toys::WrappableString} using spaces as word delimiters.
    #  *  An Array of String representing a line. This will be transformed into
    #     a {Toys::WrappableString} where each array element represents an
    #     individual word for wrapping.
    #
    # @return [Array<Toys::WrappableString>]
    #
    attr_reader :long_desc

    ##
    # A list of all defined flag groups, in order.
    #
    # @return [Array<Toys::FlagGroup>]
    #
    attr_reader :flag_groups

    ##
    # A list of all defined flags.
    #
    # @return [Array<Toys::Flag>]
    #
    attr_reader :flags

    ##
    # A list of all defined required positional arguments.
    #
    # @return [Array<Toys::PositionalArg>]
    #
    attr_reader :required_args

    ##
    # A list of all defined optional positional arguments.
    #
    # @return [Array<Toys::PositionalArg>]
    #
    attr_reader :optional_args

    ##
    # The remaining arguments specification.
    #
    # @return [Toys::PositionalArg] The argument definition
    # @return [nil] if remaining arguments are not supported by this tool.
    #
    attr_reader :remaining_arg

    ##
    # A list of flags that have been used in the flag definitions.
    #
    # @return [Array<String>]
    #
    attr_reader :used_flags

    ##
    # The default context data set by arguments.
    #
    # @return [Hash]
    #
    attr_reader :default_data

    ##
    # The stack of middleware specs used for subtools.
    #
    # This array may be modified in place.
    #
    # @return [Array<Toys::Middleware::Spec>]
    #
    attr_reader :subtool_middleware_stack

    ##
    # The stack of built middleware specs for this tool.
    #
    # @return [Array<Toys::Middleware>]
    #
    attr_reader :built_middleware

    ##
    # Info on the source of this tool.
    #
    # @return [Toys::SourceInfo] The source info
    # @return [nil] if the source is not defined.
    #
    attr_reader :source_info

    ##
    # The custom context directory set for this tool.
    #
    # @return [String] The directory path
    # @return [nil] if no custom context directory is set.
    #
    attr_reader :custom_context_directory

    ##
    # The completion strategy for this tool.
    #
    # When reading, this may return an instance of one of the subclasses of
    # {Toys::Completion::Base}, or a Proc that duck-types it. Generally, this
    # defaults to a {Toys::ToolDefinition::DefaultCompletion}, providing a
    # standard algorithm that finds appropriate completions from flags,
    # positional arguments, and subtools.
    #
    # When setting, you may pass any of the following:
    #  *  `nil` or `:default` which sets the value to a default instance.
    #  *  A Hash of options to pass to the
    #     {Toys::ToolDefinition::DefaultCompletion} constructor.
    #  *  Any other form recognized by {Toys::Completion.create}.
    #
    # @return [Toys::Completion::Base,Proc]
    #
    attr_reader :completion

    ##
    # The run handler.
    #
    # This handler is called to run the tool. Normally it is a method name,
    # represented by a symbol. (The default is `:run`.) It can be set to a
    # different method name, or to a proc that will be called with `self` set
    # to the tool context. Either way, it takes no arguments. The run handler
    # can also be explicitly set to `nil` indicating a non-runnable tool;
    # however, typically a tool is made non-runnable simply by leaving the run
    # handler set to `:run` and not defining the method.
    #
    # @return [Proc] if the run handler is defined as a Proc
    # @return [Symbol] if the run handler is defined as a method
    # @return [nil] if the tool is explicitly made non-runnable
    #
    attr_reader :run_handler

    ##
    # The usage error handler.
    #
    # This handler is called when at least one usage error is detected during
    # argument parsing, and is called instead of the `run` method. It can be
    # specified as a Proc, or a Symbol indicating a method to call. It
    # optionally takes an array of {Toys::ArgParser::UsageError} as the sole
    # argument.
    #
    # @return [Proc] if the usage error handler is defined as a Proc
    # @return [Symbol] if the user error handler is defined as a method
    # @return [nil] if there is no usage error handler
    #
    attr_reader :usage_error_handler

    ##
    # The full name of the delegate target, if any.
    #
    # @return [Array<String>] if this tool delegates
    # @return [nil] if this tool does not delegate
    #
    attr_reader :delegate_target

    ##
    # The local name of this tool, i.e. the last element of the full name.
    #
    # @return [String]
    #
    def simple_name
      full_name.last
    end

    ##
    # A displayable name of this tool, generally the full name delimited by
    # spaces.
    #
    # @return [String]
    #
    def display_name
      full_name.join(" ")
    end

    ##
    # Return the signal handler for the given signal.
    #
    # This handler is called when the given signal is received, immediately
    # taking over the execution as if it were the new run handler. The signal
    # handler can be specified as a Proc, or a Symbol indicating a method to
    # call. It optionally takes the `SignalException` as the sole argument.
    #
    # @param signal [Integer,String,Symbol] The signal number or name
    # @return [Proc] if the signal handler is defined as a Proc
    # @return [Symbol] if the signal handler is defined as a method
    # @return [nil] if there is no handler for the given signal
    #
    def signal_handler(signal)
      @signal_handlers[canonicalize_signal(signal)]
    end

    ##
    # Return the interrupt handler. This is equivalent to `signal_handler(2)`.
    #
    # @return [Proc] if the interrupt signal handler is defined as a Proc
    # @return [Symbol] if the interrupt signal handler is defined as a method
    # @return [nil] if there is no handler for the interrupt signals
    #
    def interrupt_handler
      signal_handler(2)
    end

    ##
    # Returns true if this tool is a root tool.
    # @return [true,false]
    #
    def root?
      full_name.empty?
    end

    ##
    # Returns true if this tool is marked as runnable.
    # @return [true,false]
    #
    def runnable?
      @run_handler.is_a?(::Symbol) &&
        tool_class.public_instance_methods(false).include?(@run_handler) ||
        @run_handler.is_a?(::Proc)
    end

    ##
    # Returns true if this tool handles interrupts. This is equivalent to
    # `handles_signal?(2)`.
    #
    # @return [true,false]
    #
    def handles_interrupts?
      handles_signal?(2)
    end

    ##
    # Returns true if this tool handles the given signal.
    #
    # @param signal [Integer,String,Symbol] The signal number or name
    # @return [true,false]
    #
    def handles_signal?(signal)
      signal = canonicalize_signal(signal)
      !@signal_handlers[signal].nil?
    end

    ##
    # Returns true if this tool handles usage errors.
    # @return [true,false]
    #
    def handles_usage_errors?
      !usage_error_handler.nil?
    end

    ##
    # Returns true if this tool has at least one included module.
    # @return [true,false]
    #
    def includes_modules?
      @includes_modules
    end

    ##
    # Returns true if there is a specific description set for this tool.
    # @return [true,false]
    #
    def includes_description?
      !long_desc.empty? || !desc.empty?
    end

    ##
    # Returns true if at least one flag or positional argument is defined
    # for this tool.
    # @return [true,false]
    #
    def includes_arguments?
      !default_data.empty? || !flags.empty? ||
        !required_args.empty? || !optional_args.empty? ||
        !remaining_arg.nil? || flags_before_args_enforced?
    end

    ##
    # Returns true if this tool has any definition information.
    # @return [true,false]
    #
    def includes_definition?
      includes_arguments? || runnable? || argument_parsing_disabled? ||
        includes_modules? || includes_description?
    end

    ##
    # Returns true if this tool's definition has been finished and is locked.
    # @return [true,false]
    #
    def definition_finished?
      @definition_finished
    end

    ##
    # Returns true if this tool has disabled argument parsing.
    # @return [true,false]
    #
    def argument_parsing_disabled?
      @disable_argument_parsing
    end

    ##
    # Returns true if this tool enforces flags before args.
    # @return [true,false]
    #
    def flags_before_args_enforced?
      @enforce_flags_before_args
    end

    ##
    # Returns true if this tool requires exact flag matches.
    # @return [true,false]
    #
    def exact_flag_match_required?
      @require_exact_flag_match
    end

    ##
    # All arg definitions in order: required, optional, remaining.
    #
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
    # @param str [String] Flag string
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
    # @param name [String] The acceptor name.
    # @return [Toys::Acceptor::Base] The acceptor.
    # @return [nil] if no acceptor of the given name is found.
    #
    def lookup_acceptor(name)
      @acceptors.fetch(name.to_s) { |k| @parent ? @parent.lookup_acceptor(k) : nil }
    end

    ##
    # Get the named template from this tool or its ancestors.
    #
    # @param name [String] The template name.
    # @return [Class,nil] The template class.
    # @return [nil] if no template of the given name is found.
    #
    def lookup_template(name)
      @templates.fetch(name.to_s) { |k| @parent ? @parent.lookup_template(k) : nil }
    end

    ##
    # Get the named mixin from this tool or its ancestors.
    #
    # @param name [String] The mixin name.
    # @return [Module] The mixin module.
    # @return [nil] if no mixin of the given name is found.
    #
    def lookup_mixin(name)
      @mixins.fetch(name.to_s) { |k| @parent ? @parent.lookup_mixin(k) : nil }
    end

    ##
    # Get the named completion from this tool or its ancestors.
    #
    # @param name [String] The completion name
    # @return [Toys::Completion::Base,Proc] The completion proc.
    # @return [nil] if no completion of the given name is found.
    #
    def lookup_completion(name)
      @completions.fetch(name.to_s) { |k| @parent ? @parent.lookup_completion(k) : nil }
    end

    ##
    # Include the given mixin in the tool class.
    #
    # The mixin must be given as a module. You can use {#lookup_mixin} to
    # resolve named mixins.
    #
    # @param mod [Module] The mixin module
    # @return [self]
    #
    def include_mixin(mod, *args, **kwargs)
      check_definition_state
      if tool_class.included_modules.include?(mod)
        raise ToolDefinitionError, "Mixin already included: #{mod.name}"
      end
      @includes_modules = true
      if tool_class.respond_to?(:super_include)
        tool_class.super_include(mod)
      else
        tool_class.include(mod)
      end
      if mod.respond_to?(:initializer)
        callback = mod.initializer
        add_initializer(callback, *args, **kwargs) if callback
      end
      if mod.respond_to?(:inclusion)
        callback = mod.inclusion
        tool_class.class_exec(*args, **kwargs, &callback) if callback
      end
      self
    end

    ##
    # Sets the path to the file that defines this tool.
    # A tool may be defined from at most one path. If a different path is
    # already set, it is left unchanged.
    #
    # @param source [Toys::SourceInfo] Source info
    # @return [self]
    #
    def lock_source(source)
      @source_info ||= source
      self
    end

    ##
    # Set the short description string.
    #
    # See {#desc} for details.
    #
    # @param desc [Toys::WrappableString,String,Array<String>]
    #
    def desc=(desc)
      check_definition_state
      @desc = WrappableString.make(desc)
    end

    ##
    # Set the long description strings.
    #
    # See {#long_desc} for details.
    #
    # @param long_desc [Array<Toys::WrappableString,String,Array<String>>]
    #
    def long_desc=(long_desc)
      check_definition_state
      @long_desc = WrappableString.make_array(long_desc)
    end

    ##
    # Append long description strings.
    #
    # You must pass an array of lines in the long description. See {#long_desc}
    # for details on how each line may be represented.
    #
    # @param long_desc [Array<Toys::WrappableString,String,Array<String>>]
    # @return [self]
    #
    def append_long_desc(long_desc)
      check_definition_state
      @long_desc.concat(WrappableString.make_array(long_desc))
      self
    end

    ##
    # Add a named acceptor to the tool. This acceptor may be refereneced by
    # name when adding a flag or an arg. See {Toys::Acceptor.create} for
    # detailed information on how to specify an acceptor.
    #
    # @param name [String] The name of the acceptor.
    # @param acceptor [Toys::Acceptor::Base,Object] The acceptor to add. You
    #     can provide either an acceptor object, or a spec understood by
    #     {Toys::Acceptor.create}.
    # @param type_desc [String] Type description string, shown in help.
    #     Defaults to the acceptor name.
    # @param block [Proc] Optional block used to create an acceptor. See
    #     {Toys::Acceptor.create}.
    # @return [self]
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
    # @param name [String] The name of the mixin.
    # @param mixin_module [Module] The mixin module.
    # @param block [Proc] Define the mixin module here if a `mixin_module` is
    #     not provided directly.
    # @return [self]
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
    # @param name [String] The name of the completion.
    # @param completion [Proc,Toys::Completion::Base,Object] The completion to
    #     add. You can provide either a completion object, or a spec understood
    #     by {Toys::Completion.create}.
    # @param options [Hash] Additional options to pass to the completion.
    # @param block [Proc] Optional block used to create a completion. See
    #     {Toys::Completion.create}.
    # @return [self]
    #
    def add_completion(name, completion = nil, **options, &block)
      name = name.to_s
      if @completions.key?(name)
        raise ToolDefinitionError,
              "A completion named #{name.inspect} has already been defined in tool" \
              " #{display_name.inspect}."
      end
      @completions[name] = Toys::Completion.create(completion, **options, &block)
      self
    end

    ##
    # Add a named template class to this tool.
    # You may provide a template class or a block that configures one.
    #
    # @param name [String] The name of the template.
    # @param template_class [Class] The template class.
    # @param block [Proc] Define the template class here if a `template_class`
    #     is not provided directly.
    # @return [self]
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
    # @return [self]
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
    #
    # @param state [true,false]
    # @return [self]
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
    # Require that flags must match exactly. (If false, flags can match an
    # unambiguous substring.)
    #
    # @param state [true,false]
    # @return [self]
    #
    def require_exact_flag_match(state = true)
      check_definition_state
      if argument_parsing_disabled?
        raise ToolDefinitionError,
              "Cannot require exact flag match for tool" \
              " #{display_name.inspect} because parsing is disabled."
      end
      @require_exact_flag_match = state
      self
    end

    ##
    # Add a flag group to the group list.
    #
    # The type should be one of the following symbols:
    #  *  `:optional` All flags in the group are optional
    #  *  `:required` All flags in the group are required
    #  *  `:exactly_one` Exactly one flag in the group must be provided
    #  *  `:at_least_one` At least one flag in the group must be provided
    #  *  `:at_most_one` At most one flag in the group must be provided
    #
    # @param type [Symbol] The type of group. Default is `:optional`.
    # @param desc [String,Array<String>,Toys::WrappableString] Short
    #     description for the group. See {Toys::ToolDefinition#desc} for a
    #     description of allowed formats. Defaults to `"Flags"`.
    # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
    #     Long description for the flag group. See
    #     {Toys::ToolDefinition#long_desc} for a description of allowed
    #     formats. Defaults to the empty array.
    # @param name [String,Symbol,nil] The name of the group, or nil for no
    #     name.
    # @param report_collisions [true,false] If `true`, raise an exception if a
    #     the given name is already taken. If `false`, ignore. Default is
    #     `true`.
    # @param prepend [true,false] If `true`, prepend rather than append the
    #     group to the list. Default is `false`.
    # @return [self]
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
    # @param key [String,Symbol] The key to use to retrieve the value from
    #     the execution context.
    # @param flags [Array<String>] The flags in OptionParser format. If empty,
    #     a flag will be inferred from the key.
    # @param accept [Object] An acceptor that validates and/or converts the
    #     value. You may provide either the name of an acceptor you have
    #     defined, or one of the default acceptors provided by OptionParser.
    #     Optional. If not specified, accepts any value as a string.
    # @param default [Object] The default value. This is the value that will
    #     be set in the context if this flag is not provided on the command
    #     line. Defaults to `nil`.
    # @param handler [Proc,nil,:set,:push] An optional handler for
    #     setting/updating the value. A handler is a proc taking two
    #     arguments, the given value and the previous value, returning the
    #     new value that should be set. You may also specify a predefined
    #     named handler. The `:set` handler (the default) replaces the
    #     previous value (effectively `-> (val, _prev) { val }`). The
    #     `:push` handler expects the previous value to be an array and
    #     pushes the given value onto it; it should be combined with setting
    #     `default: []` and is intended for "multi-valued" flags.
    # @param complete_flags [Object] A specifier for shell tab completion
    #     for flag names associated with this flag. By default, a
    #     {Toys::Flag::DefaultCompletion} is used, which provides the flag's
    #     names as completion candidates. To customize completion, set this to
    #     a hash of options to pass to the constructor for
    #     {Toys::Flag::DefaultCompletion}, or pass any other spec recognized
    #     by {Toys::Completion.create}.
    # @param complete_values [Object] A specifier for shell tab completion
    #     for flag values associated with this flag. Pass any spec
    #     recognized by {Toys::Completion.create}.
    # @param report_collisions [true,false] Raise an exception if a flag is
    #     requested that is already in use or marked as disabled. Default is
    #     true.
    # @param group [Toys::FlagGroup,String,Symbol,nil] Group for
    #     this flag. You may provide a group name, a FlagGroup object, or
    #     `nil` which denotes the default group.
    # @param desc [String,Array<String>,Toys::WrappableString] Short
    #     description for the flag. See {Toys::ToolDefinition#desc} for a
    #     description of allowed formats. Defaults to the empty string.
    # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
    #     Long description for the flag. See {Toys::ToolDefinition#long_desc}
    #     for a description of allowed formats. Defaults to the empty array.
    # @param display_name [String] A display name for this flag, used in help
    #     text and error messages.
    # @return [self]
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
    # @param flags [String...] The flags to disable
    # @return [self]
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
    # @param key [String,Symbol] The key to use to retrieve the value from
    #     the execution context.
    # @param accept [Object] An acceptor that validates and/or converts the
    #     value. You may provide either the name of an acceptor you have
    #     defined, or one of the default acceptors provided by OptionParser.
    #     Optional. If not specified, accepts any value as a string.
    # @param complete [Object] A specifier for shell tab completion. See
    #     {Toys::Completion.create} for recognized formats.
    # @param display_name [String] A name to use for display (in help text and
    #     error reports). Defaults to the key in upper case.
    # @param desc [String,Array<String>,Toys::WrappableString] Short
    #     description for the arg. See {Toys::ToolDefinition#desc} for a
    #     description of allowed formats. Defaults to the empty string.
    # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
    #     Long description for the arg. See {Toys::ToolDefinition#long_desc}
    #     for a description of allowed formats. Defaults to the empty array.
    # @return [self]
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
    # @param key [String,Symbol] The key to use to retrieve the value from
    #     the execution context.
    # @param default [Object] The default value. This is the value that will
    #     be set in the context if this argument is not provided on the command
    #     line. Defaults to `nil`.
    # @param accept [Object] An acceptor that validates and/or converts the
    #     value. You may provide either the name of an acceptor you have
    #     defined, or one of the default acceptors provided by OptionParser.
    #     Optional. If not specified, accepts any value as a string.
    # @param complete [Object] A specifier for shell tab completion. See
    #     {Toys::Completion.create} for recognized formats.
    # @param display_name [String] A name to use for display (in help text and
    #     error reports). Defaults to the key in upper case.
    # @param desc [String,Array<String>,Toys::WrappableString] Short
    #     description for the arg. See {Toys::ToolDefinition#desc} for a
    #     description of allowed formats. Defaults to the empty string.
    # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
    #     Long description for the arg. See {Toys::ToolDefinition#long_desc}
    #     for a description of allowed formats. Defaults to the empty array.
    # @return [self]
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
    # @param key [String,Symbol] The key to use to retrieve the value from
    #     the execution context.
    # @param default [Object] The default value. This is the value that will
    #     be set in the context if no unmatched arguments are provided on the
    #     command line. Defaults to the empty array `[]`.
    # @param accept [Object] An acceptor that validates and/or converts the
    #     value. You may provide either the name of an acceptor you have
    #     defined, or one of the default acceptors provided by OptionParser.
    #     Optional. If not specified, accepts any value as a string.
    # @param complete [Object] A specifier for shell tab completion. See
    #     {Toys::Completion.create} for recognized formats.
    # @param display_name [String] A name to use for display (in help text and
    #     error reports). Defaults to the key in upper case.
    # @param desc [String,Array<String>,Toys::WrappableString] Short
    #     description for the arg. See {Toys::ToolDefinition#desc} for a
    #     description of allowed formats. Defaults to the empty string.
    # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
    #     Long description for the arg. See {Toys::ToolDefinition#long_desc}
    #     for a description of allowed formats. Defaults to the empty array.
    # @return [self]
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
    # Set the run handler.
    #
    # This handler is called to run the tool. Normally it is a method name,
    # represented by a symbol. (The default is `:run`.) It can be set to a
    # different method name, or to a proc that will be called with `self` set
    # to the tool context. Either way, it takes no arguments. The run handler
    # can also be explicitly set to `nil` indicating a non-runnable tool;
    # however, typically a tool is made non-runnable simply by leaving the run
    # handler set to `:run` and not defining the method.
    #
    # @param handler [Proc,Symbol,nil] the run handler
    #
    def run_handler=(handler)
      check_definition_state(is_method: true)
      if !handler.is_a?(::Proc) && !handler.is_a?(::Symbol) && !handler.nil?
        raise ToolDefinitionError, "Run handler must be a proc or symbol"
      end
      @run_handler = handler
    end

    ##
    # Set the interrupt handler. This is equivalent to calling
    # {#set_signal_handler} for the `SIGINT` signal.
    #
    # @param handler [Proc,Symbol] The interrupt signal handler
    #
    def interrupt_handler=(handler)
      set_signal_handler(2, handler)
    end

    ##
    # Set the handler for the given signal.
    #
    # This handler is called when the given signal is received, immediately
    # taking over the execution as if it were the new `run` method. The signal
    # handler can be specified as a Proc, or a Symbol indicating a method to
    # call. It optionally takes the `SignalException` as the sole argument.
    #
    # @param signal [Integer,String,Symbol] The signal number or name
    # @param handler [Proc,Symbol] The signal handler
    #
    def set_signal_handler(signal, handler)
      check_definition_state(is_method: true)
      if !handler.is_a?(::Proc) && !handler.is_a?(::Symbol) && !handler.nil?
        raise ToolDefinitionError, "Signal handler must be a proc or symbol"
      end
      signal = canonicalize_signal(signal)
      @signal_handlers[signal] = handler
    end

    ##
    # Set the usage error handler.
    #
    # This handler is called when at least one usage error is detected during
    # argument parsing, and is called instead of the `run` method. It can be
    # specified as a Proc, or a Symbol indicating a method to call. It
    # optionally takes an array of {Toys::ArgParser::UsageError} as the sole
    # argument.
    #
    # @param handler [Proc,Symbol] The usage error handler
    #
    def usage_error_handler=(handler)
      check_definition_state(is_method: true)
      if !handler.is_a?(::Proc) && !handler.is_a?(::Symbol) && !handler.nil?
        raise ToolDefinitionError, "Usage error handler must be a proc or symbol"
      end
      @usage_error_handler = handler
    end

    ##
    # Add an initializer.
    #
    # @param proc [Proc] The initializer block
    # @param args [Object...] Arguments to pass to the initializer
    # @param kwargs [keywords] Keyword arguments to pass to the initializer
    # @return [self]
    #
    def add_initializer(proc, *args, **kwargs)
      check_definition_state
      @initializers << [proc, args, kwargs]
      self
    end

    ##
    # Set the custom context directory.
    #
    # See {#custom_context_directory} for details.
    #
    # @param dir [String]
    #
    def custom_context_directory=(dir)
      check_definition_state
      @custom_context_directory = dir
    end

    ##
    # Set the completion strategy for this ToolDefinition.
    #
    # See {#completion} for details.
    #
    # @param spec [Object]
    #
    def completion=(spec)
      spec = resolve_completion_name(spec)
      spec =
        case spec
        when nil, :default
          DefaultCompletion
        when ::Hash
          spec[:""].nil? ? spec.merge({"": DefaultCompletion}) : spec
        else
          spec
        end
      @completion = Completion.create(spec, **{})
    end

    ##
    # Return the effective context directory.
    # If there is a custom context directory, uses that. Otherwise, looks for
    # a custom context directory up the tool ancestor chain. If none is
    # found, uses the default context directory from the source info. It is
    # possible for there to be no context directory at all, in which case,
    # returns nil.
    #
    # @return [String] The effective context directory path.
    # @return [nil] if there is no effective context directory.
    #
    def context_directory
      lookup_custom_context_directory || source_info&.context_directory
    end

    ##
    # Causes this tool to delegate to another tool.
    #
    # @param target [Array<String>] The full path to the delegate tool.
    # @return [self]
    #
    def delegate_to(target)
      if @delegate_target
        return self if target == @delegate_target
        raise ToolDefinitionError,
              "Cannot delegate tool #{display_name.inspect} to #{target.join(' ')} because it" \
              " already delegates to \"#{@delegate_target.join(' ')}\"."
      end
      if includes_arguments?
        raise ToolDefinitionError,
              "Cannot delegate tool #{display_name.inspect} because" \
              " arguments have already been defined."
      end
      if runnable?
        raise ToolDefinitionError,
              "Cannot delegate tool #{display_name.inspect} because" \
              " the run method has already been defined."
      end
      disable_argument_parsing
      self.run_handler = make_delegation_run_handler(target)
      self.completion = DefaultCompletion.new(delegation_target: target)
      @delegate_target = target
      self
    end

    ##
    # Lookup the custom context directory in this tool and its ancestors.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def lookup_custom_context_directory
      custom_context_directory || @parent&.lookup_custom_context_directory
    end

    ##
    # Mark this tool as having at least one module included.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def mark_includes_modules
      check_definition_state
      @includes_modules = true
      self
    end

    ##
    # Complete definition and run middleware configs. Should be called from
    # the Loader only.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def finish_definition(loader)
      unless @definition_finished
        ContextualError.capture("Error installing tool middleware!", tool_name: full_name) do
          config_proc = proc { nil }
          @built_middleware.reverse_each do |middleware|
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
    #
    # @private This interface is internal and subject to change without warning.
    #
    def run_initializers(context)
      @initializers.each do |func, args, kwargs|
        context.instance_exec(*args, **kwargs, &func)
      end
    end

    ##
    # Check that the tool can still be defined. Should be called internally
    # or from the DSL only.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def check_definition_state(is_arg: false, is_method: false)
      if @definition_finished
        raise ToolDefinitionError,
              "Defintion of tool #{display_name.inspect} is already finished"
      end
      if is_arg && argument_parsing_disabled?
        raise ToolDefinitionError,
              "Tool #{display_name.inspect} has disabled argument parsing"
      end
      if (is_arg || is_method) && delegate_target
        raise ToolDefinitionError,
              "Tool #{display_name.inspect} is already delegating to another tool"
      end
      self
    end

    private

    def create_class
      ::Class.new(@parent&.settings&.propagate_helper_methods ? @parent.tool_class : ::Toys::Context)
    end

    def make_config_proc(middleware, loader, next_config)
      if middleware.respond_to?(:config)
        proc { middleware.config(self, loader, &next_config) }
      else
        next_config
      end
    end

    def make_delegation_run_handler(target)
      lambda do
        path = [target.join(" ").inspect]
        walk_context = self
        until walk_context.nil?
          name = walk_context[::Toys::Context::Key::TOOL_NAME]
          path << name.join(" ").inspect
          if name == target
            raise ToolDefinitionError, "Delegation loop: #{path.join(' <- ')}"
          end
          walk_context = walk_context[::Toys::Context::Key::DELEGATED_FROM]
        end
        cli = self[::Toys::Context::Key::CLI]
        cli.loader.load_for_prefix(target)
        unless cli.loader.tool_defined?(target)
          raise ToolDefinitionError, "Delegate target not found: \"#{target.join(' ')}\""
        end
        exit(cli.run(target + self[::Toys::Context::Key::ARGS], delegated_from: self))
      end
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

    def canonicalize_signal(signal)
      case signal
      when ::String, ::Symbol
        sigstr = signal.to_s
        sigstr = sigstr[3..-1] if sigstr.start_with?("SIG")
        signo = ::Signal.list[sigstr]
        return signo if signo
      when ::Integer
        return signal if ::Signal.signame(signal)
      end
      raise ::ArgumentError, "Unknown signal: #{signal}"
    end
  end
end
