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

require "shellwords"

module Toys
  module Utils
    ##
    # Implementation of bash tab completion. Provides completion for subtools
    # and flags.
    #
    # This class is not loaded by default. Before using it directly, you should
    # `require "toys/utils/bash_completion"`
    #
    class BashCompletion
      ##
      # Create a completion handler.
      #
      # @param [Toys::Loader] loader A loader that provides tools
      # @param [Boolean] complete_subtools Include subtool names in completions
      #     (default is `true`)
      # @param [Boolean] complete_flags Include flag names in completions
      #     (default is `true`)
      #
      def initialize(loader, complete_subtools: true, complete_flags: true)
        @loader = loader
        @complete_subtools = complete_subtools
        @complete_flags = complete_flags
      end

      ##
      # Print out completions, assuming the correct bash environment.
      #
      def run
        line = ENV["COMP_LINE"].to_s
        point = ENV["COMP_POINT"].to_i
        completions = compute(line, point)
        exit(1) unless completions
        completions.each { |completion| puts completion }
      end

      ##
      # Internal completion computation. Entrypoint for testing.
      #
      # @param [String] line The command line
      # @param [Integer] point The index where the cursor is located
      # @return [Array<String>,nil] completions, or nil for error.
      #
      def compute(line, point = 0)
        point = line.length if point.zero?
        line = line[0, point]
        words = split(line)
        last_type, last = words.pop
        return nil unless words.shift
        words.map! { |_type, word| word }
        compute_completions(words, last, last_type)
      end

      private

      # rubocop: disable all
      def split(line)
        words = []
        field = String.new
        field_type = nil
        regex = /\G\s*(?>([^\s\\\'\"]+)|'([^\']*)(?:'|\z)|"((?:[^\"\\]|\\.)*)(?:"|\z)|(\\.?)|(\S))(\s|\z)?/m
        line.scan(regex) do |word, sq, dq, esc, garbage, sep|
          raise ArgumentError, "Didn't expect garbage: #{line.inspect}" if garbage
          field << (word || sq || (dq && dq.gsub(/\\([$`"\\\n])/, '\\1')) || esc.gsub(/\\(.)/, '\\1'))
          field_type = field_type ? :multi : sq ? :single : dq ? :double : :bare
          if sep
            words << [field_type, field]
            field_type = nil
            field = sep.empty? ? nil : String.new
          end
        end
        words << [field_type || :bare, field] if field
        words
      end
      # rubocop:enable all

      def format_str(candidate, type)
        type = :bare if candidate.include?("'") && type == :single
        case type
        when :single
          "'#{candidate}'"
        when :double
          '"' + candidate.gsub(/[$`"\\\n]/, '\\\\\\1') + '"'
        else
          Shellwords.escape(candidate)
        end
      end

      def compute_completions(words, last, last_type)
        tool, args = @loader.lookup(words)
        candidates = []
        if @complete_subtools && args.empty?
          candidates = @loader.list_subtools(words).map(&:simple_name)
        end
        if @complete_flags && (last.empty? || last.start_with?("-"))
          candidates.concat(tool.used_flags)
        end
        candidates
          .find_all { |candidate| candidate.start_with?(last) }
          .map { |candidate| format_str(candidate, last_type) }
      end
    end
  end
end
