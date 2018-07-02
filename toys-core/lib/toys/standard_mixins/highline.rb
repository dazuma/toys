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

Toys::Utils::Gems.activate("highline", "~> 2.0")
require "highline"

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

      to_initialize do |*args|
        self[KEY] = ::HighLine.new(*args)
        self[KEY].use_color = $stdout.tty?
      end

      ##
      # Returns a global highline instance
      # @return [::HighLine]
      #
      def highline
        self[KEY]
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine:agree HighLine#agree
      #
      def agree(*args, &block)
        highline.agree(*args, &block)
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine:ask HighLine#ask
      #
      def ask(*args, &block)
        highline.ask(*args, &block)
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine:choose HighLine#choose
      #
      def choose(*args, &block)
        highline.choose(*args, &block)
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine:list HighLine#list
      #
      def list(*args, &block)
        highline.list(*args, &block)
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine:say HighLine#say
      #
      def say(*args, &block)
        highline.say(*args, &block)
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine:indent HighLine#indent
      #
      def indent(*args, &block)
        highline.indent(*args, &block)
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine:newline HighLine#newline
      #
      def newline
        highline.newline
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine:puts HighLine#puts
      #
      def puts(*args)
        highline.puts(*args)
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine:color HighLine#color
      #
      def color(*args)
        highline.color(*args)
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine:color_code HighLine#color_code
      #
      def color_code(*args)
        highline.color_code(*args)
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine:uncolor HighLine#uncolor
      #
      def uncolor(*args)
        highline.uncolor(*args)
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine:new_scope HighLine#new_scope
      #
      def new_scope
        highline.new_scope
      end
    end
  end
end
