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
    # arguments) or conversion (i.e. it returns the original string).
    # You may subclass this object and override the {#match} and {#convert}
    # methods to change this behavior.
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
      # indicating all inputs are valid. You may override this method to
      # specify a validation function.
      #
      # @param [String,nil] str Input argument string. May be `nil` if the
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
    # The default acceptor.
    # @return [Toys::Acceptor::Base]
    #
    DEFAULT = Base.new(type_desc: "string", well_known_spec: ::NilClass)

    ##
    # An acceptor that uses a simple function to validate and convert input.
    # The function must take the input string as its argument, and either
    # return the converted object to indicate success, or raise an exception or
    # return the sentinel {Toys::Acceptor::REJECT} to
    # indicate invalid input.
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
      # Overrides {Toys::Acceptor::Base#convert} to use the given
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
    class Pattern < Base
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
      # Overrides {Toys::Acceptor::Base#convert} to use the given
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
      # Overrides {Toys::Acceptor::Base#convert} to return the actual
      # enum element.
      #
      def convert(_str, elem)
        elem
      end
    end

    class << self
      ##
      # Resolve a standard acceptor name recognized by OptionParser.
      #
      # @param [Object] spec A well-known acceptor specification, such as
      #     `String`, `Integer`, `Array`, `OptionParser::DecimalInteger`, etc.
      # @return [Toys::Acceptor::Base,nil] The corresponding Acceptor object,
      #     or nil if not found.
      #
      def resolve_well_known(spec)
        result = standard_well_knowns[spec]
        if result.nil? && defined?(::OptionParser)
          result = optparse_well_knowns[spec]
        end
        result
      end

      ##
      # Resolve an acceptor object from the given spec, which may be an
      # acceptor object, a well-known acceptor, or nil for the default.
      #
      # @param [Object] spec
      # @return [Toys::Acceptor::Base] The acceptor object
      # @raise [Toys::ToolDefinitionError] if the input could not be resolved.
      #
      def resolve(spec)
        return spec if spec.is_a?(Base)
        return DEFAULT if spec.nil?
        well_known = resolve_well_known(spec)
        return well_known if well_known
        raise ToolDefinitionError, "Unknown acceptor: #{spec.inspect}"
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
        Simple.new(type_desc: "integer", well_known_spec: ::Integer) do |s|
          s.nil? ? nil : Integer(s)
        end
      end

      def build_float
        Simple.new(type_desc: "floating point number", well_known_spec: ::Float) do |s|
          s.nil? ? nil : Float(s)
        end
      end

      def build_rational
        Simple.new(type_desc: "rational number", well_known_spec: ::Rational) do |s|
          s.nil? ? nil : Rational(s)
        end
      end

      def build_numeric
        Simple.new(type_desc: "number", well_known_spec: ::Numeric) do |s|
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
      end

      TRUE_STRINGS = ["+", "true", "yes"].freeze
      FALSE_STRINGS = ["-", "false", "no", "nil"].freeze

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
            if s =~ %r{\A/((?:\\.|[^\\])*)/([[:alpha:]]*)\z}
              s = $1
              opts = $2 || ""
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
