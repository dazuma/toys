# frozen_string_literal: true

require "logger"

module Toys
  ##
  # An object that runs tools.
  #
  # A Runner holds the environment in which tools run. This includes the
  # {Toys::Loader} that resolves a tool name to a tool definition, along with
  # settings such as how to obtain a logger for a tool. This environment is
  # fixed when the Runner is constructed.
  #
  # Everything specific to a single invocation—which tool to run, the arguments
  # to pass to it, and how to treat errors—is passed to {#run}. A Runner thus
  # holds no per-run state, and one Runner can run any number of tools.
  #
  # Most applications should not create a Runner directly, but should call
  # {Toys::CLI#run} or {Toys::CLI#load_tool}, which run tools using a properly
  # configured Runner, along with error handling.
  #
  class Runner
    ##
    # The singleton default logger_factory Proc, which simply returns a new
    # logger writing to the current stderr.
    #
    # @return [Proc]
    #
    DEFAULT_LOGGER_FACTORY = proc {
      logger = ::Logger.new($stderr)
      logger.level = ::Logger::WARN
      logger
    }.freeze

    ##
    # Create a Runner.
    #
    # This performs no I/O and raises nothing. Tools are looked up, loaded, and
    # run only when {#run} is called.
    #
    # @param loader [Toys::Loader] The loader used to look up tools.
    # @param logger_factory [Proc,nil] A proc that optionally takes a tool
    #     definition and returns a logger. If not given,
    #     {Toys::Runner::DEFAULT_LOGGER_FACTORY} is used.
    # @param base_logger_level [Integer,nil] The logger level that corresponds
    #     to zero verbosity. If not provided, the current setting of the logger
    #     is used (typically Logger::WARN).
    # @param external_data [Hash] Additional context data provided by the
    #     caller. It is merged underneath the data the Runner provides itself,
    #     so it cannot override runtime-owned keys.
    #
    def initialize(loader,
                   logger_factory: nil,
                   base_logger_level: nil,
                   external_data: {})
      @loader = loader
      @logger_factory = logger_factory || DEFAULT_LOGGER_FACTORY
      @base_logger_level = base_logger_level
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
    # that exception propagates out of this method unwrapped, even when
    # `wrap_errors` is enabled. This lets each tool in a nested execution
    # dispatch it to its own `on_interrupt` or `on_signal` handler, and lets
    # the Ruby VM handle whatever is left.
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
    #
    # @yieldparam context [Toys::Context] If a block is given, it is invoked in
    #     place of the tool's run handler, with the tool's middleware still
    #     applied. This is intended for testing tools.
    #
    # @return [Integer] The resulting process status code (i.e. 0 for success).
    #
    def run(args, verbosity: 0, wrap_errors: true, &block)
      Invocation.new(loader: @loader,
                     logger_factory: @logger_factory,
                     base_logger_level: @base_logger_level,
                     external_data: @external_data,
                     args: args,
                     verbosity: verbosity,
                     wrap_errors: wrap_errors,
                     delegated_from: nil,
                     block: block).run
    end

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
      # Create an invocation. The first group of arguments is the environment
      # taken from the Runner, and the second is specific to this one run.
      #
      # @private
      #
      def initialize(loader:,
                     logger_factory:,
                     base_logger_level:,
                     external_data:,
                     args:,
                     verbosity:,
                     wrap_errors:,
                     delegated_from:,
                     block:)
        @loader = loader
        @logger_factory = logger_factory
        @base_logger_level = base_logger_level
        @external_data = external_data
        @args = args
        @verbosity = verbosity.to_i
        @wrap_errors = wrap_errors
        @delegated_from = delegated_from
        @block = block
      end

      ##
      # Perform the invocation, and return the resulting process status code.
      # This looks up the tool, builds its context, and invokes it within its
      # middleware stack, wrapping errors from each phase if requested.
      #
      # @private
      #
      def run
        lookup_tool
        execute
      end

      private

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
          Context::Key::CONTEXT_DIRECTORY => @tool.context_directory,
          Context::Key::DELEGATED_FROM => @delegated_from,
          Context::Key::LOADER => @loader,
          Context::Key::LOGGER => @logger_factory.call(@tool),
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
        Context.exit(delegated_invocation(target + @tool_args, context).run)
      end

      # Builds the invocation that runs a delegate target, copying this
      # invocation's environment and settings.
      def delegated_invocation(args, context)
        Invocation.new(loader: @loader,
                       logger_factory: @logger_factory,
                       base_logger_level: @base_logger_level,
                       external_data: @external_data,
                       args: args,
                       verbosity: @verbosity,
                       wrap_errors: @wrap_errors,
                       delegated_from: context,
                       block: nil)
      end

      # Prepares the runtime environment for the tool, applying lib paths and
      # initializers and setting the logger level implied by the verbosity, and
      # then calls the tool within its middleware stack, returning the resulting
      # exit code. The logger level is restored when the tool finishes.
      def execute_tool(context, &block)
        @tool.source_info&.apply_lib_paths
        @tool.run_initializers(context)
        cur_logger = context[Context::Key::LOGGER]
        if cur_logger
          original_level = cur_logger.level
          cur_logger.level = (@base_logger_level || original_level) - context[Context::Key::VERBOSITY].to_i
        end
        begin
          executor = build_executor(context, &block)
          catch(:result) do
            executor.call
            0
          end
        ensure
          cur_logger.level = original_level if cur_logger
        end
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
