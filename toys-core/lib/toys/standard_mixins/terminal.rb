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
    # {Toys::Terminal}. Some of the most useful methods are also mixed
    # into the tool and can be called directly.
    #
    # You can configure the Terminal object by passing options to the `include`
    # directive. For example:
    #
    #     include :terminal, styled: true
    #
    # The arguments will be passed on to {Toys::Terminal#initialize}.
    #
    module Terminal
      include Mixin

      ##
      # Context key for the terminal object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      to_initialize do |opts = {}|
        self[KEY] = ::Toys::Terminal.new(opts)
      end

      ##
      # Returns a tool-wide terminal instance
      # @return [Toys::Terminal]
      #
      def terminal
        self[KEY]
      end

      ##
      # @see Toys::Terminal#puts
      #
      def puts(str = "", *styles)
        terminal.puts(str, *styles)
      end
      alias say puts

      ##
      # @see Toys::Terminal#write
      #
      def write(str = "", *styles)
        terminal.write(str, *styles)
      end

      ##
      # @see Toys::Terminal#ask
      #
      def ask(prompt, *styles, default: nil, trailing_text: :default)
        terminal.ask(prompt, *styles, default: default, trailing_text: trailing_text)
      end

      ##
      # @see Toys::Terminal#confirm
      #
      def confirm(prompt = "Proceed?", *styles, default: nil)
        terminal.confirm(prompt, *styles, default: default)
      end

      ##
      # @see Toys::Terminal#spinner
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
