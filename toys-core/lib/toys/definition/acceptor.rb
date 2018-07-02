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
      # arguments). You may subclass this object and override the {#match}
      # method to change this behavior.
      #
      # The base acceptor lets you provide a converter as a proc. The proc
      # should take one or more arguments, the first of which is the entire
      # argument string, and the others of which are any additional values
      # returned from validation. The converter should return the final
      # converted value of the argument.
      #
      # The converter may be provided either as a proc in the `converter`
      # parameter, or as a block. If neither is provided, the base acceptor
      # performs no conversion and uses the argument string.
      #
      # @param [String] name A visible name for the acceptor, shown in help.
      # @param [Proc] converter A converter function. May also be given as a
      #     block.
      #
      def initialize(name, converter = nil, &block)
        @name = name.to_s
        @converter = converter || block
      end

      ##
      # Name of the acceptor
      # @return [String]
      #
      attr_reader :name
      alias to_s name

      ##
      # Validate the given input.
      #
      # You may override this method to specify a validation function. For a
      # valid input, the function must return either the original argument
      # string, or an array of which the first element is the original argument
      # string, and the remaining elements may comprise additional information.
      # All returned information is then passed to the conversion function.
      # Note that a MatchInfo object is a legitimate return value since it
      # duck-types the appropriate array.
      #
      # For an invalid input, you should return a falsy value.
      #
      # The default implementation simply returns the original argument string,
      # indicating all inputs are valid.
      #
      # @param [String] str Input argument string
      # @return [String,Array]
      #
      def match(str)
        str
      end

      ##
      # Convert the given input. Uses the converter provided to this object's
      # constructor. Subclasses may also override this method.
      #
      # @param [String] str Original argument string
      # @param [Object...] extra Zero or more additional arguments comprising
      #     additional elements returned from the match function.
      # @return [Object] The converted argument as it should be stored in the
      #     context data.
      #
      def convert(str, *extra)
        @converter ? @converter.call(str, *extra) : str
      end
    end

    ##
    # An acceptor that uses a regex to validate input.
    #
    class PatternAcceptor < Acceptor
      ##
      # Create a pattern acceptor.
      #
      # You must provide a regular expression as a validator. You may also
      # provide a converter proc. See {Toys::Definition::Acceptor} for details
      # on the converter.
      #
      # @param [String] name A visible name for the acceptor, shown in help.
      # @param [Regexp] regex Regular expression defining value values.
      # @param [Proc] converter A converter function. May also be given as a
      #     block. Note that the converter will be passed all elements of
      #     the MatchInfo.
      #
      def initialize(name, regex, converter = nil, &block)
        super(name, converter, &block)
        @regex = regex
      end

      ##
      # Overrides {Toys::Definition::Acceptor#match} to use the given regex.
      #
      def match(str)
        @regex.match(str)
      end
    end

    ##
    # An acceptor that recognizes a fixed set of values.
    #
    # You provide a list of valid values. The input argument string will be
    # matched against the string forms of these valid values. If it matches,
    # the converter will return the actual value.
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
      # Overrides {Toys::Definition::Acceptor#convert} to return the original
      # element.
      #
      def convert(_str, elem)
        elem
      end
    end
  end
end
