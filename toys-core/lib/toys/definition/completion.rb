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
    # A Completion is a callable Proc that determines candidates for shell tab
    # completion. You pass a {Toys::Definition::Completion::Context} object
    # (which includes the current string fragment and other information) and it
    # returns an array of candidates for completing the fragment, represented
    # by {Toys::Definition::Completion::Candidate} objects.
    #
    # Generally completions do *not* need to subclass the
    # {Toys::Definition::Completion} base class. They merely need to duck-type
    # `Proc` by implementing the `call` method. (The base class implementation
    # is an "empty" completion that returns no candidates.)
    #
    # Probably the most useful method here is the class method
    # {Toys::Definition::Completion.create} which takes a variety of
    # specification objects and returns a suitable completion Proc.
    #
    class Completion
      ##
      # Returns candidates for the current completion.
      # This default implementation returns an empty list.
      #
      # @param [Toys::Definition::Completion::Context] context the current
      #     completion context including the string fragment.
      # @return [Array<Toys::Definition::Completion::Candidate>] an array of
      #     completion candidates.
      #
      def call(context) # rubocop:disable Lint/UnusedMethodArgument
        []
      end

      ##
      # An instance of the empty completion that returns no candidates.
      # @return [Toys::Definition::Completion]
      #
      EMPTY = new

      ##
      # A method that takes a variety of completion specs and returns a
      # suitable completion Proc.
      #
      # Recognized specs include:
      #
      # *   `nil`: Returns the empty completion.
      # *   `:file_system`: Returns a completion that searches the current
      #     directory for file and directory names.
      # *   An **Array** of strings. Returns a completion that uses those
      #     values as candidates.
      # *   A **Proc**. Returns the proc itself.
      #
      # @param [Object] spec The completion spec. See above for recognized
      #     values.
      # @return [Proc]
      #
      def self.create(spec)
        case spec
        when nil, :empty
          EMPTY
        when ::Proc, Completion
          spec
        when ::Array
          ValuesCompletion.new(spec)
        when :file_system
          FileSystemCompletion.new
        else
          if spec.respond_to?(:call)
            spec
          else
            raise ::ArgumentError, "Unknown completion spec: #{spec.inspect}"
          end
        end
      end

      ##
      # Convenience method. Returns a new completion object using the given
      # strings as candidates.
      #
      # @param [Array<String>] values
      # @return [Proc]
      #
      def self.values(*values)
        ValuesCompletion.new(values)
      end

      ##
      # Convenience method. Returns a new completion object searching the
      # current directory for files and directories.
      #
      # @param [String] cwd Working directory (defaults to the current dir).
      # @return [Proc]
      #
      def self.file_system(cwd: nil)
        FileSystemCompletion.new(cwd: cwd)
      end

      ##
      # Convenience method. Returns a whole candidate for the given string.
      #
      # @param [String] str The completion candidate string.
      # @return [Toys::Definition::Completion::Candidate]
      #
      def self.candidate(str)
        Candidate.new(str)
      end

      ##
      # Convenience method. Returns whole candidates for the given strings.
      #
      # @param [Array<String>] strs The completion candidate strings.
      # @return [Array<Toys::Definition::Completion::Candidate>]
      #
      def self.candidates(strs)
        strs.map { |s| Candidate.new(s) }
      end

      ##
      # Convenience method. Returns a partial candidate for the given string.
      #
      # @param [String] str The completion candidate.
      # @return [Toys::Definition::Completion::Candidate]
      #
      def self.partial_candidate(str)
        Candidate.new(str, true)
      end

      ##
      # Convenience method. Returns partial candidates for the given strings.
      #
      # @param [Array<String>] strs The completion candidate strings.
      # @return [Array<Toys::Definition::Completion::Candidate>]
      #
      def self.partial_candidates(strs)
        strs.map { |s| Candidate.new(s, true) }
      end

      ##
      # The context in which to determine completion candidates.
      #
      class Context
        ##
        # Create completion context
        #
        # @param [Toys::Loader] loader The loader used to obtain tool defs
        # @param [Array<String>] previous_words Array of complete strings that
        #     appeared prior to the fragment to complete.
        # @param [String] fragment The string fragment to complete
        # @param [Hash] params Miscellaneous context data
        #
        def initialize(loader, previous_words, fragment, params = {})
          @loader = loader
          @previous_words = previous_words
          @fragment = fragment
          @params = params
          @tool_definition = nil
          @args = nil
          @arg_parser = nil
        end

        ##
        # The loader.
        # @return [Toys::Loader]
        #
        attr_reader :loader

        ##
        # All previous words.
        # @return [Array<String>]
        #
        attr_reader :previous_words

        ##
        # The current string fragment to complete
        # @return [String]
        #
        attr_accessor :fragment

        ##
        # Context parameters.
        # @return [Hash]
        #
        attr_reader :params

        ##
        # The tool being invoked, which should control the completion.
        # @return [Toys::Definition::Tool]
        #
        def tool_definition
          lookup_tool
          @tool_definition
        end

        ##
        # An array of complete arguments passed to the tool, prior to the
        # fragment to complete.
        # @return [Array<String>]
        #
        def args
          lookup_tool
          @args
        end

        ##
        # Current ArgParser indicating the status of argument parsing up to
        # this point.
        #
        # @return [Toys::ArgParser]
        #
        def arg_parser
          @arg_parser ||= ArgParser.new(tool_definition).parse(args)
        end

        private

        def lookup_tool
          @tool_definition, @args = @loader.lookup(@previous_words) unless @tool_definition
        end
      end

      ##
      # A candidate for completing a string fragment.
      #
      # A candidate includes a string representing the potential completed
      # word, as well as a flag indicating whether it is a *partial* completion
      # (i.e. a prefix that could still be added to) versus a *final* word.
      # Generally, tab completion systems should add a trailing space after a
      # final completion but not after a partial completion.
      #
      class Candidate
        include ::Comparable

        ##
        # Create a new candidate
        # @param [String] string The candidate string
        # @param [Boolean] partial Whether the candidate is partial. Defaults
        #     to `false`.
        #
        def initialize(string, partial = false)
          @string = string.to_s
          @partial = partial ? true : false
        end

        ##
        # Get the candidate string.
        # @return [String]
        #
        attr_reader :string
        alias to_s string

        ##
        # Determine whether the candidate is partial completion.
        # @return [Boolean]
        #
        attr_reader :partial
        alias partial? partial

        ##
        # Determine whether the candidate is a final completion.
        # @return [Boolean]
        #
        def final
          !partial
        end
        alias final? final

        ## @private
        def eql?(other)
          other.is_a?(Candidate) && other.string.eql?(string) && other.partial? == @partial
        end

        ## @private
        def <=>(other)
          to_s <=> other.to_s
        end

        ## @private
        def hash
          to_s.hash
        end
      end
    end

    ##
    # A FilesystemCompletion is a Completion that returns candidates from the
    # local file system.
    #
    class FileSystemCompletion < Completion
      ##
      # Create a FileSystemCompletion, which gets candidates from names in the
      # local file system.
      #
      # @param [String] cwd Working directory (defaults to the current dir).
      # @param [Boolean] omit_files Omit files from candidates
      # @param [Boolean] omit_directories Omit directories from candidates
      #
      def initialize(cwd: nil, omit_files: false, omit_directories: false)
        @cwd = cwd || ::Dir.pwd
        @include_files = !omit_files
        @include_directories = !omit_directories
      end

      ##
      # Whether files are included in the completion candidates.
      # @return [Boolean]
      #
      attr_reader :include_files

      ##
      # Whether directories are included in the completion candidates.
      # @return [Boolean]
      #
      attr_reader :include_directories

      ##
      # Path to the starting directory.
      # @return [String]
      #
      attr_reader :cwd

      ##
      # Returns candidates for the current completion.
      #
      # @param [Toys::Definition::Completion::Context] context the current
      #     completion context including the string fragment.
      # @return [Array<Toys::Definition::Completion::Candidate>] an array of
      #     completion candidates.
      #
      def call(context)
        substring = context.fragment
        prefix, name =
          if substring.empty? || substring.end_with?("/")
            [substring, ""]
          else
            ::File.split(substring)
          end
        dir = ::File.expand_path(prefix, @cwd)
        return [] unless ::File.directory?(dir)
        prefix = nil if [".", ""].include?(prefix)
        omits = [".", ".."]
        children = glob_in(name, dir).find_all do |child|
          !omits.include?(child)
        end
        if children.empty?
          children = ::Dir.entries(dir).find_all do |child|
            child.start_with?(name) && !omits.include?(child)
          end
        end
        generate_candidates(children.sort, prefix, dir)
      end

      private

      def glob_in(name, base_dir)
        if ::RUBY_VERSION < "2.5"
          ::Dir.chdir(base_dir) { ::Dir.glob(name) }
        else
          ::Dir.glob(name, base: base_dir)
        end
      end

      def generate_candidates(children, prefix, dir)
        children.flat_map do |child|
          path = ::File.join(dir, child)
          str = prefix ? ::File.join(prefix, child) : child
          if ::File.file?(path)
            @include_files ? [Completion.candidate(str)] : []
          elsif ::File.directory?(path)
            if @include_directories
              [Completion.partial_candidate("#{str}/")]
            else
              []
            end
          else
            []
          end
        end
      end
    end

    ##
    # A ValuesCompletion is a Completion whose candidates come from a static
    # list of strings.
    #
    class ValuesCompletion < Completion
      ##
      # Create a ValuesCompletion from a list of values.
      #
      # @param [Array<String>] values
      #
      def initialize(values)
        @values = Completion.candidates(values.flatten).sort
      end

      ##
      # The array of completion candidates.
      # @return [Array<String>]
      #
      attr_reader :values

      ##
      # Returns candidates for the current completion.
      #
      # @param [Toys::Definition::Completion::Context] context the current
      #     completion context including the string fragment.
      # @return [Array<Toys::Definition::Completion::Candidate>] an array of
      #     completion candidates.
      #
      def call(context)
        fragment = context.fragment
        @values.find_all { |val| val.string.start_with?(fragment) }
      end
    end

    ##
    # A StandardFlagCompletion is a Completion that returns all possible flags
    # associated with a {Toys::Definition::Flag}.
    #
    class StandardFlagCompletion < Completion
      ##
      # Create a StandardFlagCompletion given configuration options.
      #
      # @param [Toys::Definition::Flag] flag The flag definition.
      # @param [Boolean] include_short Whether to include short flags.
      # @param [Boolean] include_long Whether to include long flags.
      # @param [Boolean] include_negative Whether to include `--no-*` forms.
      #
      def initialize(flag, include_short: true, include_long: true, include_negative: true)
        @flag = flag
        @include_short = include_short
        @include_long = include_long
        @include_negative = include_negative
      end

      ##
      # Returns candidates for the current completion.
      #
      # @param [Toys::Definition::Completion::Context] context the current
      #     completion context including the string fragment.
      # @return [Array<Toys::Definition::Completion::Candidate>] an array of
      #     completion candidates.
      #
      def call(context)
        results =
          if @include_short && @include_long && @include_negative
            @flag.effective_flags
          else
            collect_results
          end
        fragment = context.fragment
        Completion.candidates(results.find_all { |val| val.start_with?(fragment) })
      end

      private

      def collect_results
        results = []
        if @include_short
          results += @flag.single_flag_syntax.map(&:positive_flag)
        end
        if @include_long
          results +=
            if @include_negative
              @flag.double_flag_syntax.flat_map(&:flags)
            else
              @flag.double_flag_syntax.map(&:positive_flag)
            end
        end
        results
      end
    end

    ##
    # A StandardToolCompletion is a Completion that implements the standard
    # algorithm for a tool as a whole.
    #
    class StandardToolCompletion < Completion
      ##
      # Create a StandardToolCompletion given configuration options.
      #
      # @param [Boolean] complete_subtools Whether to complete subtool names
      # @param [Boolean] include_hidden_subtools Whether to include hidden
      #     subtools (i.e. those beginning with an underscore)
      # @param [Boolean] complete_args Whether to complete positional args
      # @param [Boolean] complete_flags Whether to complete flag names
      # @param [Boolean] complete_flag_values Whether to complete flag values
      #
      def initialize(complete_subtools: true, include_hidden_subtools: false,
                     complete_args: true, complete_flags: true, complete_flag_values: true)
        @complete_subtools = complete_subtools
        @include_hidden_subtools = include_hidden_subtools
        @complete_flags = complete_flags
        @complete_args = complete_args
        @complete_flag_values = complete_flag_values
      end

      ##
      # Returns candidates for the current completion.
      #
      # @param [Toys::Definition::Completion::Context] context the current
      #     completion context including the string fragment.
      # @return [Array<Toys::Definition::Completion::Candidate>] an array of
      #     completion candidates.
      #
      def call(context)
        candidates = valued_flag_candidates(context)
        return candidates if candidates
        candidates = subtool_or_arg_candidates(context)
        candidates += plain_flag_candidates(context)
        candidates += flag_value_candidates(context)
        candidates
      end

      private

      def valued_flag_candidates(context)
        return unless @complete_flag_values
        arg_parser = context.arg_parser
        return unless arg_parser.flags_allowed?
        active_flag_def = arg_parser.active_flag_def
        return if active_flag_def && active_flag_def.value_type == :required
        match = /\A(--\w[\?\w-]*)=(.*)\z/.match(context.fragment)
        return unless match

        flag_def = context.tool_definition.resolve_flag(match[1]).unique_flag
        return [] unless flag_def
        context.fragment = match[2]
        flag_def.value_completion.call(context)
      end

      def subtool_or_arg_candidates(context)
        return [] if context.arg_parser.active_flag_def
        return [] if context.arg_parser.flags_allowed? && context.fragment.start_with?("-")
        subtool_candidates(context) || arg_candidates(context)
      end

      def subtool_candidates(context)
        return if !@complete_subtools || !context.args.empty?
        subtools = context.loader.list_subtools(context.tool_definition.full_name,
                                                include_hidden: @include_hidden_subtools)
        return if subtools.empty?
        fragment = context.fragment
        candidates = []
        subtools.each do |subtool|
          name = subtool.simple_name
          candidates << Definition::Completion.candidate(name) if name.start_with?(fragment)
        end
        candidates
      end

      def arg_candidates(context)
        return unless @complete_args
        arg_def = context.arg_parser.next_arg_def
        return [] unless arg_def
        arg_def.completion.call(context)
      end

      def plain_flag_candidates(context)
        return [] if !@complete_flags || context.params[:disable_flags]
        arg_parser = context.arg_parser
        return [] unless arg_parser.flags_allowed?
        flag_def = arg_parser.active_flag_def
        return [] if flag_def && flag_def.value_type == :required
        return [] if context.fragment =~ /\A[^-]/ || context.fragment.include?("=")
        context.tool_definition.flag_definitions.flat_map do |flag|
          flag.flag_completion.call(context)
        end
      end

      def flag_value_candidates(context)
        return unless @complete_flag_values
        arg_parser = context.arg_parser
        flag_def = arg_parser.active_flag_def
        return [] unless flag_def
        return [] if @complete_flags && arg_parser.flags_allowed? &&
                     flag_def.value_type == :optional && context.fragment.start_with?("-")
        flag_def.value_completion.call(context)
      end
    end

    ##
    # A StandardCliCompletion is a Completion that implements the standard
    # algorithm for a CLI.
    #
    class StandardCliCompletion < Completion
      ##
      # Returns candidates for the current completion.
      #
      # @param [Toys::Definition::Completion::Context] context the current
      #     completion context including the string fragment.
      # @return [Array<Toys::Definition::Completion::Candidate>] an array of
      #     completion candidates.
      #
      def call(context)
        context.tool_definition.completion.call(context)
      end
    end
  end
end
