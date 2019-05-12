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

require "optparse"

module Toys
  ##
  # An internal class that orchestrates execution of a tool.
  #
  # Generaly, you should not need to use this class directly. Instead, run a
  # tool using {Toys::CLI#run}.
  #
  class Runner
    ##
    # Create a runner for a particular tool in a particular CLI.
    #
    # @param [Toys::CLI] cli The CLI that is running the tool. This will
    #     provide needed context information.
    # @param [Toys::Definition::Tool] tool_definition The tool to run.
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
      data = create_data(args, verbosity)
      parse_args(args, data) unless @tool_definition.argument_parsing_disabled?
      tool = @tool_definition.tool_class.new(@cli, data)
      @tool_definition.run_initializers(tool)

      original_level = @cli.logger.level
      @cli.logger.level = @cli.base_level - data[Tool::Keys::VERBOSITY]
      begin
        perform_execution(tool)
      ensure
        @cli.logger.level = original_level
      end
    end

    private

    def create_data(args, base_verbosity)
      data = @tool_definition.default_data.dup
      data[Tool::Keys::TOOL_DEFINITION] = @tool_definition
      data[Tool::Keys::TOOL_SOURCE] = @tool_definition.source_info
      data[Tool::Keys::TOOL_NAME] = @tool_definition.full_name
      data[Tool::Keys::VERBOSITY] = base_verbosity
      data[Tool::Keys::ARGS] = args
      data[Tool::Keys::USAGE_ERROR] = nil
      data
    end

    def parse_args(args, data)
      optparse, seen = create_option_parser(data)
      remaining = optparse.parse(args)
      validate_flags(args, seen)
      remaining = parse_required_args(remaining, args, data)
      remaining = parse_optional_args(remaining, data)
      parse_remaining_args(remaining, args, data)
    rescue ::OptionParser::ParseError => e
      data[Tool::Keys::USAGE_ERROR] = e.message
    end

    def create_option_parser(data)
      seen = []
      optparse = ::OptionParser.new
      # The following clears out the Officious (hidden default flags).
      optparse.remove
      optparse.remove
      optparse.new
      optparse.new
      @tool_definition.flag_definitions.each do |flag|
        optparse.on(*flag.optparser_info) do |val|
          seen << flag.key
          data[flag.key] = flag.handler.call(val, data[flag.key])
        end
      end
      @tool_definition.custom_acceptors do |accept|
        optparse.accept(accept)
      end
      [optparse, seen]
    end

    def validate_flags(args, seen)
      @tool_definition.flag_groups.each do |group|
        error = group.validation_error(seen)
        raise create_parse_error(args, error) if error
      end
    end

    def parse_required_args(remaining, args, data)
      @tool_definition.required_arg_definitions.each do |arg_info|
        if remaining.empty?
          reason = "No value given for required argument #{arg_info.display_name}"
          raise create_parse_error(args, reason)
        end
        data[arg_info.key] = arg_info.process_value(remaining.shift)
      end
      remaining
    end

    def parse_optional_args(remaining, data)
      @tool_definition.optional_arg_definitions.each do |arg_info|
        break if remaining.empty?
        data[arg_info.key] = arg_info.process_value(remaining.shift)
      end
      remaining
    end

    def parse_remaining_args(remaining, args, data)
      return if remaining.empty?
      unless @tool_definition.remaining_args_definition
        if @tool_definition.runnable?
          raise create_parse_error(remaining, "Extra arguments provided")
        else
          raise create_parse_error(@tool_definition.full_name + args, "Tool not found")
        end
      end
      data[@tool_definition.remaining_args_definition.key] =
        remaining.map { |arg| @tool_definition.remaining_args_definition.process_value(arg) }
    end

    def create_parse_error(path, reason)
      ::OptionParser::ParseError.new(*path).tap do |e|
        e.reason = reason
      end
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
