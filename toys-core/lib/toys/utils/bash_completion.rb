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

      def filter_candidates(candidates, current)
        candidates.find_all { |candidate| candidate.start_with?(current) }
      end

      def subtool_candidates(words, current)
        return [] unless @complete_subtools
        filter_candidates(@loader.list_subtools(words).map(&:simple_name), current)
      end

      def flag_value_candidates(flag, current)
        return [] unless @complete_flag_values
        flag.completion.call(current)
      end

      def arg_candidates(arg, current)
        return [] unless @complete_args
        arg.completion.call(current)
      end

      def flag_candidates(tool, current)
        return [] unless @complete_flags
        filter_candidates(tool.used_flags, current)
      end

      def compute_completions(words, last, last_type)
        tool, args = @loader.lookup(words)
        candidates = []
        if args.empty? && !last.start_with?("-")
          candidates += subtool_candidates(words, last)
        end
        optparser_machine = OptparserMachine.new(tool, candidates.empty?)
        args.each { |arg| optparser_machine.handle_arg(arg) }
        sources, current = optparser_machine.final_sources(last)
        sources.each do |source|
          case source
          when Definition::Flag
            candidates += flag_value_candidates(source, current)
          when Definition::Arg
            candidates += arg_candidates(source, current)
          when :flag_name
            candidates += flag_candidates(tool, current)
          end
        end
        candidates.sort.map { |candidate| format_str(candidate, last_type) }
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
        end

        def handle_arg(arg)
          if @flag_def
            value_type = @flag_def.value_type
            @flag_def = nil
            return if value_type == :required || !arg.start_with?("-")
          end
          if arg == "--"
            @flags_allowed = false
          elsif recognize_plain_flag?(arg)
            flag_def = @tool.flag_definitions.find { |f| f.effective_flags.include?(arg) }
            @flag_def = flag_def if flag_def.flag_type == :value
          elsif recognize_valued_flag?(arg)
            @arg_def_index += 1
          end
        end

        def recognize_plain_flag?(arg)
          @flags_allowed && arg =~ /^-(-\w[\?\w-]*|[\?\w])$/
        end

        def recognize_valued_flag?(arg)
          (!@flags_allowed || arg !~ /^-(-\w[\?\w-]*=.*|[\?\w].+)$/) &&
            @arg_def_index < @arg_defs.size &&
            @arg_defs[@arg_def_index].type != :remaining
        end

        def add_flag_value_sources(sources, last)
          if @flag_def.value_type == :optional && (last.empty? || last.start_with?("-"))
            sources << :flag_name
          end
          if @flag_def.value_type == :required || last.empty? || !last.start_with?("-")
            sources << @flag_def
          end
        end

        def add_flag_set_sources(sources, flag_str)
          flag_def = @tool.flag_definitions.find { |f| f.effective_flags.include?(flag_str) }
          sources << flag_def if flag_def
        end

        def add_other_sources(sources, last)
          if @flags_allowed && (last.empty? || last.start_with?("-"))
            sources << :flag_name
          end
          if @args_allowed && (!@flags_allowed || !last.start_with?("-"))
            sources << @arg_defs[@arg_def_index]
          end
        end

        def final_sources(last)
          sources = []
          val = last
          if @flag_def
            add_flag_value_sources(sources, last)
          elsif @flags_allowed && last =~ /^(-[\?\w])(.+)|(--\w[\?\w-]*)=(.*)$/
            val = $2 || $4
            add_flag_set_sources(sources, $1 || $3)
          else
            add_other_sources(sources, last)
          end
          [sources, val]
        end
      end
    end
  end
end
