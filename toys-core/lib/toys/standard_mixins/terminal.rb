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
  module StandardMixins
    ##
    # A mixin that provides a simple terminal. It includes a set of methods
    # that produce styled output, get user input, and otherwise interact with
    # the user's terminal.
    #
    # You may make these methods available to your tool by including the
    # following directive in your tool configuration:
    #
    #     include :terminal
    #
    module Terminal
      ##
      # Returns a global terminal instance
      # @return [Toys::Utils::Terminal]
      #
      def terminal
        self[Terminal] ||= Utils::Terminal.new
      end

      ##
      # @see Toys::Utils::Terminal#puts
      #
      def puts(str = "", *styles)
        terminal.puts(str, *styles)
      end

      ##
      # @see Toys::Utils::Terminal#write
      #
      def write(str = "", *styles)
        terminal.write(str, *styles)
      end

      ##
      # @see Toys::Utils::Terminal#confirm
      #
      def confirm(prompt = "Proceed?")
        terminal.confirm(prompt)
      end

      ##
      # @see Toys::Utils::Terminal#spinner
      #
      def spinner(leading_text: "", final_text: "",
                  frame_length: nil, frames: nil, style: nil, &block)
        terminal.spinner(leading_text: leading_text, final_text: final_text,
                         frame_length: frame_length, frames: frames, style: style,
                         &block)
      end
    end
  end
end
