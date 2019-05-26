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
  module Definition
    ##
    # An Acceptor validates and converts arguments. It is designed to be
    # compatible with the OptionParser accept mechanism.
    #
    # First, an acceptor validates an argument via the {#match} method. This
    # method should determine whether the argument is valid, and return
    # information that will help with conversion of the argument.
    #
    # Second, an acceptor converts the argument from the input string to its
    # final form via the {#convert} method.
    #
    # Finally, an acceptor has a name that may appear in help text for flags
    # and arguments that use it.
    #
    class Acceptor
      ##
      # Create a base acceptor.
      #
      # The base acceptor does not do any validation (i.e. it accepts all
      # arguments) or conversion (i.e. it returns the original string).
      # You may subclass this object and override the {#match} and {#convert}
      # methods to change this behavior.
      #
      # @param [String] name A visible name for the acceptor, shown in help.
      #
      def initialize(name)
        @name = name
      end

      ##
      # Name of the acceptor
      # @return [String]
      #
      attr_reader :name

      ##
      # Name of the acceptor
      # @return [String]
      #
      def to_s
        name.to_s
      end

      ##
      # Validate the given input.
      #
      # When given a valid input, return an array in which the first element is
      # the original input string, and the remaining elements (which may be
      # empty) comprise any additional information that may be useful during
      # conversion. If there is no additional information, you may return the
      # original input string by itself without wrapping in an array.
      #
      # When given an invalid input, return a falsy value such as `nil`.
      #
      # Note that a `MatchData` object is a legitimate return value because it
      # duck-types the appropriate array.
      #
      # This default implementation simply returns the original input string,
      # indicating all inputs are valid. You may override this method to
      # specify a validation function.
      #
      # @param [String,nil] str Input argument string. May be `nil` if the
      #     value is optional and not provided.
      # @return [String,Array,nil]
      #
      def match(str)
        str
      end

      ##
      # Convert the given input.
      #
      # This method is passed the results of a successful match, including the
      # original input string and any other values returned from {#match}. It
      # must return the final converted value to use.
      #
      # @param [String,nil] str Original argument string. May be `nil` if the
      #     value is optional and not provided.
      # @param [Object...] _extra Zero or more additional arguments comprising
      #     additional elements returned from the match function.
      # @return [Object] The converted argument as it should be stored in the
      #     context data.
      #
      def convert(str, *_extra)
        str
      end
    end

    ##
    # An acceptor that uses a simple function to validate and convert input.
    # The function must take the input string as its argument, and either
    # return the converted object to indicate success, or raise an exception or
    # return the sentinel {Toys::Definition::SimpleAcceptor::REJECT} to
    # indicate invalid input.
    #
    class SimpleAcceptor < Acceptor
      ##
      # A sentinel that may be returned from the function to indicate invalid
      # input.
      # @return [Object]
      #
      REJECT = ::Object.new.freeze

      ##
      # Create a simple acceptor.
      #
      # You should provide an acceptor function, either as a proc in the
      # `function` argument, or as a block. The function must take as its one
      # argument the input string. If the string is valid, the function must
      # return the value to store in the tool's data. If the string is invalid,
      # the function may either raise an exception (which must descend from
      # `StandardError`) or return {Toys::Definition::SimpleAcceptor::REJECT}.
      #
      # @param [String] name A visible name for the acceptor, shown in help.
      # @param [Proc] function The acceptor function
      #
      def initialize(name, function = nil, &block)
        super(name)
        @function = function || block || proc { |s| s }
      end

      ##
      # Overrides {Toys::Definition::Acceptor#match} to use the given function.
      #
      def match(str)
        result = @function.call(str) rescue REJECT # rubocop:disable Style/RescueModifier
        result.equal?(REJECT) ? nil : [str, result]
      end

      ##
      # Overrides {Toys::Definition::Acceptor#convert} to use the given
      # function's result.
      #
      def convert(_str, result)
        result
      end
    end

    ##
    # An acceptor that uses a regex to validate input. It also supports a
    # custom conversion function that can be passed to the constructor as a
    # proc or a block.
    #
    class PatternAcceptor < Acceptor
      ##
      # Create a pattern acceptor.
      #
      # You must provide a regular expression or any object that duck-types
      # `Regexp#match`) as a validator.
      #
      # You may also optionally provide a converter, either as a proc or a
      # block. A converter must take as its arguments the values in the
      # `MatchData` returned from a successful regex match. That is, the first
      # argument is the original input string, and the remaining arguments are
      # the captures. The converter must return the final converted value.
      # If no converter is provided, no conversion is done and the input string
      # is returned.
      #
      # @param [String] name A visible name for the acceptor, shown in help.
      # @param [Regexp] regex Regular expression defining value values.
      # @param [Proc] converter A converter function. May also be given as a
      #     block. Note that the converter will be passed all elements of
      #     the `MatchData`.
      #
      def initialize(name, regex, converter = nil, &block)
        super(name)
        @regex = regex
        @converter = converter || block
      end

      ##
      # Overrides {Toys::Definition::Acceptor#match} to use the given regex.
      #
      def match(str)
        str.nil? ? nil : @regex.match(str)
      end

      ##
      # Overrides {Toys::Definition::Acceptor#convert} to use the given
      # converter.
      #
      def convert(str, *extra)
        @converter ? @converter.call(str, *extra) : str
      end
    end

    ##
    # An acceptor that recognizes a fixed set of values.
    #
    # You provide a list of valid values. The input argument string will be
    # matched against the string forms of these valid values. If it matches,
    # the converter will return the actual value from the valid list.
    #
    # For example, you could pass `[:one, :two, 3]` as the set of values. If
    # an argument of `"two"` is passed in, the converter will yield a final
    # value of the symbol `:two`. If an argument of "3" is passed in, the
    # converter will yield the integer `3`. If an argument of "three" is
    # passed in, the match will fail.
    #
    class EnumAcceptor < Acceptor
      ##
      # Create an acceptor.
      #
      # @param [String] name A visible name for the acceptor, shown in help.
      # @param [Array] values Valid values.
      #
      def initialize(name, values)
        super(name)
        @values = Array(values).map { |v| [v.to_s, v] }
      end

      ##
      # Overrides {Toys::Definition::Acceptor#match} to find the value.
      #
      def match(str)
        @values.find { |s, _e| s == str }
      end

      ##
      # Overrides {Toys::Definition::Acceptor#convert} to return the actual
      # enum element.
      #
      def convert(_str, elem)
        elem
      end
    end

    class Acceptor # rubocop:disable Style/Documentation
      class << self
        ##
        # Resolve a standard acceptor name recognized by OptionParser.
        #
        # @param [Object] name Name of the acceptor. Recognizes names of
        #     the OptionParser-provided acceptors, such as `String`, `Integer`,
        #     `Array`, `OptionParser::DecimalInteger`, etc.
        # @return [Toys::Definition::Acceptor] an acceptor
        #
        def resolve_default(name)
          result = standard_defaults[name]
          if result.nil? && defined?(::OptionParser)
            result = optparse_defaults[name]
          end
          result
        end

        private

        def standard_defaults
          @standard_defaults ||= {
            ::Object => new(::Object),
            ::NilClass => new(::NilClass),
            ::String => build_string,
            ::Integer => build_integer,
            ::Float => build_float,
            ::Rational => build_rational,
            ::Numeric => build_numeric,
            ::TrueClass => build_boolean(::TrueClass),
            ::FalseClass => build_boolean(::FalseClass),
            ::Array => build_array,
            ::Regexp => build_regexp
          }
        end

        def optparse_defaults
          @optparse_defaults ||= {
            ::OptionParser::DecimalInteger => build_decimal_integer,
            ::OptionParser::OctalInteger => build_octal_integer,
            ::OptionParser::DecimalNumeric => build_decimal_numeric
          }
        end

        def build_string
          PatternAcceptor.new(::String, /.+/m)
        end

        def build_integer
          SimpleAcceptor.new(::Integer) { |s| Integer(s) }
        end

        def build_float
          SimpleAcceptor.new(::Float) { |s| Float(s) }
        end

        def build_rational
          SimpleAcceptor.new(::Rational) { |s| Rational(s) }
        end

        def build_numeric
          SimpleAcceptor.new(::Numeric) do |s|
            if s.nil?
              SimpleAcceptor::REJECT
            elsif s.include?("/")
              Rational(s)
            elsif s.include?(".")
              Float(s)
            else
              Integer(s)
            end
          end
        end

        def build_boolean(name)
          SimpleAcceptor.new(name) do |s|
            if s
              s = s.downcase
              if s == "+" || "true".start_with?(s) || "yes".start_with?(s)
                true
              elsif s == "-" || "false".start_with?(s) || "no".start_with?(s)
                false
              else
                SimpleAcceptor::REJECT
              end
            else
              SimpleAcceptor::REJECT
            end
          end
        end

        def build_array
          SimpleAcceptor.new(::Array) do |s|
            if s
              s.split(",").collect { |elem| elem unless elem.empty? }
            else
              SimpleAcceptor::REJECT
            end
          end
        end

        def build_regexp
          SimpleAcceptor.new(::Regexp) do |s|
            if s
              flags = 0
              if s =~ %r{\A/((?:\\.|[^\\])*)/([[:alpha:]]+)?\z}
                s = $1
                opts = $2
                flags |= ::Regexp::IGNORECASE if opts.include?("i")
                flags |= ::Regexp::MULTILINE if opts.include?("m")
                flags |= ::Regexp::EXTENDED if opts.include?("x")
              end
              Regexp.new(s, flags)
            else
              SimpleAcceptor::REJECT
            end
          end
        end

        def build_decimal_integer
          SimpleAcceptor.new(::OptionParser::DecimalInteger) { |s| Integer(s, 10) }
        end

        def build_octal_integer
          SimpleAcceptor.new(::OptionParser::OctalInteger) { |s| Integer(s, 8) }
        end

        def build_decimal_numeric
          SimpleAcceptor.new(::OptionParser::DecimalNumeric) do |s|
            if s.nil?
              SimpleAcceptor::REJECT
            elsif s.include?(".")
              Float(s)
            else
              Integer(s, 10)
            end
          end
        end
      end
    end
  end
end
