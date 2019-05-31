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
  # A middleware is an object that has the opportunity to alter the
  # configuration and runtime behavior of each tool in a Toys CLI. A CLI
  # contains an ordered list of middleware, known as the *middleware stack*,
  # that together define the CLI's default behavior.
  #
  # Specifically, a middleware can perform two functions.
  #
  # First, it can modify the configuration of a tool. After tools are defined
  # from configuration, the middleware stack can make modifications to each
  # tool. A middleware can add flags and arguments to the tool, modify the
  # description, or make any other changes to how the tool is set up.
  #
  # Second, a middleware can intercept and change tool execution. Like a Rack
  # middleware, a Toys middleware can wrap execution with its own code,
  # replace it outright, or leave it unmodified.
  #
  # Generally, a middleware is a class that implements the two methods defined
  # in this module: {Toys::Middleware#config} and {Toys::Middleware#run}. A
  # middleware can include this module to get default implementations that do
  # nothing, but this is not required.
  #
  module Middleware
    ##
    # This method is called after a tool has been defined, and gives this
    # middleware the opportunity to modify the tool definition. It is passed
    # the tool definition object and the loader, and can make any changes to
    # the tool definition. In most cases, this method should also call
    # `yield`, which passes control to the next middleware in the stack. A
    # middleware can disable modifications done by subsequent middleware by
    # omitting the `yield` call, but this is uncommon.
    #
    # This basic implementation does nothing and simply yields to the next
    # middleware.
    #
    # @param [Toys::ToolDefinition] tool_definition The tool definition
    #     to modify.
    # @param [Toys::Loader] loader The loader that loaded this tool.
    #
    def config(tool_definition, loader) # rubocop:disable Lint/UnusedMethodArgument
      yield
    end

    ##
    # This method is called when the tool is run. It gives the middleware an
    # opportunity to modify the runtime behavior of the tool. It is passed
    # the tool instance (i.e. the object that hosts a tool's `run` method),
    # and you can use this object to access the tool's options and other
    # context data. In most cases, this method should also call `yield`,
    # which passes control to the next middleware in the stack. A middleware
    # can "wrap" normal execution by calling `yield` somewhere in its
    # implementation of this method, or it can completely replace the
    # execution behavior by not calling `yield` at all.
    #
    # Like a tool's `run` method, this method's return value is unused. If
    # you want to output from a tool, write to stdout or stderr. If you want
    # to set the exit status code, call {Toys::Context#exit} on the context.
    #
    # This basic implementation does nothing and simply yields to the next
    # middleware.
    #
    # @param [Toys::Context] context The tool execution context.
    #
    def run(context) # rubocop:disable Lint/UnusedMethodArgument
      yield
    end
  end
end
