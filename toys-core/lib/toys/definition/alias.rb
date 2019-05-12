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
    # An alias is a name that refers to another name.
    #
    class Alias
      ##
      # Create a new alias.
      #
      # @param [Array<String>] full_name The name of the alias.
      # @param [String,Array<String>] target The name of the target. May either
      #     be a local reference (a single string) or a global reference (an
      #     array of strings)
      #
      def initialize(loader, full_name, target, priority)
        @target_name =
          if target.is_a?(::Array)
            target.map(&:to_s)
          else
            full_name[0..-2] + [target.to_s]
          end
        @target_name.freeze
        @full_name = full_name.map(&:to_s).freeze
        @priority = priority
        @tool_class = DSL::Tool.new_class(@full_name, priority, loader)
      end

      ##
      # Return the tool class.
      # @return [Class]
      #
      attr_reader :tool_class

      ##
      # Return the name of the tool as an array of strings.
      # This array may not be modified.
      # @return [Array<String>]
      #
      attr_reader :full_name

      ##
      # Return the priority of this alias.
      # @return [Integer]
      #
      attr_reader :priority

      ##
      # Return the name of the target as an array of strings.
      # This array may not be modified.
      # @return [Array<String>]
      #
      attr_reader :target_name

      ##
      # Returns the local name of this tool.
      # @return [String]
      #
      def simple_name
        full_name.last
      end

      ##
      # Returns a displayable name of this tool, generally the full name
      # delimited by spaces.
      # @return [String]
      #
      def display_name
        full_name.join(" ")
      end

      ##
      # Returns a displayable name of the target, generally the full name
      # delimited by spaces.
      # @return [String]
      #
      def display_target
        target_name.join(" ")
      end
    end
  end
end
