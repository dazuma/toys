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
    # Implementations of tab completion.
    #
    # This module is not loaded by default. Before using it directly, you must
    # `require "toys/utils/completion_engine"`
    #
    module CompletionEngine
      ##
      # A completion engine for bash.
      #
      class Bash
        ##
        # Create a bash completion engine.
        #
        # @param cli [Toys::CLI] The CLI.
        #
        def initialize(cli)
          @cli = cli
        end

        ##
        # Perform completion in the current shell environment, which must
        # include settings for the `COMP_LINE` and `COMP_POINT` environment
        # variables. Prints out completion candidates, one per line, and
        # returns a status code indicating the result.
        #
        # *   **0** for success.
        # *   **1** if completion failed.
        # *   **-1** if the environment is incorrect (e.g. expected environment
        #     variables not found)
        #
        # @return [Integer] status code
        #
        def run
          return -1 if !::ENV.key?("COMP_LINE") || !::ENV.key?("COMP_POINT")
          line = ::ENV["COMP_LINE"].to_s
          point = ::ENV["COMP_POINT"].to_i
          point = line.length if point.negative?
          line = line[0, point]
          completions = run_internal(line)
          if completions
            completions.each { |completion| puts completion }
            0
          else
            1
          end
        end

        ##
        # Internal completion method designed for testing.
        # @private
        #
        def run_internal(line)
          words = CompletionEngine.split(line)
          quote_type, last = words.pop
          return nil unless words.shift
          words.map! { |_type, word| word }
          prefix = ""
          if (match = /\A(.*[=:])(.*)\z/.match(last))
            prefix = match[1]
            last = match[2]
          end
          context = Completion::Context.new(
            cli: @cli, previous_words: words, fragment_prefix: prefix, fragment: last,
            params: {shell: :bash, quote_type: quote_type}
          )
          candidates = @cli.completion.call(context)
          candidates.uniq.sort.map do |candidate|
            CompletionEngine.format_candidate(candidate, quote_type)
          end
        end
      end

      class << self
        ## @private
        def split(line)
          words = []
          field = ::String.new
          quote_type = nil
          line.scan(split_regex) do |word, sqw, dqw, esc, garbage, sep|
            raise ArgumentError, "Didn't expect garbage: #{line.inspect}" if garbage
            field << field_str(word, sqw, dqw, esc)
            quote_type = update_quote_type(quote_type, sqw, dqw)
            if sep
              words << [quote_type, field]
              quote_type = nil
              field = sep.empty? ? nil : ::String.new
            end
          end
          words << [quote_type, field] if field
          words
        end

        ## @private
        def format_candidate(candidate, quote_type)
          str = candidate.to_s
          partial = candidate.is_a?(Completion::Candidate) ? candidate.partial? : false
          quote_type = nil if candidate.string.include?("'") && quote_type == :single
          case quote_type
          when :single
            partial ? "'#{str}" : "'#{str}' "
          when :double
            str = str.gsub(/[$`"\\\n]/, '\\\\\\1')
            partial ? "\"#{str}" : "\"#{str}\" "
          else
            str = ::Shellwords.escape(str)
            partial ? str : "#{str} "
          end
        end

        private

        def split_regex
          word_re = "([^\\s\\\\\\'\\\"]+)"
          sq_re = "'([^\\']*)(?:'|\\z)"
          dq_re = "\"((?:[^\\\"\\\\]|\\\\.)*)(?:\"|\\z)"
          esc_re = "(\\\\.?)"
          sep_re = "(\\s|\\z)"
          /\G\s*(?>#{word_re}|#{sq_re}|#{dq_re}|#{esc_re}|(\S))#{sep_re}?/m
        end

        def field_str(word, sqw, dqw, esc)
          word ||
            sqw ||
            dqw&.gsub(/\\([$`"\\\n])/, '\\1') ||
            esc&.gsub(/\\(.)/, '\\1') ||
            ""
        end

        def update_quote_type(quote_type, sqw, dqw)
          if quote_type
            :multi
          elsif sqw
            :single
          elsif dqw
            :double
          else
            :bare
          end
        end
      end
    end
  end
end
