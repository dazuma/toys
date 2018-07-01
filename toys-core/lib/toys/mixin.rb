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
  ##
  # A mixin definition. Mixin modules should include this module.
  #
  # A mixin is a collection of methods that are available to be called from a
  # tool implementation (i.e. its run method). The mixin is added to the tool
  # class, so it has access to the same methods that can be called by the tool,
  # such as {Toys::Tool#option}.
  #
  # ## Usage
  #
  # To create a mixin, define a module, and include this module. Then define
  # the methods you want to be available.
  #
  # If you want to perform some initialization specific to the mixin, use a
  # `to_initialize` block. This block is passed any extra arguments that were
  # passed to the `include` directive. It is called in the context of the tool,
  # so it also has access to tool methods such as {Toys::Tool#option}. It can
  # perform any setup required, which often involves initializing some
  # persistent state and storing it in the tool using {Toys::Tool#set}.
  #
  # ## Example
  #
  # This is an example that implements a simple counter. Whenever the counter
  # is incremented, a log message is emitted. The tool can also retrieve the
  # final counter value.
  #
  #     # Define a mixin by creating a module that includes Toys::Mixin
  #     module MyCounterMixin
  #       include Toys::Mixin
  #
  #       # Initialize the counter. Called with self set to the tool so it can
  #       # affect the tool state.
  #       to_initialize do |start = 0|
  #         set(:counter_value, start)
  #       end
  #
  #       # Mixin methods are called with self set to the tool and can affect
  #       # the tool state.
  #       def counter_value
  #         get(:counter_value)
  #       end
  #
  #       def increment
  #         set(:counter_value, counter_value + 1)
  #         logger.info("Incremented counter")
  #       end
  #     end
  #
  # Now we can use it from a tool:
  #
  #     tool "count-up" do
  #       # Pass 1 as an extra argument to the mixin initializer
  #       include MyCounterMixin, 1
  #
  #       def run
  #         # Mixin methods can be called.
  #         5.times { increment }
  #         puts "Final value is #{counter_value}"
  #       end
  #     end
  #
  module Mixin
    ## @private
    def self.included(mod)
      return if mod.respond_to?(:to_initialize)
      mod.extend(ClassMethods)
    end

    ##
    # Class methods that will be added to a mixin module.
    #
    module ClassMethods
      ##
      # Provide the block that initializes this mixin.
      #
      def to_initialize(&block)
        self.initializer = block
      end

      ##
      # You may alternately set the initializer block using this accessor.
      # @return [Proc]
      #
      attr_accessor :initializer
    end
  end
end
