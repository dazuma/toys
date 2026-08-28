# frozen_string_literal: true

require "logger"

module Toys
  ##
  # An object that runs tools.
  #
  # A Runner holds the environment in which tools run. This includes the
  # {Toys::Loader} that resolves a tool name to a tool definition, along with
  # run policy such as how to obtain a logger for a tool and what to do with an
  # error the tool did not handle. This environment is fixed when the Runner is
  # constructed.
  #
  # Everything specific to a single invocation, such as which tool to run and
  # the arguments to pass to it, is passed to {#run}. A Runner is thus itself
  # immutable and holds no per-run state, so one Runner can run any number of
  # tools and is safe to share. This says nothing about the tools it runs,
  # however; running two tools at the same time is safe only if the tools
  # themselves are, since a tool can modify global state such as the load path
  # or a shared logger. See the `logger` parameter of {Toys::CLI#initialize}
  # for one such caveat.
  #
  # The Runner that is running a tool is available to that tool as
  # {Toys::Context#runner}, so a tool can use it to run a sibling tool in the
  # same process. For example:
  #
  #     # My .toys.rb
  #     tool "foo" do
  #       def run
  #         puts "in foo"
  #       end
  #     end
  #     tool "bar" do
  #       def run
  #         puts "in bar"
  #         runner.run(["foo"])
  #       end
  #     end
  #
  class Runner
    ##
    # The singleton default logger_factory Proc, which simply returns a new
    # logger writing to the current stderr.
    #
    # @return [Proc]
    #
    DEFAULT_LOGGER_FACTORY = proc { |_tool|
      logger = ::Logger.new($stderr)
      logger.level = ::Logger::WARN
      logger
    }.freeze

    ##
    # The singleton default error_handler Proc, which simply reraises the error
    # it is given. A {Toys::ContextualError} is reraised as itself, so that a
    # rescue block has access to the context information. An unhandled
    # `SignalException` (or a subclass such as `Interrupt`) is also reraised as
    # itself, so that the Ruby VM has a chance to handle it normally.
    #
    # @return [Proc]
    #
    DEFAULT_ERROR_HANDLER = proc { |error|
      raise(error)
    }.freeze

    ##
    # Create a Runner.
    #
    # This performs no I/O and raises nothing. Tools are looked up, loaded, and
    # run only when {#run} is called.
    #
    # @param loader [Toys::Loader] The loader used to look up tools.
    # @param logger_factory [Proc,nil] A proc that takes a
    #     {Toys::ToolDefinition} as an argument, and returns a logger to use
    #     when running that tool. If not given,
    #     {Toys::Runner::DEFAULT_LOGGER_FACTORY} is used.
    # @param base_level [Integer,nil] The logger level that corresponds to zero
    #     verbosity. If not provided, the level the logger has before a run
    #     adjusts it is used (typically Logger::WARN). A run nested inside
    #     another run that shares the same logger uses the base level already
    #     in effect for that logger, so that verbosity does not compound.
    # @param error_handler [Proc,nil] A proc that is called when an unhandled
    #     exception is detected during a run that has error handling enabled.
    #     The proc takes the error as its sole argument, and should report it.
    #     It could simply reraise the exception, or it could display an error
    #     message and/or return an exit code (normally nonzero) appropriate to
    #     the error. The error is one of the following:
    #
    #     *  a {Toys::ContextualError}, wrapping a `StandardError`, a
    #        `ScriptError`, or a nested {Toys::ContextualError}
    #     *  a bare `StandardError` or `ScriptError`, if the run disabled error
    #        wrapping
    #     *  a bare `SignalException`, which is never wrapped
    #
    #     Optional. If not given, {Toys::Runner::DEFAULT_ERROR_HANDLER} is
    #     used.
    # @param executable_name [String,nil] The executable name displayed in help
    #     text. Optional. Defaults to the ruby program name.
    # @param external_data [Hash] Additional context data provided by the
    #     caller. It is merged underneath the data the Runner provides itself,
    #     so it cannot override runtime-owned keys.
    #
    def initialize(loader,
                   logger_factory: nil,
                   base_level: nil,
                   error_handler: nil,
                   executable_name: nil,
                   external_data: {})
      @loader = loader
      @logger_factory = logger_factory || DEFAULT_LOGGER_FACTORY
      @base_level = base_level
      @error_handler = error_handler || DEFAULT_ERROR_HANDLER
      @executable_name = executable_name || ::File.basename($PROGRAM_NAME)
      @external_data = external_data
    end

    ##
    # Run a tool.
    #
    # The tool is looked up by matching a tool name at the beginning of the
    # given arguments. The remaining arguments are then parsed into a
    # {Toys::Context}, the tool's middleware is applied, and the tool is run.
    #
    # If a block is passed, the runtime context is simply yielded to it in
    # place of the tool's run handler, with the tool's middleware still
    # applied. This is useful for testing parts of the tool runtime in
    # isolation.
    #
    # If the tool raises a `SignalException` that it does not handle itself,
    # that exception propagates unwrapped, even when `wrap_errors` is enabled.
    # This lets each tool in a nested execution dispatch it to its own
    # `on_interrupt` or `on_signal` handler, and lets the error handler, and
    # ultimately the Ruby VM, recognize it as a signal.
    #
    # @param args [Array<String>] The command line arguments, including the
    #     name of the tool to look up. This must be an array of strings; it is
    #     an error to pass anything else.
    # @param verbosity [Integer] Initial verbosity. Default is 0.
    # @param wrap_errors [boolean] If true (the default), wrap errors in
    #     {Toys::ContextualError}, including errors during the tool lookup,
    #     argument parsing, and tool execution. If false, propagate errors
    #     as-is and do not wrap them. A `SignalException` is never wrapped
    #     regardless of this setting; see above.
    # @param handle_errors [boolean] If true (the default), pass any error
    #     that reaches the end of the run to this Runner's error handler, and
    #     return the exit code it produces. If false, let the error propagate
    #     out of this method. A `SystemExit` is never passed to the error
    #     handler regardless of this setting, so `Kernel.exit` in a tool still
    #     exits the process.
    #
    # @yieldparam context [Toys::Context] If a block is given, it is invoked in
    #     place of the tool's run handler, with the tool's middleware still
    #     applied. This is intended for testing tools.
    #
    # @return [Integer] The resulting process status code (i.e. 0 for success).
    # @raise [ArgumentError] if `args` is not an array. Note that
    #     {Toys::CLI#run}, unlike this method, takes its arguments as a splat.
    #
    def run(args, verbosity: 0, wrap_errors: true, handle_errors: true, &block)
      unless args.is_a?(::Array)
        raise ::ArgumentError, "Tool arguments must be an array of strings: #{args.inspect}"
      end
      Invocation.new(runner: self,
                     args: args,
                     verbosity: verbosity,
                     wrap_errors: wrap_errors,
                     handle_errors: handle_errors,
                     delegated_from: nil,
                     block: block).run
    end

    #### INTERNAL METHODS ####

    ##
    # The loader used to look up tools.
    #
    # @private This interface is internal and subject to change without warning.
    #
    attr_reader :loader

    ##
    # The proc that provides a logger for a tool.
    #
    # @private This interface is internal and subject to change without warning.
    #
    attr_reader :logger_factory

    ##
    # The logger level corresponding to zero verbosity, or nil to use the level
    # already in effect.
    #
    # @private This interface is internal and subject to change without warning.
    #
    attr_reader :base_level

    ##
    # The proc that reports an unhandled error.
    #
    # @private This interface is internal and subject to change without warning.
    #
    attr_reader :error_handler

    ##
    # The executable name displayed in help text.
    #
    # @private This interface is internal and subject to change without warning.
    #
    attr_reader :executable_name

    ##
    # Additional context data provided by the caller.
    #
    # @private This interface is internal and subject to change without warning.
    #
    attr_reader :external_data

    ##
    # A single invocation of a tool by a {Toys::Runner}. It holds the values
    # that are specific to one run, alongside the environment copied from the
    # Runner, and carries out the run. An Invocation is used once and
    # discarded.
    #
    # @private
    #
    class Invocation
      ##
      # Create an invocation. The environment is copied from the given Runner,
      # and the remaining arguments are specific to this one run. Copying the
      # environment here, rather than at each call site, keeps a delegated
      # invocation from silently diverging from the Runner that produced it.
      #
      # @private
      #
      def initialize(runner:,
                     args:,
                     verbosity:,
                     wrap_errors:,
                     handle_errors:,
                     delegated_from:,
                     block:)
        @runner = runner
        @loader = runner.loader
        @logger_factory = runner.logger_factory
        @base_level = runner.base_level
        @error_handler = runner.error_handler
        @executable_name = runner.executable_name
        @external_data = runner.external_data
        @args = args
        @verbosity = verbosity.to_i
        @wrap_errors = wrap_errors
        @handle_errors = handle_errors
        @delegated_from = delegated_from
        @block = block
      end

      ##
      # Perform the invocation, and return the resulting process status code.
      # This looks up the tool, builds its context, and invokes it within its
      # middleware stack, wrapping errors from each phase and dispatching any
      # error that reaches the end to the error handler, if requested.
      #
      # @private
      #
      def run
        return run_tool unless @handle_errors
        begin
          run_tool
        rescue ::StandardError, ::ScriptError, ::SignalException => e
          @error_handler.call(e).to_i
        end
      end

      private

      # Looks up the tool and runs it, without any error handling.
      def run_tool
        lookup_tool
        execute
      end

      # Looks up the tool named at the beginning of the arguments, and records
      # it along with the arguments remaining after the name was consumed.
      def lookup_tool
        @tool, @tool_args =
          if @wrap_errors
            ContextualError.capture(banner: "Error finding tool definition", final: true) do
              @loader.lookup(@args)
            end
          else
            @loader.lookup(@args)
          end
      end

      # Builds the context and runs the tool within it, wrapping any error in a
      # finalized ContextualError tagged with the tool's identity.
      def execute
        return execute_internal unless @wrap_errors
        ContextualError.capture(
          banner: "Error during tool execution",
          path: @tool.source_info&.source_path,
          tool_name: @tool.full_name, tool_args: @tool_args,
          final: true
        ) do
          execute_internal
        end
      end

      # Builds the context and runs the tool within it, without any error
      # wrapping. See {#execute}.
      def execute_internal
        context = build_context
        block = @block || make_run_handler
        execute_tool(context, &block)
      end

      # Parses the command line arguments against the tool's flag and positional
      # definitions, and builds the tool's runtime context from the result. Any
      # argument errors are recorded in the context as usage errors, to be
      # handled later during execution.
      def build_context
        common_data = {
          Context::Key::CONTEXT_DIRECTORY => @tool.context_directory || ::Dir.getwd,
          Context::Key::DELEGATED_FROM => @delegated_from,
          Context::Key::EXECUTABLE_NAME => @executable_name,
          Context::Key::LOADER => @loader,
          Context::Key::LOGGER => @logger_factory.call(@tool),
          Context::Key::RUNNER => @runner,
          Context::Key::TOOL => @tool,
          Context::Key::TOOL_NAME => @tool.full_name,
          Context::Key::TOOL_SOURCE => @tool.source_info,
          Context::Key::VERBOSITY => @verbosity,
        }
        common_data = @external_data.merge(common_data)
        arg_parser = ArgParser.new(@tool, @loader,
                                   common_data: common_data,
                                   require_exact_flag_match: @tool.exact_flag_match_required?)
        arg_parser.parse(@tool_args).finish
        @tool.tool_class.new(arg_parser.data)
      end

      # Returns a proc that invokes the tool's run handler on a context. The
      # handler may be a method name, the name of a delegate target, or a proc to
      # execute against the context.
      def make_run_handler
        run_handler = @tool.run_handler
        case run_handler
        when ::Symbol
          proc do |context|
            context.send(run_handler)
          end
        when ::Array
          proc do |context|
            run_delegation(context, run_handler)
          end
        else
          proc do |context|
            context.instance_exec(&run_handler)
          end
        end
      end

      # Runs the delegate target of a delegating tool. The tool's run handler is
      # the full name of the target, and the current context is passed along as
      # the delegating context. The delegated run inherits this invocation's
      # environment and settings, but never the block.
      def run_delegation(context, target)
        target_str = target.join(" ").inspect
        path = [target_str]
        walk_context = context
        until walk_context.nil?
          name = walk_context[Context::Key::TOOL_NAME]
          path << name.join(" ").inspect
          raise ToolDefinitionError, "Delegation loop: #{path.join(' <- ')}" if name == target
          walk_context = walk_context[Context::Key::DELEGATED_FROM]
        end
        @loader.load_for_prefix(target)
        raise ToolDefinitionError, "Delegate target not found: #{target_str}" unless @loader.tool_defined?(target)
        # We don't lookup_specific the target directly, but allow the Loader to
        # re-lookup with the args, so that target can point to a namespace and
        # we can load a tool under it.
        #
        # Uses Context.exit rather than context.exit because a tool is allowed to
        # override the exit method, and this control flow must not be intercepted.
        Context.exit(delegated_invocation(target + @tool_args, context).run)
      end

      # Builds the invocation that runs a delegate target. It takes its
      # environment from the same Runner, and copies this invocation's
      # settings. Error handling is always disabled for the delegate, so that
      # the error handler fires once, at the outermost run only.
      def delegated_invocation(args, context)
        Invocation.new(runner: @runner,
                       args: args,
                       verbosity: @verbosity,
                       wrap_errors: @wrap_errors,
                       handle_errors: false,
                       delegated_from: context,
                       block: nil)
      end

      # Prepares the runtime environment for the tool, applying lib paths and
      # initializers, and then calls the tool within its middleware stack and
      # within the logger level implied by the verbosity, returning the
      # resulting exit code.
      def execute_tool(context, &block)
        @tool.source_info&.find_lib_paths&.reverse_each do |path|
          $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
        end
        @tool.run_initializers(context)
        with_logger_level(context) do
          executor = build_executor(context, &block)
          catch(:result) do
            executor.call
            0
          end
        end
      end

      # Sets the logger level implied by the verbosity for the duration of the
      # block, and restores it, along with the base level in effect for it,
      # afterward. The restoration must cover the level assignment itself,
      # because a base level that cannot be combined with the verbosity fails
      # there, and a base level left recorded behind a failed run would be
      # picked up by later runs sharing the logger. Yields directly if the tool
      # has no logger.
      def with_logger_level(context)
        cur_logger = context[Context::Key::LOGGER]
        return yield unless cur_logger
        original_level = cur_logger.level
        base_level = @base_level || base_levels[cur_logger] || original_level
        saved_base_level = set_base_level(cur_logger, base_level)
        begin
          cur_logger.level = base_level - context[Context::Key::VERBOSITY].to_i
          yield
        ensure
          set_base_level(cur_logger, saved_base_level)
          cur_logger.level = original_level
        end
      end

      # The base levels currently in effect on this thread, keyed by logger
      # identity. A run that adjusts a logger's level records the base
      # level it used, for the extent of that run, because a nested run cannot
      # recover it from a shared logger: the level it would find there is the
      # enclosing run's already adjusted level, which would make verbosity
      # compound. The record is per-thread because it describes the loggers this
      # thread is actively adjusting.
      def base_levels
        thread = ::Thread.current
        thread.thread_variable_get(:toys_base_levels) ||
          thread.thread_variable_set(:toys_base_levels, {}.compare_by_identity)
      end

      # Records the base level in effect for the given logger, or clears it if
      # the level is nil, and returns the level previously in effect. The caller
      # must restore that previous level when its run finishes.
      def set_base_level(logger, level)
        levels = base_levels
        previous = levels[logger]
        if level
          levels[logger] = level
        else
          levels.delete(logger)
        end
        previous
      end

      # Builds the callable that runs the tool. The innermost proc checks for
      # usage errors and for a missing implementation before invoking the given
      # block, and catches any signal raised by the tool. That proc is then
      # wrapped in the tool's middleware in reverse order, so that the first
      # middleware in the list ends up outermost.
      def build_executor(context)
        executor = proc do
          if !context[Context::Key::USAGE_ERRORS].empty?
            handle_usage_errors(context)
          elsif !@tool.runnable?
            raise NotRunnableError, "No implementation for tool #{@tool.display_name.inspect}"
          else
            yield context
          end
        rescue ::SignalException => e
          handle_signal_by_tool(context, e)
        end
        @tool.built_middleware.reverse_each do |middleware|
          executor = make_executor(middleware, context, executor)
        end
        executor
      end

      # Dispatches the usage errors recorded during argument parsing to the
      # tool's usage error handler. If the tool has no handler, the errors are
      # raised instead.
      def handle_usage_errors(context)
        usage_errors = context[Context::Key::USAGE_ERRORS]
        handler = @tool.usage_error_handler
        raise ArgParsingError, usage_errors if handler.nil?
        call_handler(context, handler, usage_errors)
      end

      # Dispatches a signal raised by the tool to the tool's handler for that
      # signal, if any, or reraises it otherwise. A different signal raised by
      # the handler itself is dispatched in turn, but the same signal reraised by
      # its own handler is passed through.
      def handle_signal_by_tool(context, exception)
        handler = @tool.signal_handler(exception.signo)
        raise exception unless handler
        call_handler(context, handler, exception)
      rescue ::SignalException => e
        raise e if e.equal?(exception)
        handle_signal_by_tool(context, e)
      end

      # Calls a usage error or signal handler against the context. The handler
      # may be a method name or a proc, and receives the errors or the signal
      # exception as its argument unless it takes no arguments.
      def call_handler(context, handler, argument)
        handler = context.method(handler).to_proc if handler.is_a?(::Symbol)
        if handler.arity.zero?
          context.instance_exec(&handler)
        else
          context.instance_exec(argument, &handler)
        end
      end

      # Wraps the given executor in a single middleware, returning the executor
      # unchanged if the middleware does not implement the run interface.
      def make_executor(middleware, context, next_executor)
        if middleware.respond_to?(:run)
          proc { middleware.run(context, &next_executor) }
        else
          next_executor
        end
      end
    end
  end
end
