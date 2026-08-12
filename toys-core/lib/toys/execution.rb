# frozen_string_literal: true

require "logger"

module Toys
  ##
  # An object that performs tool executions.
  #
  # An Execution ties together all the information needed to perform a tool
  # execution. This includes which tool to execute and the arguments passed to
  # it, and execution-related settings.
  #
  # A successfully built Execution can be invoked via {#run} to execute a tool.
  # This parses the remaining command line arguments into a {Toys::Context},
  # applies the tool's middleware, and then either runs the tool normally or
  # executes a given block with the context. The latter is useful for testing.
  #
  # Once constructed, an Execution can be invoked multiple times independently.
  #
  # Create executions using the {Execution.for_tool} or {Execution.for_args}
  # factory methods. Most applications should not create executions at all, but
  # should call {Toys::CLI#run} or {Toys::CLI#load_tool}, which perform properly
  # configured tool executions and tests, along with error handling.
  #
  class Execution
    class << self
      ##
      # Create a tool execution for an already known tool.
      #
      # @param tool [Toys::ToolDefinition] The tool to run.
      # @param args [Array<String>] The command line arguments to pass to the
      #     tool, not including the tool name itself.
      # @param loader [Toys::Loader] The loader.
      # @param logger_factory [Proc,nil] A proc that optionally takes a tool
      #     definition and returns a logger. If not given, a default will be
      #     provided.
      # @param base_logger_level [Integer,nil] The logger level that corresponds
      #     to zero verbosity. If not provided, the current setting of the logger
      #     is used (typically Logger::WARN).
      # @param verbosity [Integer] Initial verbosity. Default is 0.
      # @param delegated_from [Toys::Context,nil] The context from which this
      #     execution is delegated. Optional. Should be set only if this is a
      #     delegated execution.
      # @param wrap_errors [boolean] If true (the default), wrap errors in
      #     ContextualError, including errors during argument parsing and tool
      #     execution during the {#run} method. If false, propagate errors as-is
      #     and do not wrap them. A `SignalException` is never wrapped
      #     regardless of this setting; see {#run}.
      # @param external_data [Hash] Additional data provided by the caller.
      # @return [Toys::Execution]
      #
      def for_tool(tool, args, loader,
                   logger_factory: nil,
                   base_logger_level: nil,
                   verbosity: 0,
                   delegated_from: nil,
                   wrap_errors: true,
                   external_data: {})
        new(tool, args, loader,
            logger_factory: logger_factory,
            base_logger_level: base_logger_level,
            verbosity: verbosity,
            delegated_from: delegated_from,
            wrap_errors: wrap_errors,
            external_data: external_data)
      end

      ##
      # Create a tool execution, determining the tool by looking up a tool name
      # appearing at the beginning of the given arguments.
      #
      # The given {Toys::Loader} is invoked to perform the lookup, which can
      # raise an error. If `wrap_errors` is enabled, such an error is wrapped in
      # a finalized {Toys::ContextualError}.
      #
      # @param args [Array<String>] The command line arguments, including the
      #     name of the tool to look up.
      # @param loader [Toys::Loader] The loader.
      # @param logger_factory [Proc,nil] A proc that optionally takes a tool
      #     definition and returns a logger. If not given, a default will be
      #     provided.
      # @param base_logger_level [Integer,nil] The logger level that corresponds
      #     to zero verbosity. If not provided, the current setting of the logger
      #     is used (typically Logger::WARN).
      # @param verbosity [Integer] Initial verbosity. Default is 0.
      # @param delegated_from [Toys::Context,nil] The context from which this
      #     execution is delegated. Optional. Should be set only if this is a
      #     delegated execution.
      # @param wrap_errors [boolean] If true (the default), wrap errors in
      #     ContextualError, including errors during the tool lookup performed
      #     by this method, and errors during argument parsing and tool
      #     execution during the {#run} method. If false, propagate errors as-is
      #     and do not wrap them. A `SignalException` is never wrapped
      #     regardless of this setting; see {#run}.
      # @param external_data [Hash] Additional data provided by the caller.
      # @return [Toys::Execution]
      #
      def for_args(args, loader,
                   logger_factory: nil,
                   base_logger_level: nil,
                   verbosity: 0,
                   delegated_from: nil,
                   wrap_errors: true,
                   external_data: {})
        tool, remaining =
          if wrap_errors
            ContextualError.capture(banner: "Error finding tool definition", final: true) do
              loader.lookup(args)
            end
          else
            loader.lookup(args)
          end
        new(tool, remaining, loader,
            logger_factory: logger_factory,
            base_logger_level: base_logger_level,
            verbosity: verbosity,
            delegated_from: delegated_from,
            wrap_errors: wrap_errors,
            external_data: external_data)
      end

      ##
      # Returns a default logger factory that generates simple loggers that
      # write to STDERR.
      #
      # @return [Proc]
      #
      def default_logger_factory
        proc do
          logger = ::Logger.new($stderr)
          logger.level = ::Logger::WARN
          logger
        end
      end
    end

    ##
    # Create a tool execution. Use {Execution.for_tool} or {Execution.for_args}
    # instead of calling this directly.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def initialize(tool, args, loader,
                   logger_factory:,
                   base_logger_level:,
                   verbosity:,
                   delegated_from:,
                   wrap_errors:,
                   external_data:)
      @tool = tool
      @args = args
      @loader = loader
      @logger_factory = logger_factory || Execution.default_logger_factory
      @base_logger_level = base_logger_level
      @verbosity = verbosity.to_i
      @delegated_from = delegated_from
      @wrap_errors = wrap_errors
      @external_data = external_data
    end

    ##
    # The tool that this execution runs.
    #
    # @return [Toys::ToolDefinition]
    #
    attr_reader :tool

    ##
    # The command line arguments passed to the tool, not including the tool name
    # itself. If this execution was created by {Execution.for_args}, these are
    # the arguments remaining after the tool name was consumed by the lookup.
    #
    # @return [Array<String>]
    #
    attr_reader :args

    ##
    # Perform the requested tool execution.
    #
    # Parses the command line arguments, and builds the tool's context, and
    # invokes the tool within its middleware stack.
    #
    # If a block is passed, the runtime context is simply yielded to it. This
    # is useful for testing parts of the tool runtime in isolation.
    # If no block is passed, the tool is executed normally.
    #
    # If the tool raises a `SignalException` that it does not handle itself,
    # that exception propagates out of this method unwrapped, even when
    # `wrap_errors` is enabled. This lets each tool in a nested execution
    # dispatch it to its own `on_interrupt` or `on_signal` handler, and lets
    # the Ruby VM handle whatever is left.
    #
    # @yieldparam context [Toys::Context] If a block is given, it is invoked in
    #     place of the tool's run handler, with the tool's middleware still
    #     applied. This is intended for testing tools.
    #
    # @return [Integer] The resulting process status code (i.e. 0 for success).
    #
    def run(&block)
      return run_internal(&block) unless @wrap_errors
      ContextualError.capture(
        banner: "Error during tool execution",
        path: @tool.source_info&.source_path,
        tool_name: @tool.full_name, tool_args: @args,
        final: true
      ) do
        run_internal(&block)
      end
    end

    private

    # Builds the context and runs the tool within it, without any error
    # wrapping. See {#run}.
    def run_internal(&block)
      context = build_context
      block ||= make_run_handler
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
      arg_parser.parse(@args).finish
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
    # the delegating context.
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
      subexec = Execution.for_args(target + @args, @loader,
                                   external_data: @external_data,
                                   logger_factory: @logger_factory,
                                   base_logger_level: @base_logger_level,
                                   verbosity: @verbosity,
                                   wrap_errors: @wrap_errors,
                                   delegated_from: context)
      Context.exit(subexec.run)
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
