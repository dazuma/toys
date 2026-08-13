# frozen_string_literal: true

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
      # @private
      #
      # Stands in for a character that was quoted or backslash-escaped, in the
      # `bare_field` returned by {CompletionEngine.split}. Chosen so that it
      # can never be mistaken for a shell's word break character.
      #
      QUOTED_CHAR = "\0"

      ##
      # Base class for shell completion engines that use a
      # `COMP_LINE` / `COMP_POINT` protocol.
      #
      # Completion candidates are always computed as whole words: the entire
      # word under the cursor is presented to the completion as the fragment,
      # and each candidate is a replacement for that entire word. A shell that
      # replaces less than the whole word, because it breaks words at certain
      # characters, declares those characters in the private method
      # `#word_break_chars`, and the candidates are trimmed to match.
      #
      # Subclasses must implement the private methods `#shell_name` and
      # `#output_completions`, and may override `#word_break_chars`.
      #
      class Base
        ##
        # Create a completion engine.
        #
        # @param completion [Toys::Completion::Base] The shell tab completion
        #     specifying how to generate completion candidates.
        # @param loader [Toys::Loader] The tool loader.
        #
        def initialize(completion, loader)
          @completion = completion
          @loader = loader
        end

        ##
        # Perform completion in the current shell environment, which must
        # include settings for the `COMP_LINE` and `COMP_POINT` environment
        # variables. Prints out completion candidates and returns a status code
        # indicating the result.
        #
        #  *  **0** for success.
        #  *  **1** if completion failed.
        #  *  **2** if the environment is incorrect (e.g. expected environment
        #     variables not found)
        #
        # @return [Integer] status code
        #
        def run
          return 2 if !::ENV.key?("COMP_LINE") || !::ENV.key?("COMP_POINT")
          line = ::ENV["COMP_LINE"].to_s
          point = ::ENV["COMP_POINT"].to_i
          point = line.length if point.negative?
          line = line[0, point]
          result = run_internal(line)
          if result
            output_completions(*result)
            0
          else
            1
          end
        end

        ##
        # @private
        #
        # Internal completion method. Test-accessible.
        # Returns `[quote_type, Array<Toys::Completion::Candidate>]`, or `nil`
        # if the line cannot be parsed (e.g. the executable name is missing).
        #
        def run_internal(line)
          words = CompletionEngine.split(line)
          quote_type, last, bare_last = words.pop
          return nil unless words.shift
          words.map! { |_type, word| word }
          context = Completion::Context.new(
            loader: @loader, previous_words: words, fragment: last,
            shell: shell_name, quote_type: quote_type
          )
          candidates = fit_candidates_to_word(@completion.call(context), last, bare_last)
          [quote_type, candidates.uniq.sort]
        end

        private

        ##
        # The characters at which this shell breaks the word being completed.
        # A shell that breaks words replaces only the text following the final
        # break, so candidates are trimmed accordingly. The base implementation
        # returns the empty string, meaning the shell replaces the whole word.
        #
        def word_break_chars
          ""
        end

        ##
        # Adjusts candidates to the span of the command line that this shell
        # will replace with the completion.
        #
        # Completions produce whole words. If this shell breaks words, drop the
        # part of each candidate that the shell will leave in place, i.e. the
        # text through the final break character in the word.
        #
        # The break is located in `bare_word`, which is `word` with its quoted
        # and backslash-escaped characters masked out, because a shell does not
        # break a word at a character that was quoted. A candidate that does not
        # extend the word cannot be trimmed, and is passed through unchanged.
        #
        def fit_candidates_to_word(candidates, word, bare_word)
          chars = word_break_chars
          return candidates if chars.empty?
          index = bare_word.rindex(/[#{::Regexp.escape(chars)}]/)
          return candidates if index.nil?
          prefix = word[0, index + 1]
          candidates.map do |candidate|
            string = candidate.to_s
            next candidate unless string.start_with?(prefix)
            Completion::Candidate.new(string[prefix.length..], partial: candidate.partial?)
          end
        end

        def shell_name
          raise ::NotImplementedError
        end

        def output_completions(_quote_type, _candidates)
          raise ::NotImplementedError
        end
      end

      ##
      # A completion engine for bash.
      #
      class Bash < Base
        ##
        # Create a bash completion engine.
        #
        # @param completion [Toys::Completion::Base] The shell tab completion
        #     specifying how to generate completion candidates.
        # @param loader [Toys::Loader] The tool loader.
        #
        def initialize(completion, loader)
          require "shellwords"
          super
        end

        ##
        # @private
        # Accessible only for testing
        #
        def format_candidate(candidate, quote_type)
          str = candidate.to_s
          partial = candidate.partial?
          quote_type = nil if str.include?("'") && quote_type == :single
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

        ##
        # Bash's default `COMP_WORDBREAKS` includes an equals sign and a colon,
        # and it replaces only the text following the final break.
        #
        def word_break_chars
          "=:"
        end

        def shell_name
          :bash
        end

        def output_completions(quote_type, candidates)
          candidates.each { |c| puts format_candidate(c, quote_type) }
        end
      end

      ##
      # A completion engine for zsh.
      #
      class Zsh < Base
        private

        def shell_name
          :zsh
        end

        def output_completions(_quote_type, candidates)
          finals, partials = candidates.partition(&:final?)
          finals.each { |c| puts c.string unless c.string.empty? }
          puts ""
          partials.each { |c| puts c.string unless c.string.empty? }
        end
      end

      class << self
        ##
        # @private
        #
        # Splits a command line into words. Returns an array of triples
        # `[quote_type, field, bare_field]`, where `field` is the word with its
        # quoting and escaping removed, and `bare_field` is `field` with every
        # character that was quoted or backslash-escaped replaced by
        # {QUOTED_CHAR}. The two are always the same length, so an index into
        # one is an index into the other.
        #
        def split(line)
          words = []
          field = ::String.new
          bare_field = ::String.new
          quote_type = nil
          line.scan(split_regex) do |word, sqw, dqw, esc, garbage, sep|
            raise ArgumentError, "Didn't expect garbage: #{line.inspect}" if garbage
            str = field_str(word, sqw, dqw, esc)
            field << str
            bare_field << (word ? str : QUOTED_CHAR * str.length)
            quote_type = update_quote_type(quote_type, sqw, dqw)
            next unless sep
            words << [quote_type, field, bare_field]
            quote_type = nil
            if sep.empty?
              field = bare_field = nil
            else
              field = ::String.new
              bare_field = ::String.new
            end
          end
          words << [quote_type, field, bare_field] if field
          words
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
