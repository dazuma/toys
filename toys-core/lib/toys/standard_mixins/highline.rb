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
    # A mixin that provides access to the capabilities of the highline gem.
    #
    # This mixin requires the highline gem, version 2.0 or later. It will
    # attempt to install the gem if it is not available.
    #
    # You may make these methods available to your tool by including the
    # following directive in your tool configuration:
    #
    #     include :highline
    #
    # A HighLine object will then be available by calling the {#highline}
    # method. For information on using this object, see the
    # [Highline documentation](https://www.rubydoc.info/gems/highline). Some of
    # the most common HighLine methods, such as `say`, are also mixed into the
    # tool and can be called directly.
    #
    # You can configure the HighLine object by passing options to the `include`
    # directive. For example:
    #
    #     include :highline, my_stdin, my_stdout
    #
    # The arguments will be passed on to the
    # [HighLine constructor](https://www.rubydoc.info/gems/highline/HighLine:initialize).
    #
    module Highline
      include Mixin

      ##
      # Context key for the highline object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      on_initialize do |*args|
        require "toys/utils/gems"
        Toys::Utils::Gems.activate("highline", "~> 2.0")
        require "highline"
        self[KEY] = ::HighLine.new(*args)
        self[KEY].use_color = $stdout.tty?
      end

      ##
      # A tool-wide [HighLine](https://www.rubydoc.info/gems/highline/HighLine)
      # instance
      # @return [::HighLine]
      #
      def highline
        self[KEY]
      end

      ##
      # Calls [HighLine#agree](https://www.rubydoc.info/gems/highline/HighLine:agree)
      #
      def agree(*args, &block)
        highline.agree(*args, &block)
      end

      ##
      # Calls [HighLine#ask](https://www.rubydoc.info/gems/highline/HighLine:ask)
      #
      def ask(*args, &block)
        highline.ask(*args, &block)
      end

      ##
      # Calls [HighLine#choose](https://www.rubydoc.info/gems/highline/HighLine:choose)
      #
      def choose(*args, &block)
        highline.choose(*args, &block)
      end

      ##
      # Calls [HighLine#list](https://www.rubydoc.info/gems/highline/HighLine:list)
      #
      def list(*args, &block)
        highline.list(*args, &block)
      end

      ##
      # Calls [HighLine#say](https://www.rubydoc.info/gems/highline/HighLine:say)
      #
      def say(*args, &block)
        highline.say(*args, &block)
      end

      ##
      # Calls [HighLine#indent](https://www.rubydoc.info/gems/highline/HighLine:indent)
      #
      def indent(*args, &block)
        highline.indent(*args, &block)
      end

      ##
      # Calls [HighLine#newline](https://www.rubydoc.info/gems/highline/HighLine:newline)
      #
      def newline
        highline.newline
      end

      ##
      # Calls [HighLine#puts](https://www.rubydoc.info/gems/highline/HighLine:puts)
      #
      def puts(*args)
        highline.puts(*args)
      end

      ##
      # Calls [HighLine#color](https://www.rubydoc.info/gems/highline/HighLine:color)
      #
      def color(*args)
        highline.color(*args)
      end

      ##
      # Calls [HighLine#color_code](https://www.rubydoc.info/gems/highline/HighLine:color_code)
      #
      def color_code(*args)
        highline.color_code(*args)
      end

      ##
      # Calls [HighLine#uncolor](https://www.rubydoc.info/gems/highline/HighLine:uncolor)
      #
      def uncolor(*args)
        highline.uncolor(*args)
      end

      ##
      # Calls [HighLine#new_scope](https://www.rubydoc.info/gems/highline/HighLine:new_scope)
      #
      def new_scope
        highline.new_scope
      end
    end
  end
end
