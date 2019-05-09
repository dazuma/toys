# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
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
  module Utils
    ##
    # Implementation of bash tab completion.
    # Provides completion for subtools and flags.
    #
    class BashCompletion
      ##
      # Create a completion.
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
        exit 1 unless words.shift
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
