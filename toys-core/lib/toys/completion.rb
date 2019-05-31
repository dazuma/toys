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
      # @return [Toys::Tool]
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
        to_s <=> other.to_s
      end

      ## @private
      def hash
        to_s.hash
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
    # Generally completions do *not* need to subclass this base class. They
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
      # @param [Toys::Completion::Context] context the current completion
      #     context including the string fragment.
      # @return [Array<Toys::Completion::Candidate>] an array of candidates
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
    class Values < Base
      ##
      # Create a completion from a list of values.
      #
      # @param [Array<String>] values
      #
      def initialize(values)
        @values = values.flatten.map { |v| Candidate.new(v) }.sort
      end

      ##
      # The array of completion candidates.
      # @return [Array<String>]
      #
      attr_reader :values

      ##
      # Returns candidates for the current completion.
      #
      # @param [Toys::Completion::Context] context the current completion
      #     context including the string fragment.
      # @return [Array<Toys::Completion::Candidate>] an array of candidates
      #
      def call(context)
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
      when ::Proc, Base
        spec
      when ::Array
        Values.new(spec)
      when :file_system
        FileSystem.new
      else
        if spec.respond_to?(:call)
          spec
        else
          raise ::ArgumentError, "Unknown completion spec: #{spec.inspect}"
        end
      end
    end
  end
end
