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
    def initialize(context_base, data)
      @_context_base = context_base
      @_data = data
      @_data[:__loader] = context_base.loader
      @_data[:__binary_name] = context_base.binary_name
      @_data[:__logger] = context_base.logger
    end

    def verbosity
      @_data[:__verbosity]
    end

    def tool
      @_data[:__tool]
    end

    def tool_name
      @_data[:__tool_name]
    end

    def args
      @_data[:__args]
    end

    def optparse
      @_data[:__optparse]
    end

    def usage_error
      @_data[:__usage_error]
    end

    def logger
      @_data[:__logger]
    end

    def loader
      @_data[:__loader]
    end

    def binary_name
      @_data[:__binary_name]
    end

    def [](key)
      @_data[key]
    end

    def []=(key, value)
      @_data[key] = value
    end

    def options
      @_data.select do |k, _v|
        !k.is_a?(::Symbol) || !k.to_s.start_with?("__")
      end
    end

    def run(*args, exit_on_nonzero_status: false)
      code = @_context_base.run(args.flatten, verbosity: @_data[:__verbosity])
      exit(code) if exit_on_nonzero_status && !code.zero?
      code
    end

    def exit(code)
      throw :result, code
    end

    ##
    # Common context data
    # @private
    #
    class Base
      def initialize(loader, binary_name, logger)
        @loader = loader
        @binary_name = binary_name || ::File.basename($PROGRAM_NAME)
        @logger = logger || ::Logger.new(::STDERR)
        @base_level = @logger.level
      end

      attr_reader :loader
      attr_reader :binary_name
      attr_reader :logger
      attr_reader :base_level

      def run(args, verbosity: 0)
        @loader.execute(self, args, verbosity: verbosity)
      end

      def create_context(data)
        Context.new(self, data)
      end
    end
  end
end
