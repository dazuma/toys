# frozen_string_literal: true

# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
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
    # @param [Toys::Definition::Tool] _tool_definition The tool definition
    #     to modify.
    # @param [Toys::Loader] _loader The loader that loaded this tool.
    #
    def config(_tool_definition, _loader)
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
    # to set the exit status code, call {Toys::Tool#exit} on the tool object.
    #
    # This basic implementation does nothing and simply yields to the next
    # middleware.
    #
    # @param [Toys::Tool] _tool The tool execution instance.
    #
    def run(_tool)
      yield
    end
  end
end
