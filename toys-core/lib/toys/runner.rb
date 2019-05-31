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
    # @param [Toys::ToolDefinition] tool_definition The tool to run.
    #
    def initialize(cli, tool_definition)
      @cli = cli
      @tool_definition = tool_definition
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
      data = parse_data(args, verbosity)
      tool = @tool_definition.tool_class.new(@cli, data)
      @tool_definition.run_initializers(tool)

      original_level = @cli.logger.level
      @cli.logger.level = @cli.base_level - data[Context::Key::VERBOSITY]
      begin
        perform_execution(tool)
      ensure
        @cli.logger.level = original_level
      end
    end

    private

    def parse_data(args, verbosity)
      arg_parser = ArgParser.new(@tool_definition)
      data = arg_parser.data
      data[Context::Key::TOOL_DEFINITION] = @tool_definition
      data[Context::Key::TOOL_SOURCE] = @tool_definition.source_info
      data[Context::Key::TOOL_NAME] = @tool_definition.full_name
      data[Context::Key::VERBOSITY] = verbosity
      data[Context::Key::ARGS] = args
      data[Context::Key::USAGE_ERROR] = nil
      unless @tool_definition.argument_parsing_disabled?
        arg_parser.parse(args)
        arg_parser.finish
        unless arg_parser.errors.empty?
          data[Context::Key::USAGE_ERROR] = arg_parser.errors.join("\n")
        end
      end
      data
    end

    def perform_execution(tool)
      executor = proc do
        unless @tool_definition.runnable?
          @cli.logger.fatal("No implementation for tool #{@tool_definition.display_name.inspect}")
          tool.exit(-1)
        end
        interruptable = @tool_definition.interruptable?
        begin
          tool.run
        rescue ::Interrupt => e
          raise e unless interruptable
          handle_interrupt(tool, e)
        end
      end
      @tool_definition.middleware_stack.reverse_each do |middleware|
        executor = make_executor(middleware, tool, executor)
      end
      catch(:result) do
        executor.call
        0
      end
    end

    def handle_interrupt(tool, exception)
      if tool.method(:interrupt).arity.zero?
        tool.interrupt
      else
        tool.interrupt(exception)
      end
    rescue ::Interrupt => e
      raise e if e.equal?(exception)
      handle_interrupt(tool, e)
    end

    def make_executor(middleware, tool, next_executor)
      proc { middleware.run(tool, &next_executor) }
    end
  end
end
