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

require "toys/middleware/base"
require "toys/utils/usage"

module Toys
  module Middleware
    ##
    # This middleware handles the case of a usage error. If a usage error, such
    # as an unrecognized switch or an unfulfilled required argument, is
    # detected, this middleware intercepts execution and displays the error
    # along with the usage string, and terminates execution with an error code.
    #
    class HandleUsageErrors < Base
      ##
      # Create a HandleUsageErrors middleware.
      #
      # @param [Intgeer] exit_code The exit code to return if a usage error
      #     occurs. Default is -1.
      #
      def initialize(exit_code: -1)
        @exit_code = exit_code
      end

      ##
      # Intercept and handle usage errors during execution.
      #
      def execute(context)
        if context[Context::USAGE_ERROR]
          puts(context[Context::USAGE_ERROR])
          puts("")
          puts(Utils::Usage.from_context(context).string)
          context.exit(@exit_code)
        else
          yield
        end
      end
    end
  end
end
