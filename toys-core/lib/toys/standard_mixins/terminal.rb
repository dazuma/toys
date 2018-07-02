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
  module StandardMixins
    ##
    # A mixin that provides a simple terminal. It includes a set of methods
    # that produce styled output, get user input, and otherwise interact with
    # the user's terminal. This mixin is not as richly featured as other mixins
    # such as Highline, but it has no gem dependencies so is ideal for basic
    # cases.
    #
    # You may make these methods available to your tool by including the
    # following directive in your tool configuration:
    #
    #     include :terminal
    #
    # A Terminal object will then be available by calling the {#terminal}
    # method. For information on using this object, see the documentation for
    # {Toys::Utils::Terminal}. Some of the most useful methods are also mixed
    # into the tool and can be called directly.
    #
    # You can configure the Terminal object by passing options to the `include`
    # directive. For example:
    #
    #     include :terminal, styled: true
    #
    # The arguments will be passed on to {Toys::Utils::Terminal#initialize}.
    #
    module Terminal
      include Mixin

      ##
      # Context key for the terminal object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      to_initialize do |opts = {}|
        self[KEY] = Utils::Terminal.new(opts)
      end

      ##
      # Returns a global terminal instance
      # @return [Toys::Utils::Terminal]
      #
      def terminal
        self[KEY]
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
      def confirm(prompt = "Proceed?", default: false)
        terminal.confirm(prompt, default: default)
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
