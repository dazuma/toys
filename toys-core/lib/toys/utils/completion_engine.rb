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
        candidates = []
        if args.empty? && !fragment.start_with?("-")
          context = Definition::Completion::Context.new(
            fragment, quote_type: quote_type, completion_engine: self
          )
          candidates += subtool_candidates(previous_words, context)
        end
        optparser_machine = OptparserMachine.new(tool, candidates.empty?)
        args.each { |arg| optparser_machine.handle_arg(arg) }
        sources, current = optparser_machine.final_sources(fragment)
        candidates += sources_candidates(sources, current, quote_type, tool)
        candidates.sort.uniq
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
        start_str = context.string
        strings.flat_map do |str|
          str.start_with?(start_str) ? [Definition::Completion.candidate(str)] : []
        end
      end

      def subtool_candidates(words, context)
        return [] unless @complete_subtools
        make_candidates(@loader.list_subtools(words).map(&:simple_name), context)
      end

      def sources_candidates(sources, current, quote_type, tool)
        sources.flat_map do |source, previous|
          context = Definition::Completion::Context.new(
            current, quote_type: quote_type, previous: previous, completion_engine: self
          )
          case source
          when Definition::Flag
            flag_value_candidates(source, context)
          when Definition::Arg
            arg_candidates(source, context)
          when :flag_name
            flag_candidates(tool, context)
          else
            []
          end
        end
      end

      def flag_value_candidates(flag, context)
        return [] unless @complete_flag_values
        flag.completion.call(context)
      end

      def arg_candidates(arg, context)
        return [] unless @complete_args
        arg.completion.call(context)
      end

      def flag_candidates(tool, context)
        return [] unless @complete_flags
        make_candidates(tool.used_flags, context)
      end

      ## @private
      class OptparserMachine
        def initialize(tool, args_allowed)
          @flag_def = nil
          @flags_allowed = true
          @args_allowed = args_allowed
          @tool = tool
          @arg_defs = tool.arg_definitions
          @arg_def_index = 0
          @previous_flag_name = nil
          @previous_remaining = []
        end

        def handle_arg(arg)
          return if check_flag_value(arg)
          return if check_double_dash(arg)
          return if check_plain_flag(arg)
          check_positional_arg(arg)
        end

        def check_flag_value(arg)
          return false unless @flag_def
          value_type = @flag_def.value_type
          @flag_def = nil
          @previous_flag_name = nil
          value_type == :required || !arg.start_with?("-")
        end

        def check_double_dash(arg)
          return false unless arg == "--"
          @flags_allowed = false
          true
        end

        def check_plain_flag(arg)
          return false if !@flags_allowed || arg !~ /^-(-\w[\?\w-]*|[\?\w])$/
          flag_def = @tool.flag_definitions.find { |f| f.effective_flags.include?(arg) }
          if flag_def.flag_type == :value
            @flag_def = flag_def
            @previous_flag_name = arg
          end
          true
        end

        def check_positional_arg(arg)
          return false if @flags_allowed && arg =~ /^-(-\w[\?\w-]*=.*|[\?\w].+)$/
          return false if @arg_def_index >= @arg_defs.size
          if @arg_defs[@arg_def_index].type == :remaining
            @previous_remaining << arg
          else
            @arg_def_index += 1
          end
          true
        end

        def add_flag_value_sources(sources, last)
          if @flag_def.value_type == :optional && (last.empty? || last.start_with?("-"))
            sources << [:flag_name, nil]
          end
          if @flag_def.value_type == :required || last.empty? || !last.start_with?("-")
            sources << [@flag_def, @previous_flag_name]
          end
        end

        def add_flag_set_sources(sources, flag_str, flag_previous)
          flag_def = @tool.flag_definitions.find { |f| f.effective_flags.include?(flag_str) }
          sources << [flag_def, flag_previous] if flag_def
        end

        def add_other_sources(sources, last)
          if @flags_allowed && (last.empty? || last.start_with?("-"))
            sources << [:flag_name, nil]
          end
          if @args_allowed && (!@flags_allowed || !last.start_with?("-"))
            arg = @arg_defs[@arg_def_index]
            sources << [arg, arg.type == :remaining ? @previous_remaining : nil] if arg
          end
        end

        def final_sources(last)
          sources = []
          if @flag_def
            add_flag_value_sources(sources, last)
          elsif @flags_allowed && last =~ /^(-[\?\w])(.+)|(--\w[\?\w-]*)=(.*)$/
            last = $2 || $4
            flag_str = $1 || $3
            flag_previous = $1 || "#{$3}="
            add_flag_set_sources(sources, flag_str, flag_previous)
          else
            add_other_sources(sources, last)
          end
          [sources, last]
        end
      end
    end
  end
end
