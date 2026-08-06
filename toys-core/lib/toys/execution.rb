# frozen_string_literal: true

require "logger"

module Toys
  ##
  # An execution of a single tool.
  #
  # An execution ties together a {Toys::CLI} with a {Toys::ToolDefinition} that
  # has already been looked up from the CLI's loader, along with the remaining
  # command line arguments to pass to it. Calling {Toys::Execution#run} parses
  # those arguments into a {Toys::Context}, applies the tool's middleware, and
  # invokes the tool.
  #
  # Most applications should not create executions directly, but should call
  # {Toys::CLI#run}, which looks up the tool, creates the execution, and
  # provides error handling. Create an execution directly if you have a tool
  # definition in hand and want to run it without going through tool name
  # lookup, or if you want to provide your own error handling.
  #
  # An execution does no work, and raises no errors, until {#run} is called.
  #
  class Execution
    ##
    # Create an execution of the given tool.
    #
    # @param tool [Toys::ToolDefinition] The tool to run.
    # @param args [Array<String>] The command line arguments to pass to the
    #     tool, not including the tool name itself.
    # @param loader [Toys::Loader] The loader, used for delegating, getting
    #     suggestions, and populating context.
    # @param logger [Logger,nil] A logger to use. If not given, a default will
    #     be created.
    # @param base_logger_level [Integer,nil] The logger level that corresponds
    #     to zero verbosity. If not provided, the current setting of the logger
    #     is used (typically Logger::WARN).
    # @param verbosity [Integer] Initial verbosity. Default is 0.
    # @param delegated_from [Toys::Context,nil] The context from which this
    #     execution is delegated. Optional. Should be set only if this is a
    #     delegated execution.
    # @param external_data [Hash] Additional data provided by the caller.
    #
    def initialize(tool, args, loader,
                   logger: nil,
                   base_logger_level: nil,
                   verbosity: 0,
                   delegated_from: nil,
                   external_data: {})
      @tool = tool
      @args = args
      @loader = loader
      @logger = logger
      unless @logger
        @logger = ::Logger.new($stderr)
        @logger.level = ::Logger::WARN
      end
      @base_logger_level = base_logger_level
      @verbosity = verbosity.to_i
      @delegated_from = delegated_from
      @external_data = external_data
    end

    ##
    # Run the tool.
    #
    # Parses the command line arguments, builds the tool's context, and invokes
    # the tool within its middleware stack. Errors are not handled; they are
    # raised to the caller.
    #
    # @yieldparam context [Toys::Context] If a block is given, it is invoked in
    #     place of the tool's run handler, with the tool's middleware still
    #     applied. This is intended for testing tools.
    #
    # @return [Integer] The resulting process status code (i.e. 0 for success).
    #
    def run(&block)
      context = build_context
      block ||= make_run_handler
      execute_tool(context, &block)
    end

    private

    # Parses the command line arguments against the tool's flag and positional
    # definitions, and builds the tool's runtime context from the result. Any
    # argument errors are recorded in the context as usage errors, to be
    # handled later during execution.
    def build_context
      common_data = {
        Context::Key::CONTEXT_DIRECTORY => @tool.context_directory,
        Context::Key::DELEGATED_FROM => @delegated_from,
        Context::Key::LOGGER => @logger,
        Context::Key::TOOL => @tool,
        Context::Key::TOOL_NAME => @tool.full_name,
        Context::Key::TOOL_SOURCE => @tool.source_info,
        Context::Key::VERBOSITY => @verbosity,
      }
      common_data.merge!(@external_data)
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
      # We recompute the tool/args split so that target can point to a namespace
      # and we can load a tool under it.
      @loader.load_for_prefix(target)
      raise ToolDefinitionError, "Delegate target not found: #{target_str}" unless @loader.tool_defined?(target)
      target_tool, target_args = @loader.lookup(target + @args)
      subexec = Execution.new(target_tool, target_args, @loader,
                              external_data: @external_data,
                              logger: @logger,
                              base_logger_level: @base_logger_level,
                              verbosity: @verbosity,
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
