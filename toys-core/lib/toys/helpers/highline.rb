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

gem "highline", "~> 1.7"

require "highline"

module Toys
  module Helpers
    ##
    # A module that provides access to highline.
    #
    module Highline
      ##
      # Returns a global highline instance
      # @return [::HighLine]
      #
      def self.highline
        @highline ||= ::HighLine.new
      end

      ##
      # Returns a global highline instance
      # @return [::HighLine]
      #
      def highline
        Highline.highline
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
      # @see https://www.rubydoc.info/gems/highline/HighLine.color HighLine.color
      #
      def color(*args, &block)
        ::HighLine.color(*args, &block)
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine.color_code HighLine.color_code
      #
      def color_code(*args, &block)
        ::HighLine.color_code(*args, &block)
      end

      ##
      # @see https://www.rubydoc.info/gems/highline/HighLine.uncolor HighLine.uncolor
      #
      def uncolor(*args, &block)
        ::HighLine.uncolor(*args, &block)
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
      def newline(*args, &block)
        highline.newline(*args, &block)
      end
    end
  end
end
