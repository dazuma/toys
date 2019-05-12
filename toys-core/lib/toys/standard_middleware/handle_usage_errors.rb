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
  module StandardMiddleware
    ##
    # This middleware handles the case of a usage error. If a usage error, such
    # as an unrecognized flag or an unfulfilled required argument, is detected,
    # this middleware intercepts execution and displays the error along with
    # the short help string, and terminates execution with an error code.
    #
    class HandleUsageErrors
      include Middleware

      ##
      # Create a HandleUsageErrors middleware.
      #
      # @param [Intgeer] exit_code The exit code to return if a usage error
      #     occurs. Default is -1.
      # @param [IO] stream Output stream to write to. Default is stderr.
      # @param [Boolean,nil] styled_output Cause the tool to display help text
      #     with ansi styles. If `nil`, display styles if the output stream is
      #     a tty. Default is `nil`.
      #
      def initialize(exit_code: -1, stream: $stderr, styled_output: nil)
        @exit_code = exit_code
        @terminal = Terminal.new(output: stream, styled: styled_output)
      end

      ##
      # Intercept and handle usage errors during execution.
      #
      def run(tool)
        if tool[Tool::Keys::USAGE_ERROR]
          require "toys/utils/help_text"
          help_text = Utils::HelpText.from_tool(tool)
          @terminal.puts(tool[Tool::Keys::USAGE_ERROR], :bright_red, :bold)
          @terminal.puts("")
          @terminal.puts(help_text.usage_string(wrap_width: @terminal.width))
          Tool.exit(@exit_code)
        else
          yield
        end
      end
    end
  end
end
