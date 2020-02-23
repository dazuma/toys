# frozen_string_literal: true

module Toys
  ##
  # A mixin definition. Mixin modules should include this module.
  #
  # A mixin is a collection of methods that are available to be called from a
  # tool implementation (i.e. its run method). The mixin is added to the tool
  # class, so it has access to the same methods that can be called by the tool,
  # such as {Toys::Context#get}.
  #
  # ## Usage
  #
  # To create a mixin, define a module, and include this module. Then define
  # the methods you want to be available.
  #
  # If you want to perform some initialization specific to the mixin, you can
  # provide an *initializer* block and/or an *inclusion* block. These can be
  # specified by calling the module methods defined in
  # {Toys::Mixin::ModuleMethods}.
  #
  # The initializer block is called when the tool context is instantiated
  # in preparation for execution. It has access to context methods such as
  # {Toys::Context#get}, and can perform setup for the tool execution itself,
  # such as initializing some persistent state and storing it in the tool using
  # {Toys::Context#set}. The initializer block is passed any extra arguments
  # that were provided to the `include` directive. Define the initializer by
  # calling {Toys::Mixin::ModuleMethods#on_initialize}.
  #
  # The inclusion block is called in the context of your tool class when your
  # mixin is included. It is also passed any extra arguments that were provided
  # to the `include` directive. It can be used to issue directives to define
  # tools or other objects in the DSL, or even enhance the DSL by defining DSL
  # methods specific to the mixin. Define the inclusion block by calling
  # {Toys::Mixin::ModuleMethods#on_include}.
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
  #       # Initialize the counter. Notice that the initializer is evaluated
  #       # in the context of the runtime context, so has access to the runtime
  #       # context state.
  #       on_initialize do |start = 0|
  #         set(:counter_value, start)
  #       end
  #
  #       # Mixin methods are evaluated in the runtime context and so have
  #       # access to the runtime context state, just as if you had defined
  #       # them in your tool.
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
    ##
    # Create a mixin module with the given block.
    #
    # @param block [Proc] Defines the mixin module.
    # @return [Class]
    #
    def self.create(&block)
      mixin_mod = ::Module.new do
        include ::Toys::Mixin
      end
      mixin_mod.module_eval(&block) if block
      mixin_mod
    end

    ## @private
    def self.included(mod)
      return if mod.respond_to?(:on_initialize)
      mod.extend(ModuleMethods)
    end

    ##
    # Methods that will be added to a mixin module object.
    #
    module ModuleMethods
      ##
      # Set the initializer for this mixin. This block is evaluated in the
      # runtime context before execution, and is passed any arguments provided
      # to the `include` directive. It can perform any runtime initialization
      # needed by the mixin.
      #
      # @param block [Proc] Sets the initializer proc.
      # @return [self]
      #
      def on_initialize(&block)
        self.initializer = block
        self
      end

      ##
      # The initializer proc for this mixin. This proc is evaluated in the
      # runtime context before execution, and is passed any arguments provided
      # to the `include` directive. It can perform any runtime initialization
      # needed by the mixin.
      #
      # @return [Proc] The iniitiliazer for this mixin.
      #
      attr_accessor :initializer

      ##
      # Set an inclusion proc for this mixin. This block is evaluated in the
      # tool class immediately after the mixin is included, and is passed any
      # arguments provided to the `include` directive.
      #
      # @param block [Proc] Sets the inclusion proc.
      # @return [self]
      #
      def on_include(&block)
        self.inclusion = block
        self
      end

      ##
      # The inclusion proc for this mixin. This block is evaluated in the tool
      # class immediately after the mixin is included, and is passed any
      # arguments provided to the `include` directive.
      #
      # @return [Proc] The inclusion procedure for this mixin.
      #
      attr_accessor :inclusion
    end
  end
end
