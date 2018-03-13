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

require "logger"

module Toys
  ##
  # The object context in effect during the execution of a tool.
  #
  class Context
    def initialize(context_base, tool_name, args, options)
      @context_base = context_base
      @tool_name = tool_name
      @args = args
      @options = options
    end

    attr_reader :tool_name
    attr_reader :args
    attr_reader :options

    def [](key)
      @options[key]
    end

    def logger
      @context_base.logger
    end

    def binary_name
      @context_base.binary_name
    end

    def run(*args)
      @context_base.run(*args)
    end

    def exit(code)
      throw :result, code
    end

    ##
    # Common context data
    # @private
    #
    class Base
      def initialize(lookup, binary_name, logger)
        @lookup = lookup
        @binary_name = binary_name
        @logger = logger || ::Logger.new(::STDERR)
      end

      attr_reader :binary_name
      attr_reader :logger

      def run(*args)
        @lookup.execute(self, args.flatten)
      end

      def create_context(tool_name, args, options)
        Context.new(self, tool_name, args, options)
      end
    end
  end
end
