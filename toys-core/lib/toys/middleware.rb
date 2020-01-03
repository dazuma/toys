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
  # A middleware is an object that has the opportunity to alter the
  # configuration and runtime behavior of each tool in a Toys CLI. A CLI
  # contains an ordered list of middleware, known as the *middleware stack*,
  # that together define the CLI's default behavior.
  #
  # Specifically, a middleware can perform two functions.
  #
  # First, it can modify the configuration of a tool. After tools are defined
  # from configuration, the middleware stack can make modifications to each
  # tool. A middleware can add flags and arguments to the tool, modify the
  # description, or make any other changes to how the tool is set up.
  #
  # Second, a middleware can intercept and change tool execution. Like a Rack
  # middleware, a Toys middleware can wrap execution with its own code,
  # replace it outright, or leave it unmodified.
  #
  # Generally, a middleware is a class that implements the two methods defined
  # in this module: {Toys::Middleware#config} and {Toys::Middleware#run}. To
  # get default implementations that do nothing, a middleware can
  # `include Toys::Middleware` or subclass {Toys::Middleware::Base}, but this
  # is not required.
  #
  module Middleware
    ##
    # This method is called after a tool has been defined, and gives this
    # middleware the opportunity to modify the tool definition. It is passed
    # the tool definition object and the loader, and can make any changes to
    # the tool definition. In most cases, this method should also call
    # `yield`, which passes control to the next middleware in the stack. A
    # middleware can disable modifications done by subsequent middleware by
    # omitting the `yield` call, but this is uncommon.
    #
    # This basic implementation does nothing and simply yields to the next
    # middleware.
    #
    # @param tool [Toys::Tool] The tool definition to modify.
    # @param loader [Toys::Loader] The loader that loaded this tool.
    # @return [void]
    #
    def config(tool, loader) # rubocop:disable Lint/UnusedMethodArgument
      yield
    end

    ##
    # This method is called when the tool is run. It gives the middleware an
    # opportunity to modify the runtime behavior of the tool. It is passed
    # the tool instance (i.e. the object that hosts a tool's `run` method),
    # and you can use this object to access the tool's options and other
    # context data. In most cases, this method should also call `yield`,
    # which passes control to the next middleware in the stack. A middleware
    # can "wrap" normal execution by calling `yield` somewhere in its
    # implementation of this method, or it can completely replace the
    # execution behavior by not calling `yield` at all.
    #
    # Like a tool's `run` method, this method's return value is unused. If
    # you want to output from a tool, write to stdout or stderr. If you want
    # to set the exit status code, call {Toys::Context#exit} on the context.
    #
    # This basic implementation does nothing and simply yields to the next
    # middleware.
    #
    # @param context [Toys::Context] The tool execution context.
    # @return [void]
    #
    def run(context) # rubocop:disable Lint/UnusedMethodArgument
      yield
    end

    class << self
      ##
      # Create a middleware spec.
      #
      # @overload spec(middleware_object)
      #   Create a spec wrapping an existing middleware object
      #
      #   @param middleware_object [Toys::Middleware] The middleware object
      #   @return [Toys::Middleware::Spec] A spec
      #
      # @overload spec(name, *args, **kwargs, &block)
      #   Create a spec indicating a given middleware name should be
      #   instantiated with the given arguments.
      #
      #   @param name [String,Symbol,Class] The middleware name or class
      #   @param args [Array] The arguments to pass to the constructor
      #   @param kwargs [Hash] The keyword arguments to pass to the constructor
      #   @param block [Proc,nil] The block to pass to the constructor
      #   @return [Toys::Middleware::Spec] A spec
      #
      def spec(middleware, *args, **kwargs, &block)
        if middleware.is_a?(::String) || middleware.is_a?(::Symbol) || middleware.is_a?(::Class)
          Spec.new(nil, middleware, args, kwargs, block)
        else
          Spec.new(middleware, nil, nil, nil, nil)
        end
      end

      ##
      # Create a middleware spec from an array specification.
      #
      # The array must be 1-4 elements long. The first element must be the
      # middleware name or class. The other three arguments may include any or
      # all of the following optional elements, in any order:
      #  *  An array for the positional arguments to pass to the constructor
      #  *  A hash for the keyword arguments to pass to the constructor
      #  *  A proc for the block to pass to the constructor
      #
      # @param array [Array] The array input
      # @return [Toys::Middleware::Spec] A spec
      #
      def spec_from_array(array)
        middleware = array.first
        if !middleware.is_a?(::String) && !middleware.is_a?(::Symbol) && !middleware.is_a?(::Class)
          raise ::ArgumentError, "Bad middleware name: #{middleware.inspect}"
        end
        args = []
        kwargs = {}
        block = nil
        array.slice(1..-1).each do |param|
          case param
          when ::Array
            args += param
          when ::Hash
            kwargs = kwargs.merge(param)
          when ::Proc
            block = param
          else
            raise ::ArgumentError, "Bad param: #{param.inspect}"
          end
        end
        Spec.new(nil, middleware, args, kwargs, block)
      end

      ##
      # Resolve all arguments into an array of middleware specs. Each argument
      # may be one of the following:
      #
      #  *  A {Toys::Middleware} object
      #  *  A {Toys::Middleware::Spec}
      #  *  An array whose first element is a middleware name or class, and the
      #     subsequent elements are params that define what to pass to the class
      #     constructor (see {Toys::Middleware.spec_from_array})
      #
      # @param items [Array<Toys::Middleware,Toys::Middleware::Spec,Array>]
      # @return [Array<Toys::Middleware::Spec>]
      #
      def resolve_specs(*items)
        items.map do |item|
          case item
          when ::Array
            spec_from_array(item)
          when Spec
            item
          else
            spec(item)
          end
        end
      end
    end

    ##
    # A base class that provides default NOP implementations of the middleware
    # interface. This base class may optionally be subclassed by a middleware
    # implementation.
    #
    class Base
      include Middleware
    end

    ##
    # A middleware specification, including the middleware class and the
    # arguments to pass to the constructor.
    #
    # Use {Toys::Middleware.spec} to create a middleware spec.
    #
    class Spec
      ##
      # Builds a middleware for this spec, given a ModuleLookup for middleware.
      #
      # If this spec wraps an existing middleware object, returns that object.
      # Otherwise, constructs a middleware object from the spec.
      #
      # @param lookup [Toys::ModuleLookup] A module lookup to resolve
      #     middleware names
      # @return [Toys::Middleware] The middleware
      #
      def build(lookup)
        return @object unless @object.nil?
        if @name.is_a?(::String) || @name.is_a?(::Symbol)
          klass = lookup&.lookup(@name)
          raise ::NameError, "Unknown middleware name #{@name.inspect}" if klass.nil?
        else
          klass = @name
        end
        # Due to a bug in Ruby < 2.7, passing an empty **kwargs splat to
        # initialize will fail if there are no formal keyword args.
        formals = klass.instance_method(:initialize).parameters
        if @kwargs.empty? && formals.all? { |arg| arg.first != :key && arg.first != :keyrest }
          klass.new(*@args, &@block)
        else
          klass.new(*@args, **@kwargs, &@block)
        end
      end

      ##
      # @return [Toys::Middleware] if this spec wraps a middleware object
      # @return [nil] if this spec represents a class to instantiate
      #
      attr_reader :object

      ##
      # @return [String,Symbol] if this spec represents a middleware name
      # @return [Class] if this spec represents a middleware class
      # @return [nil] if this spec wraps a middleware object
      #
      attr_reader :name

      ##
      # @return [Array] the positional arguments to be passed to a middleware
      #     class constructor, or the empty array if there are no positional
      #     arguments
      # @return [nil] if this spec wraps a middleware object
      #
      attr_reader :args

      ##
      # @return [Hash] the keyword arguments to be passed to a middleware class
      #     constructor, or the empty hash if there are no keyword arguments
      # @return [nil] if this spec wraps a middleware object
      #
      attr_reader :kwargs

      ##
      # @return [Proc] if there is a block argument to be passed to a
      #     middleware class constructor
      # @return [nil] if there is no block argument, or this spec wraps a
      #     middleware object
      #
      attr_reader :block

      ## @private
      def initialize(object, name, args, kwargs, block)
        @object = object
        @name = name
        @args = args
        @kwargs = kwargs
        @block = block
      end
    end
  end
end
