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
    # Implementation of tab completion. Provides completion for subtools and
    # flags, and a frontend for bash.
    #
    # This class is not loaded by default. Before using it directly, you should
    # `require "toys/utils/completion_engine"`
    #
    class CompletionEngine
      ##
      # Create a completion engine.
      #
      # @param [Toys::Loader] loader A loader that provides tools
      # @param [Boolean] complete_subtools Include subtool names in completions
      #     (default is `true`)
      # @param [Boolean] complete_flags Include flag names in completions
      #     (default is `true`)
      # @param [Boolean] complete_args Include args in completions
      #     (default is `true`)
      # @param [Boolean] complete_flag_values Include flag values in completions
      #     (default is `true`)
      #
      def initialize(loader,
                     complete_subtools: true, complete_flags: true,
                     complete_args: true, complete_flag_values: true)
        @loader = loader
        @complete_subtools = complete_subtools
        @complete_flags = complete_flags
        @complete_args = complete_args
        @complete_flag_values = complete_flag_values
      end

      ##
      # Perform bash-style completion. The input lines are expected to be
      # presented in the `COMP_LINE` and `COMP_POINT` environment variables.
      # Completion candidates are written to stdout, one per line. See the bash
      # manual for details.
      #
      # Returns a process status code:
      #
      # *   **0** for success
      # *   **1** if completion failed
      # *   **-1** if the required `COMP_LINE` and `COMP_POINT` environment
      #     variables are not present.
      #
      # @return [Integer] status code
      #
      def run_bash
        return -1 if !::ENV.key?("COMP_LINE") || !::ENV.key?("COMP_POINT")
        line = ::ENV["COMP_LINE"].to_s
        point = ::ENV["COMP_POINT"].to_i
        completions = run_bash_internal(line, point)
        if completions
          completions.each { |completion| puts completion }
          0
        else
          1
        end
      end

      ##
      # Internal bash completion method designed for testing. Pass the
      # `COMP_LINE` and `COMP_POINT` values and receive an array of strings
      # as a response.
      #
      # @param [String] line The command line
      # @param [Integer] point The index where the cursor is located
      # @return [Array<String>,nil] completions, or nil for error.
      #
      def run_bash_internal(line, point = -1)
        point = line.length if point.negative?
        line = line[0, point]
        words = split(line)
        quote_type, last = words.pop
        return nil unless words.shift
        words.map! { |_type, word| word }
        candidates = compute(words, last, quote_type: quote_type)
        candidates.map { |candidate| format_candidate(candidate, quote_type) }
      end

      ##
      # Compute completion candidates given a list of previous words and a
      # current word fragment.
      #
      # @param [Array<String>] previous_words Previous words in the line
      # @param [String] fragment Current word fragment
      # @param [:single,:double,nil] quote_type How the current word fragment
      #     is quoted.
      # @return [Array<String>] completions.
      #
      def compute(previous_words, fragment, quote_type: nil)
        tool, args = @loader.lookup(previous_words)
        candidates = subtool_candidates(previous_words, args, fragment, quote_type)
        args_allowed = candidates.empty?
        arg_parser = ArgParser.new(tool).parse(args)
        context = Definition::Completion::Context.new(
          fragment, quote_type: quote_type, arg_parser: arg_parser, completion_engine: self
        )
        candidates += plain_flag_candidates(context)
        candidates += valued_flag_candidates(arg_parser, fragment, quote_type)
        candidates += flag_value_candidates(context)
        candidates += arg_candidates(context) if args_allowed
        candidates.sort.uniq
      end

      ##
      # Create and return a copy of this CompletionEngine with the given
      # modifications to the settings.
      #
      # @param [Boolean,nil] complete_subtools Modified value for the
      #     `:complete_subtools` option, or `nil` to keep the current value.
      # @param [Boolean,nil] complete_flags Modified value for the
      #     `:complete_flags` option, or `nil` to keep the current value.
      # @param [Boolean,nil] complete_args Modified value for the
      #     `:complete_args` option, or `nil` to keep the current value.
      # @param [Boolean,nil] complete_flag_values Modified value for the
      #     `:complete_flag_values` option, or `nil` to keep the current value.
      # @return [Toys::Utils::CompletionEngine]
      #
      def with(complete_subtools: nil, complete_flags: nil, complete_args: nil,
               complete_flag_values: nil)
        complete_subtools = @complete_subtools if complete_subtools.nil?
        complete_flags = @complete_flags if complete_flags.nil?
        complete_args = @complete_args if complete_args.nil?
        complete_flag_values = @complete_flag_values if complete_flag_values.nil?
        CompletionEngine.new(
          @loader,
          complete_subtools: complete_subtools, complete_flags: complete_flags,
          complete_args: complete_args, complete_flag_values: complete_flag_values
        )
      end

      private

      # rubocop: disable all
      def split(line)
        words = []
        field = ::String.new
        quote_type = nil
        regex = /\G\s*(?>([^\s\\\'\"]+)|'([^\']*)(?:'|\z)|"((?:[^\"\\]|\\.)*)(?:"|\z)|(\\.?)|(\S))(\s|\z)?/m
        line.scan(regex) do |word, sq, dq, esc, garbage, sep|
          raise ArgumentError, "Didn't expect garbage: #{line.inspect}" if garbage
          field << (word || sq || (dq && dq.gsub(/\\([$`"\\\n])/, '\\1')) || esc.gsub(/\\(.)/, '\\1'))
          quote_type = quote_type ? :multi : sq ? :single : dq ? :double : :bare
          if sep
            words << [quote_type, field]
            quote_type = nil
            field = sep.empty? ? nil : ::String.new
          end
        end
        words << [quote_type, field] if field
        words
      end
      # rubocop:enable all

      def format_candidate(candidate, quote_type)
        str = candidate.to_s
        partial = candidate.is_a?(Definition::Completion::Candidate) ? candidate.partial? : false
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

      def make_candidates(strings, context)
        start_str = context.fragment
        strings.flat_map do |str|
          str.start_with?(start_str) ? [Definition::Completion.candidate(str)] : []
        end
      end

      def subtool_candidates(previous_words, args, fragment, quote_type)
        return [] if !@complete_subtools || !args.empty? || fragment.start_with?("-")
        context = Definition::Completion::Context.new(
          fragment, quote_type: quote_type, completion_engine: self
        )
        subtool_names = @loader.list_subtools(previous_words).map(&:simple_name)
        make_candidates(subtool_names, context)
      end

      def plain_flag_candidates(context)
        return [] unless @complete_flags
        arg_parser = context.arg_parser
        return [] unless arg_parser.flags_allowed?
        return [] if context.fragment =~ /\A[^-]/ || context.fragment.include?("=")
        flag_def = arg_parser.active_flag_def
        return [] if flag_def && flag_def.value_type == :required
        make_candidates(arg_parser.tool_definition.used_flags, context)
      end

      def valued_flag_candidates(arg_parser, fragment, quote_type)
        return [] if !@complete_flag_values || !arg_parser.flags_allowed?
        flag_def = arg_parser.active_flag_def
        return [] if flag_def && flag_def.value_type == :required
        return [] unless fragment =~ /\A(--\w[\?\w-]*)=(.*)\z/
        flag_str = $1
        fragment = $2
        flag_def = tool.resolve_flag(flag_str).unique_flag
        return [] unless flag_def
        context = Definition::Completion::Context.new(
          fragment, quote_type: quote_type, arg_parser: arg_parser, completion_engine: self
        )
        flag_def.completion.call(context)
      end

      def flag_value_candidates(context)
        return [] unless @complete_flag_values
        arg_parser = context.arg_parser
        flag_def = arg_parser.active_flag_def
        return [] unless flag_def
        return [] if @complete_flags && arg_parser.flags_allowed? &&
                     flag_def.value_type == :optional && context.fragment.start_with?("-")
        flag_def.completion.call(context)
      end

      def arg_candidates(context)
        return [] unless @complete_args
        arg_parser = context.arg_parser
        return [] if arg_parser.active_flag_def
        return [] if arg_parser.flags_allowed? && context.fragment.start_with?("-")
        arg_def = arg_parser.next_arg_def
        return [] unless arg_def
        arg_def.completion.call(context)
      end
    end
  end
end
