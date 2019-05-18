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
    # completion. You pass a string (the current string fragment) and it
    # returns an array of {Toys::Definition::Completion::Candidate} objects.
    #
    # Each candidate has a string for the completion, as well as a flag
    # indicating whether it is a *partial* completion (i.e. a prefix that
    # could be added to) or a *whole* completion word. Generally, tab
    # completion systems should add a trailing space after a whole completion
    # but not after a partial completion.
    #
    # Generally completions do *not* have to subclass the
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
      # Returns candidates given the current substring.
      # This default implementation returns an empty list.
      #
      # @param [String] substring the current substring.
      # @return [Array<Toys::Definition::Completion::Candidate>] an array of
      #     completion candidates.
      #
      def call(substring) # rubocop:disable Lint/UnusedMethodArgument
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
      # *   A **Proc**. Returns the proc.
      #
      # @param [Object] spec The completion spec. See above for recognized
      #     values.
      # @return [Proc]
      #
      def self.create(spec)
        case spec
        when nil, :empty
          EMPTY
        when ::Proc
          spec
        when ::Array
          ValuesCompletion.new(spec)
        when :file_system
          FileSystemCompletion.new
        else
          raise ::ArgumentError, "Unknown completion spec: #{spec.inspect}"
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
      def self.partial(str)
        Candidate.new(str, true)
      end

      ##
      # Convenience method. Returns partial candidates for the given strings.
      #
      # @param [Array<String>] strs The completion candidate strings.
      # @return [Array<Toys::Definition::Completion::Candidate>]
      #
      def self.partials(strs)
        strs.map { |s| Candidate.new(s, true) }
      end

      ##
      # A candidate string.
      #
      class Candidate
        include ::Comparable

        ##
        # Create a new candidate
        # @param [String] string The candidate string
        # @param [Boolean] partial Whether the candidate is partial.
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
        # Determine whether the candidate is partial.
        # @return [Boolean]
        #
        def partial?
          @partial
        end

        ##
        # Determine whether the candidate is whole.
        # @return [Boolean]
        #
        def whole?
          !@partial
        end

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
      # Returns candidates given the current substring.
      #
      # @param [String] substring the current substring.
      # @return [Array<Toys::Definition::Completion::Candidate>] an array of
      #     completion candidates.
      #
      def call(substring)
        prefix, name =
          if substring.empty? || substring.end_with?("/")
            [substring, ""]
          else
            ::File.split(substring)
          end
        dir = ::File.expand_path(prefix, @cwd)
        prefix = nil if [".", ""].include?(prefix)
        children = glob_in(name, dir).find_all { |child| child != "." && child != ".." }.sort
        if children.empty?
          children = ::Dir.children(dir).find_all { |child| child.start_with?(name) }.sort
        end
        generate_candidates(children, prefix, dir)
      end

      private

      def glob_in(name, base_dir)
        if ::RUBY_VERSION < "2.5"
          if ::File.directory?(base_dir)
            ::Dir.chdir(base_dir) { ::Dir.glob(name) }
          else
            []
          end
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
              [Completion.partial("#{str}/")]
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
      # Returns candidates given the current substring.
      #
      # @param [String] substring the current substring.
      # @return [Array<Toys::Definition::Completion::Candidate>] an array of
      #     completion candidates.
      #
      def call(substring)
        @values.find_all { |val| val.string.start_with?(substring) }
      end
    end
  end
end
