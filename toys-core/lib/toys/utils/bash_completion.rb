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
      # Print out completions, assuming the correct bash environment
      #
      def run
        words, last = analyze_line
        exit(1) unless words.shift
        compute_completions(words, last).each do |completion|
          puts completion
        end
      end

      private

      def analyze_line
        line = ENV["COMP_LINE"].to_s
        point = (ENV["COMP_POINT"] || line.length).to_i
        line = line[0, point].lstrip
        words = line.split(" ", -1)
        last = words.pop.to_s
        [words, last]
      end

      def compute_completions(words, last)
        tool, args = @loader.lookup(words)
        candidates = []
        if @complete_subtools && args.empty?
          candidates = @loader.list_subtools(words).map(&:simple_name)
        end
        if @complete_flags && (last.empty? || last.start_with?("-"))
          candidates.concat(tool.used_flags)
        end
        candidates.find_all { |candidate| candidate.start_with?(last) }
      end
    end
  end
end
