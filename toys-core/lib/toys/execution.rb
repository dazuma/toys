# frozen_string_literal: true

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
    # @param cli [Toys::CLI] The CLI that is running the tool. It provides the
    #     loader, logger factory, and base logger level for the execution, and
    #     is made available to the tool at runtime.
    # @param tool [Toys::ToolDefinition] The tool to run.
    # @param args [Array<String>] The command line arguments to pass to the
    #     tool, not including the tool name itself.
    # @param verbosity [Integer] Initial verbosity. Default is 0.
    # @param delegated_from [Toys::Context,nil] The context from which this
    #     execution is delegated. Optional. Should be set only if this is a
    #     delegated execution.
    #
    def initialize(cli, tool, args, verbosity: 0, delegated_from: nil)
      @cli = cli
      @tool = tool
      @args = args
      @verbosity = verbosity
      @delegated_from = delegated_from
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

    def build_context
      default_data = {
        Context::Key::VERBOSITY => @verbosity,
        Context::Key::DELEGATED_FROM => @delegated_from,
      }
      arg_parser = ArgParser.new(@cli, @tool,
                                 default_data: default_data,
                                 require_exact_flag_match: @tool.exact_flag_match_required?)
      arg_parser.parse(@args).finish
      @tool.tool_class.new(arg_parser.data)
    end

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
      path = [target.join(" ").inspect]
      walk_context = context
      until walk_context.nil?
        name = walk_context[Context::Key::TOOL_NAME]
        path << name.join(" ").inspect
        if name == target
          raise ToolDefinitionError, "Delegation loop: #{path.join(' <- ')}"
        end
        walk_context = walk_context[Context::Key::DELEGATED_FROM]
      end
      cli = context[Context::Key::CLI]
      cli.loader.load_for_prefix(target)
      unless cli.loader.tool_defined?(target)
        raise ToolDefinitionError, "Delegate target not found: \"#{target.join(' ')}\""
      end
      # Uses Context.exit rather than context.exit because a tool is allowed to
      # override the exit method, and this control flow must not be intercepted.
      Context.exit(cli.run(target + context[Context::Key::ARGS], delegated_from: context))
    end

    def execute_tool(context, &block)
      @tool.source_info&.apply_lib_paths
      @tool.run_initializers(context)
      cur_logger = context[Context::Key::LOGGER]
      if cur_logger
        original_level = cur_logger.level
        cur_logger.level = (@cli.base_level || original_level) - context[Context::Key::VERBOSITY].to_i
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

    def handle_usage_errors(context)
      usage_errors = context[Context::Key::USAGE_ERRORS]
      handler = @tool.usage_error_handler
      raise ArgParsingError, usage_errors if handler.nil?
      call_handler(context, handler, usage_errors)
    end

    def handle_signal_by_tool(context, exception)
      handler = @tool.signal_handler(exception.signo)
      raise exception unless handler
      call_handler(context, handler, exception)
    rescue ::SignalException => e
      raise e if e.equal?(exception)
      handle_signal_by_tool(context, e)
    end

    def call_handler(context, handler, argument)
      handler = context.method(handler).to_proc if handler.is_a?(::Symbol)
      if handler.arity.zero?
        context.instance_exec(&handler)
      else
        context.instance_exec(argument, &handler)
      end
    end

    def make_executor(middleware, context, next_executor)
      if middleware.respond_to?(:run)
        proc { middleware.run(context, &next_executor) }
      else
        next_executor
      end
    end
  end
end
