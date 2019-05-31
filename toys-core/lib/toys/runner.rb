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

module Toys
  ##
  # An internal class that orchestrates execution of a tool.
  #
  # Generally, you should not need to use this class directly. Instead, run a
  # tool using {Toys::CLI#run}.
  #
  class Runner
    ##
    # Create a runner for a particular tool in a particular CLI.
    #
    # @param [Toys::CLI] cli The CLI that is running the tool. This will
    #     provide needed context information.
    # @param [Toys::Tool] tool The tool to run.
    #
    def initialize(cli, tool)
      @cli = cli
      @tool = tool
    end

    ##
    # Run the tool, provided given arguments.
    #
    # @param [Array<String>] args Command line arguments passed to the tool.
    # @param [Integer] verbosity Initial verbosity. Default is 0.
    #
    # @return [Integer] The resulting status code
    #
    def run(args, verbosity: 0)
      arg_parser = ArgParser.new(@cli, @tool, verbosity: verbosity)
      arg_parser.parse(args).finish
      context = @tool.tool_class.new(arg_parser.data)
      @tool.run_initializers(context)

      original_level = @cli.logger.level
      @cli.logger.level = @cli.base_level - context[Context::Key::VERBOSITY]
      begin
        perform_execution(context)
      ensure
        @cli.logger.level = original_level
      end
    end

    private

    def perform_execution(context)
      executor = proc do
        unless @tool.runnable?
          @cli.logger.fatal("No implementation for tool #{@tool.display_name.inspect}")
          context.exit(-1)
        end
        interruptable = @tool.interruptable?
        begin
          context.run
        rescue ::Interrupt => e
          raise e unless interruptable
          handle_interrupt(context, e)
        end
      end
      @tool.middleware_stack.reverse_each do |middleware|
        executor = make_executor(middleware, context, executor)
      end
      catch(:result) do
        executor.call
        0
      end
    end

    def handle_interrupt(context, exception)
      if context.method(:interrupt).arity.zero?
        context.interrupt
      else
        context.interrupt(exception)
      end
    rescue ::Interrupt => e
      raise e if e.equal?(exception)
      handle_interrupt(context, e)
    end

    def make_executor(middleware, context, next_executor)
      proc { middleware.run(context, &next_executor) }
    end
  end
end
