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
  ##
  # A mixin definition. Mixin modules should include this module.
  #
  # A mixin is a collection of methods that are available to be called from a
  # tool implementation (i.e. its run method). The mixin is added to the tool
  # class, so it has access to the same methods that can be called by the tool,
  # such as {Toys::Context#option}.
  #
  # ## Usage
  #
  # To create a mixin, define a module, and include this module. Then define
  # the methods you want to be available.
  #
  # If you want to perform some initialization specific to the mixin, you can
  # provide a `to_initialize` block and/or a `to_include` block.
  #
  # The `to_initialize` block is called when the tool itself is instantiated.
  # It has access to tool methods such as {Toys::Context#option}, and can
  # perform setup for the tool execution itself, often involving initializing
  # some persistent state and storing it in the tool using {Toys::Context#set}.
  # The `to_initialize` block is passed any extra arguments that were provided
  # to the `include` directive.
  #
  # The `to_include` block is called in the context of your tool class when
  # your mixin is included. It is also passed any extra arguments that were
  # provided to the `include` directive. It can be used to issue directives
  # or define methods on the DSL, specific to the mixin.
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
      mod.extend(ModuleMethods)
    end

    ##
    # Methods that will be added to a mixin module object.
    #
    module ModuleMethods
      ##
      # Provide a block that initializes this mixin when the tool is
      # constructed.
      #
      def to_initialize(&block)
        self.initialization_callback = block
      end

      ##
      # Provide a block that modifies the tool class when the mixin is
      # included.
      #
      def to_include(&block)
        self.inclusion_callback = block
      end

      ##
      # You may alternately set the initializer block using this accessor.
      # @return [Proc]
      #
      attr_accessor :initialization_callback

      ##
      # You may alternately set the inclusion block using this accessor.
      # @return [Proc]
      #
      attr_accessor :inclusion_callback
    end
  end
end
