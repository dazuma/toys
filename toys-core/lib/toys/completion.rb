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
  ##
  # A Completion is a callable Proc that determines candidates for shell tab
  # completion. You pass a {Toys::Completion::Context} object (which includes
  # the current string fragment and other information) and it returns an array
  # of candidates for completing the fragment, represented by
  # {Toys::Completion::Candidate} objects.
  #
  # A useful method here is the class method {Toys::Completion.create} which
  # takes a variety of inputs and returns a suitable completion Proc.
  #
  module Completion
    ##
    # The context in which to determine completion candidates.
    #
    class Context
      ##
      # Create completion context
      #
      # @param [Toys::CLI] cli The CLI being run.
      # @param [Array<String>] previous_words Array of complete strings that
      #     appeared prior to the fragment to complete.
      # @param [String] fragment_prefix The non-completed prefix (e.g. "key=")
      #     of the fragment.
      # @param [String] fragment The string fragment to complete
      # @param [Hash] params Miscellaneous context data
      #
      def initialize(cli:, previous_words: [], fragment_prefix: "", fragment: "", params: {})
        @cli = cli
        @previous_words = previous_words
        @fragment_prefix = fragment_prefix
        @fragment = fragment
        @params = params
        @tool = nil
        @args = nil
        @arg_parser = nil
      end

      ##
      # Create a new completion context with the given modifications.
      #
      # @param [Toys::CLI] cli The CLI being run.
      # @param [Array<String>] previous_words Array of complete strings that
      #     appeared prior to the fragment to complete.
      # @param [String] fragment_prefix The non-completed prefix (e.g. "key=")
      #     of the fragment.
      # @param [String] fragment The string fragment to complete
      # @param [Hash] add_params Add miscellaneous context data
      # @param [Hash,nil] replace_params Replace miscellaneous context data.
      # @return [Toys::Completion::Context]
      #
      def with(cli: nil, previous_words: nil, fragment_prefix: nil, fragment: nil,
               add_params: {}, replace_params: nil)
        Context.new(cli: cli || self.cli,
                    previous_words: previous_words || self.previous_words,
                    fragment_prefix: fragment_prefix || self.fragment_prefix,
                    fragment: fragment || self.fragment,
                    params: (replace_params || params).merge(add_params))
      end

      ##
      # The CLI being run.
      # @return [Toys::CLI]
      #
      attr_reader :cli

      ##
      # All previous words.
      # @return [Array<String>]
      #
      attr_reader :previous_words

      ##
      # A non-completed prefix for the current fragment.
      # @return [String]
      #
      attr_reader :fragment_prefix

      ##
      # The current string fragment to complete
      # @return [String]
      #
      attr_reader :fragment

      ##
      # Context parameters.
      # @return [Hash]
      #
      attr_reader :params

      ##
      # The tool being invoked, which should control the completion.
      # @return [Toys::Tool]
      #
      def tool
        lookup_tool
        @tool
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
        lookup_tool
        @arg_parser ||= ArgParser.new(@cli, @tool).parse(@args)
      end

      ## @private
      def inspect
        "<Toys::Completion::Context previous=#{previous_words.inspect}" \
          " prefix=#{fragment_prefix.inspect} fragment=#{fragment.inspect}>"
      end

      private

      def lookup_tool
        @tool, @args = @cli.loader.lookup(@previous_words) unless @tool
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
      def initialize(string, partial: false)
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
        string <=> other.string
      end

      ## @private
      def hash
        string.hash
      end

      ##
      # Create an array of candidates given an array of strings.
      #
      # @param [Array<String>] array
      # @return [Array<Toys::Completion::Candidate]
      #
      def self.new_multi(array, partial: false)
        array.map { |s| new(s, partial: partial) }
      end
    end

    ##
    # A base class that returns no completions.
    #
    # Completions *may* but do not need to subclass this base class. They
    # merely need to duck-type `Proc` by implementing the `call` method.
    #
    class Base
      ##
      # Returns candidates for the current completion.
      # This default implementation returns an empty list.
      #
      # @param [Toys::Completion::Context] context The current completion
      #     context including the string fragment.
      # @return [Array<Toys::Completion::Candidate>] An array of candidates
      #
      def call(context) # rubocop:disable Lint/UnusedMethodArgument
        []
      end
    end

    ##
    # A Completion that returns candidates from the local file system.
    #
    class FileSystem < Base
      ##
      # Create a completion that gets candidates from names in the local file
      # system.
      #
      # @param [String] cwd Working directory (defaults to the current dir).
      # @param [Boolean] omit_files Omit files from candidates
      # @param [Boolean] omit_directories Omit directories from candidates
      # @param [String,Regexp] prefix_constraint Constraint on the fragment
      #     prefix. Defaults to requiring the prefix be empty.
      #
      def initialize(cwd: nil, omit_files: false, omit_directories: false, prefix_constraint: "")
        @cwd = cwd || ::Dir.pwd
        @include_files = !omit_files
        @include_directories = !omit_directories
        @prefix_constraint = prefix_constraint
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
      # Constraint on the fragment prefix.
      # @return [String,Regexp]
      #
      attr_reader :prefix_constraint

      ##
      # Path to the starting directory.
      # @return [String]
      #
      attr_reader :cwd

      ##
      # Returns candidates for the current completion.
      #
      # @param [Toys::Completion::Context] context the current completion
      #     context including the string fragment.
      # @return [Array<Toys::Completion::Candidate>] an array of candidates
      #
      def call(context)
        return [] unless @prefix_constraint === context.fragment_prefix
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

      if ::RUBY_VERSION < "2.5"
        def glob_in(name, base_dir)
          ::Dir.chdir(base_dir) { ::Dir.glob(name) }
        end
      else
        def glob_in(name, base_dir)
          ::Dir.glob(name, base: base_dir)
        end
      end

      def generate_candidates(children, prefix, dir)
        children.flat_map do |child|
          path = ::File.join(dir, child)
          str = prefix ? ::File.join(prefix, child) : child
          if ::File.file?(path)
            @include_files ? [Candidate.new(str)] : []
          elsif ::File.directory?(path)
            if @include_directories
              [Candidate.new("#{str}/", partial: true)]
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
    # A Completion whose candidates come from a static list of strings.
    #
    class Enum < Base
      ##
      # Create a completion from a list of values.
      #
      # @param [Array<String>] values
      # @param [String,Regexp] prefix_constraint Constraint on the fragment
      #     prefix. Defaults to requiring the prefix be empty.
      #
      def initialize(values, prefix_constraint: "")
        @values = values.flatten.map { |v| Candidate.new(v) }.sort
        @prefix_constraint = prefix_constraint
      end

      ##
      # The array of completion candidates.
      # @return [Array<String>]
      #
      attr_reader :values

      ##
      # Constraint on the fragment prefix.
      # @return [String,Regexp]
      #
      attr_reader :prefix_constraint

      ##
      # Returns candidates for the current completion.
      #
      # @param [Toys::Completion::Context] context the current completion
      #     context including the string fragment.
      # @return [Array<Toys::Completion::Candidate>] an array of candidates
      #
      def call(context)
        return [] unless @prefix_constraint === context.fragment_prefix
        fragment = context.fragment
        @values.find_all { |val| val.string.start_with?(fragment) }
      end
    end

    ##
    # An instance of the empty completion that returns no candidates.
    # @return [Toys:::Completion::Base]
    #
    EMPTY = Base.new

    ##
    # Create a completion Proc from a variety of specification formats.
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
    # @param [Hash] options Additional options to pass to the completion.
    # @return [Toys::Completion::Base,Proc]
    #
    def self.create(spec = nil, **options, &block)
      spec ||= block
      case spec
      when nil, :empty
        EMPTY
      when ::Proc, Base
        spec
      when ::Array
        Enum.new(spec, options)
      when :file_system
        FileSystem.new(options)
      else
        if spec.respond_to?(:call)
          spec
        else
          raise ToolDefinitionError, "Illegal completion spec: #{spec.inspect}"
        end
      end
    end
  end
end
