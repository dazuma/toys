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
  # An Acceptor validates and converts arguments. It is designed to be
  # compatible with the OptionParser accept mechanism.
  #
  # First, an acceptor validates the argument via its
  # {Toys::Acceptor::Base#match} method. This method should determine whether
  # the argument is valid, and return information that will help with
  # conversion of the argument.
  #
  # Second, an acceptor converts the argument to its final form via the
  # {Toys::Acceptor::Base#convert} method.
  #
  # Finally, an acceptor has a name that may appear in help text for flags and
  # arguments that use it.
  #
  module Acceptor
    ##
    # A sentinel that may be returned from a function-based acceptor to
    # indicate invalid input.
    # @return [Object]
    #
    REJECT = ::Object.new.freeze

    ##
    # The default type description.
    # @return [String]
    #
    DEFAULT_TYPE_DESC = "string"

    ##
    # A base class for acceptors.
    #
    # The base acceptor does not do any validation (i.e. it accepts all
    # arguments) or conversion (i.e. it returns the original string). You can
    # subclass this base class and override the {#match} and {#convert} methods
    # to implement an acceptor.
    #
    class Base
      ##
      # Create a base acceptor.
      #
      # @param [String] type_desc Type description string, shown in help.
      #     Defaults to {Toys::Acceptor::DEFAULT_TYPE_DESC}.
      # @param [Object] well_known_spec The well-known acceptor spec associated
      #     with this acceptor, or `nil` for none.
      #
      def initialize(type_desc: nil, well_known_spec: nil)
        @type_desc = type_desc || DEFAULT_TYPE_DESC
        @well_known_spec = well_known_spec
      end

      ##
      # Type description string, shown in help.
      # @return [String]
      #
      attr_reader :type_desc

      ##
      # The well-known acceptor spec associated with this acceptor, if any.
      # This generally identifies an OptionParser-compatible acceptor spec. For
      # example, the acceptor object that corresponds to `Integer` will return
      # `Integer` from this attribute.
      #
      # @return [Object,nil]
      #
      attr_reader :well_known_spec

      ##
      # Type description string, shown in help.
      # @return [String]
      #
      def to_s
        type_desc.to_s
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
      # as the only array element, indicating all inputs are valid. You can
      # override this method to provide a different validation function.
      #
      # @param [String,nil] str The input argument string. May be `nil` if the
      #     value is optional and not provided.
      # @return [String,Array,nil]
      #
      def match(str)
        [str]
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
      # @param [Object...] extra Zero or more additional arguments comprising
      #     additional elements returned from the match function.
      # @return [Object] The converted argument as it should be stored in the
      #     context data.
      #
      def convert(str, *extra) # rubocop:disable Lint/UnusedMethodArgument
        str
      end
    end

    ##
    # The default acceptor. Corresponds to the well-known acceptor for
    # `NilClass`.
    # @return [Toys::Acceptor::Base]
    #
    DEFAULT = Base.new(type_desc: "string", well_known_spec: ::NilClass)

    ##
    # An acceptor that uses a simple function to validate and convert input.
    # The function must take the input string as its argument, and either
    # return the converted object to indicate success, or raise an exception or
    # return the sentinel {Toys::Acceptor::REJECT} to indicate invalid input.
    #
    class Simple < Base
      ##
      # Create a simple acceptor.
      #
      # You should provide an acceptor function, either as a proc in the
      # `function` argument, or as a block. The function must take as its one
      # argument the input string. If the string is valid, the function must
      # return the value to store in the tool's data. If the string is invalid,
      # the function may either raise an exception (which must descend from
      # `StandardError`) or return {Toys::Acceptor::REJECT}.
      #
      # @param [Proc] function The acceptor function
      # @param [String] type_desc Type description string, shown in help.
      #     Defaults to {Toys::Acceptor::DEFAULT_TYPE_DESC}.
      # @param [Object] well_known_spec The well-known acceptor spec associated
      #     with this acceptor, or `nil` for none.
      #
      def initialize(function = nil, type_desc: nil, well_known_spec: nil, &block)
        super(type_desc: type_desc, well_known_spec: well_known_spec)
        @function = function || block || proc { |s| s }
      end

      ##
      # Overrides {Toys::Acceptor::Base#match} to use the given function.
      #
      def match(str)
        result = @function.call(str) rescue REJECT # rubocop:disable Style/RescueModifier
        result.equal?(REJECT) ? nil : [str, result]
      end

      ##
      # Overrides {Toys::Acceptor::Base#convert} to use the given function's
      # result.
      #
      def convert(_str, result)
        result
      end
    end

    ##
    # An acceptor that uses a regex to validate input. It also supports a
    # custom conversion function that generates the final value from the match
    # results.
    #
    class Pattern < Base
      ##
      # Create a pattern acceptor.
      #
      # You must provide a regular expression (or any object that duck-types
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
      # @param [Regexp] regex Regular expression defining value values.
      # @param [Proc] converter A converter function. May also be given as a
      #     block. Note that the converter will be passed all elements of
      #     the `MatchData`.
      # @param [String] type_desc Type description string, shown in help.
      #     Defaults to {Toys::Acceptor::DEFAULT_TYPE_DESC}.
      # @param [Object] well_known_spec The well-known acceptor spec associated
      #     with this acceptor, or `nil` for none.
      #
      def initialize(regex, converter = nil, type_desc: nil, well_known_spec: nil, &block)
        super(type_desc: type_desc, well_known_spec: well_known_spec)
        @regex = regex
        @converter = converter || block
      end

      ##
      # Overrides {Toys::Acceptor::Base#match} to use the given regex.
      #
      def match(str)
        str.nil? ? [nil] : @regex.match(str)
      end

      ##
      # Overrides {Toys::Acceptor::Base#convert} to use the given converter.
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
    class Enum < Base
      ##
      # Create an acceptor.
      #
      # @param [Array] values Valid values.
      # @param [String] type_desc Type description string, shown in help.
      #     Defaults to {Toys::Acceptor::DEFAULT_TYPE_DESC}.
      # @param [Object] well_known_spec The well-known acceptor spec associated
      #     with this acceptor, or `nil` for none.
      #
      def initialize(values, type_desc: nil, well_known_spec: nil)
        super(type_desc: type_desc, well_known_spec: well_known_spec)
        @values = Array(values).map { |v| [v.to_s, v] }
      end

      ##
      # Overrides {Toys::Acceptor::Base#match} to find the value.
      #
      def match(str)
        str.nil? ? [nil, nil] : @values.find { |s, _e| s == str }
      end

      ##
      # Overrides {Toys::Acceptor::Base#convert} to return the actual enum
      # element.
      #
      def convert(_str, elem)
        elem
      end
    end

    ##
    # An acceptor that recognizes a range of values.
    #
    # The input argument is matched against the given range. For example, you
    # can match against the integers from 1 to 10 by passing the range
    # `(1..10)`.
    #
    # You can also provide a conversion function that takes the input string
    # and converts it an object that can be compared by the range. If you do
    # not provide a converter, a default converter will be provided depending
    # on the types of objects serving as the range limits. Specifically:
    #
    # *   If the range beginning and end are both `Integer`, then input strings
    #     are likewise converted to `Integer` when matched against the range.
    #     Accepted values are returned as integers.
    # *   If the range beginning and end are both `Float`, then input strings
    #     are likewise converted to `Float`.
    # *   If the range beginning and end are both `Rational`, then input
    #     strings are likewise converted to `Rational`.
    # *   If the range beginning and end are both `Numeric` types but different
    #     subtypes (e.g. an `Integer` and a `Float`), then any type of numeric
    #     input (integer, float, rational) is accepted and matched against the
    #     range.
    # *   If the range beginning and/or end are not numeric types, then no
    #     conversion is done by default.
    #
    class Range < Simple
      ##
      # Create an acceptor.
      #
      # @param [Range] range The range of acceptable values
      # @param [Proc] converter A converter proc that takes an input string and
      #     attempts to convert it to a type comparable by the range. For
      #     numeric ranges, this can be omitted because one is provided by
      #     default. You should provide a converter for other types of ranges.
      #     You can also pass the converter as a block.
      # @param [String] type_desc Type description string, shown in help.
      #     Defaults to {Toys::Acceptor::DEFAULT_TYPE_DESC}.
      # @param [Object] well_known_spec The well-known acceptor spec associated
      #     with this acceptor, or `nil` for none.
      #
      def initialize(range, converter = nil, type_desc: nil, well_known_spec: nil, &block)
        converter ||= block || make_converter(range.begin, range.end)
        super(type_desc: type_desc, well_known_spec: well_known_spec) do |val|
          val = converter.call(val) if converter
          val.nil? || range.include?(val) ? val : REJECT
        end
        @range = range
      end

      ##
      # The range being checked.
      # @return [Range]
      #
      attr_reader :range

      private

      def make_converter(val1, val2)
        if val1.is_a?(::Integer) && val2.is_a?(::Integer)
          INTEGER_CONVERTER
        elsif val1.is_a?(::Float) && val2.is_a?(::Float)
          FLOAT_CONVERTER
        elsif val1.is_a?(::Rational) && val2.is_a?(::Rational)
          RATIONAL_CONVERTER
        elsif val1.is_a?(::Numeric) && val2.is_a?(::Numeric)
          NUMERIC_CONVERTER
        end
      end
    end

    ##
    # A converter proc that handles integers. Useful in Simple and Range
    # acceptors.
    # @return [Proc]
    #
    INTEGER_CONVERTER = proc { |s| s.nil? ? nil : Integer(s) }

    ##
    # A converter proc that handles floats. Useful in Simple and Range
    # acceptors.
    # @return [Proc]
    #
    FLOAT_CONVERTER = proc { |s| s.nil? ? nil : Float(s) }

    ##
    # A converter proc that handles rationals. Useful in Simple and Range
    # acceptors.
    # @return [Proc]
    #
    RATIONAL_CONVERTER = proc { |s| s.nil? ? nil : Rational(s) }

    ##
    # A converter proc that handles any numeric value. Useful in Simple and
    # Range acceptors.
    # @return [Proc]
    #
    NUMERIC_CONVERTER =
      proc do |s|
        if s.nil?
          nil
        elsif s.include?("/")
          Rational(s)
        elsif s.include?(".") || (s.include?("e") && s !~ /\A-?0x/)
          Float(s)
        else
          Integer(s)
        end
      end

    class << self
      ##
      # Lookup a standard acceptor name recognized by OptionParser.
      #
      # @param [Object] spec A well-known acceptor specification, such as
      #     `String`, `Integer`, `Array`, `OptionParser::DecimalInteger`, etc.
      # @return [Toys::Acceptor::Base,nil] The corresponding Acceptor object,
      #     or nil if not found.
      #
      def lookup_well_known(spec)
        result = standard_well_knowns[spec]
        if result.nil? && defined?(::OptionParser)
          result = optparse_well_knowns[spec]
        end
        result
      end

      ##
      # Create an acceptor from a variety of specification formats. The
      # acceptor is constructed from the given specification object and/or the
      # given block. Additionally, some acceptors can take an optional type
      # description string used to describe the type of data in online help.
      #
      # Recognized specs include:
      #
      # *   Any well-known acceptor recognized by OptionParser, such as
      #     `Integer`, `Array`, or `OptionParser::DecimalInteger`. Any block
      #     and type description you provide are ignored.
      #
      # *   Any **regular expression**. The returned acceptor validates only if
      #     the regex matches the *entire string parameter*.
      #
      #     You can also provide an optional conversion function as a block. If
      #     provided, the block must take a variable number of arguments, the
      #     first being the matched string and the remainder being the captures
      #     from the regular expression. It should return the converted object
      #     that will be stored in the context data. If you do not provide a
      #     block, no conversion takes place, and the original string is used.
      #
      # *   An **array** of possible values. The acceptor validates if the
      #     string parameter matches the *string form* of one of the array
      #     elements (i.e. the results of calling `to_s` on the element.)
      #
      #     An array acceptor automatically converts the string parameter to
      #     the actual array element that it matched. For example, if the
      #     symbol `:foo` is in the array, it will match the string `"foo"`,
      #     and then store the symbol `:foo` in the tool data. You may not
      #     further customize the conversion function; any block is ignored.
      #
      # *   A **range** of possible values. The acceptor validates if the
      #     string parameter, after conversion to the range type, lies within
      #     the range. The final value stored in context data is the converted
      #     value. For numeric ranges, conversion is provided, but if the range
      #     has a different type, you must provide the conversion function as
      #     a block.
      #
      # *   A **function** as a Proc (where the block is ignored) or a block
      #     (if the spec is nil). This function performs *both* validation and
      #     conversion. It should take the string parameter as its argument,
      #     and it must either return the object that should be stored in the
      #     tool data, or raise an exception (descended from `StandardError`)
      #     to indicate that the string parameter is invalid. You may also
      #     return the sentinel value {Toys::Acceptor::REJECT} to indicate that
      #     the string is invalid.
      #
      # *   The value `nil` with no block, to indicate the default pass-through
      #     acceptor {Toys::Acceptor::DEFAULT}. Any type description you
      #     provide is ignored.
      #
      # @param [Object] spec The spec. See above for recognized values.
      # @param [String] type_desc The type description for interpolating into
      #     help text. Ignored if the spec indicates the default acceptor or a
      #     well-known acceptor.
      # @return [Toys::Acceptor::Base,Proc]
      #
      def create(spec = nil, type_desc: nil, &block)
        well_known = lookup_well_known(spec)
        return well_known if well_known
        case spec
        when Base
          spec
        when ::Regexp
          Pattern.new(spec, type_desc: type_desc, &block)
        when ::Array
          Enum.new(spec, type_desc: type_desc)
        when ::Proc
          Simple.new(spec, type_desc: type_desc)
        when ::Range
          Range.new(spec, type_desc: type_desc, &block)
        when nil, :default
          block ? Simple.new(type_desc: type_desc, &block) : DEFAULT
        else
          raise ToolDefinitionError, "Illegal acceptor spec: #{spec.inspect}"
        end
      end

      private

      def standard_well_knowns
        @standard_well_knowns ||= {
          ::Object => build_object,
          ::NilClass => DEFAULT,
          ::String => build_string,
          ::Integer => build_integer,
          ::Float => build_float,
          ::Rational => build_rational,
          ::Numeric => build_numeric,
          ::TrueClass => build_boolean(::TrueClass, true),
          ::FalseClass => build_boolean(::FalseClass, false),
          ::Array => build_array,
          ::Regexp => build_regexp,
        }
      end

      def optparse_well_knowns
        @optparse_well_knowns ||= {
          ::OptionParser::DecimalInteger => build_decimal_integer,
          ::OptionParser::OctalInteger => build_octal_integer,
          ::OptionParser::DecimalNumeric => build_decimal_numeric,
        }
      end

      def build_object
        Simple.new(type_desc: "string", well_known_spec: ::Object) do |s|
          s.nil? ? true : s
        end
      end

      def build_string
        Pattern.new(/.+/m, type_desc: "nonempty string", well_known_spec: ::String)
      end

      def build_integer
        Simple.new(INTEGER_CONVERTER, type_desc: "integer", well_known_spec: ::Integer)
      end

      def build_float
        Simple.new(FLOAT_CONVERTER, type_desc: "floating point number", well_known_spec: ::Float)
      end

      def build_rational
        Simple.new(RATIONAL_CONVERTER, type_desc: "rational number", well_known_spec: ::Rational)
      end

      def build_numeric
        Simple.new(NUMERIC_CONVERTER, type_desc: "number", well_known_spec: ::Numeric)
      end

      TRUE_STRINGS = ["+", "true", "yes"].freeze
      FALSE_STRINGS = ["-", "false", "no", "nil"].freeze
      private_constant :TRUE_STRINGS, :FALSE_STRINGS

      def build_boolean(spec, default)
        Simple.new(type_desc: "boolean", well_known_spec: spec) do |s|
          if s.nil?
            default
          else
            s = s.downcase
            if s.empty?
              REJECT
            elsif TRUE_STRINGS.any? { |t| t.start_with?(s) }
              true
            elsif FALSE_STRINGS.any? { |f| f.start_with?(s) }
              false
            else
              REJECT
            end
          end
        end
      end

      def build_array
        Simple.new(type_desc: "string array", well_known_spec: ::Array) do |s|
          if s.nil?
            nil
          else
            s.split(",").collect { |elem| elem unless elem.empty? }
          end
        end
      end

      def build_regexp
        Simple.new(type_desc: "regular expression", well_known_spec: ::Regexp) do |s|
          if s.nil?
            nil
          else
            flags = 0
            if (match = %r{\A/((?:\\.|[^\\])*)/([[:alpha:]]*)\z}.match(s))
              s = match[1]
              opts = match[2] || ""
              flags |= ::Regexp::IGNORECASE if opts.include?("i")
              flags |= ::Regexp::MULTILINE if opts.include?("m")
              flags |= ::Regexp::EXTENDED if opts.include?("x")
            end
            ::Regexp.new(s, flags)
          end
        end
      end

      def build_decimal_integer
        Simple.new(type_desc: "decimal integer",
                   well_known_spec: ::OptionParser::DecimalInteger) do |s|
          s.nil? ? nil : Integer(s, 10)
        end
      end

      def build_octal_integer
        Simple.new(type_desc: "octal integer",
                   well_known_spec: ::OptionParser::OctalInteger) do |s|
          s.nil? ? nil : Integer(s, 8)
        end
      end

      def build_decimal_numeric
        Simple.new(type_desc: "decimal number",
                   well_known_spec: ::OptionParser::DecimalNumeric) do |s|
          if s.nil?
            nil
          elsif s.include?(".") || (s.include?("e") && s !~ /\A-?0x/)
            Float(s)
          else
            Integer(s, 10)
          end
        end
      end
    end
  end
end
