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
    # returns an array of strings.
    #
    # Generally completions do not have to subclass Completion. They merely
    # need to duck-type Proc by implementing the `call` method.
    #
    # The Completion base class is "empty" and returns no completions. You can
    # also use the instance {Toys::Definition::Completion::EMPTY}.
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
      # @return [Array<String>] an array of completion candidates.
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
      # *   `:files_only`: Returns a completion that searches the current
      #     directory for file names (but not directories).
      # *   `:directories_only`: Returns a completion that searches the current
      #     directory for directory names (but not files).
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
        when ::Array
          values(*spec)
        when ::Proc
          spec
        when :file_system
          file_system
        when :files_only
          files_only
        when :directories_only
          directories_only
        else
          raise ::ArgumentError, "Unknown completion spec: #{spec.inspect}"
        end
      end

      ##
      # Returns a new completion object using the given strings as candidates.
      #
      # @param [Array<String>] values
      # @return [Proc]
      #
      def self.values(*values)
        ValuesCompletion.new(values)
      end

      ##
      # Returns a new completion object searching the current directory for
      # files and directories.
      #
      # @param [String] cwd Working directory (defaults to the current dir).
      # @return [Proc]
      #
      def self.file_system(cwd: nil)
        FileSystemCompletion.new(cwd: cwd)
      end

      ##
      # Returns a new completion object searching the current directory for
      # files (but not directories).
      #
      # @param [String] cwd Working directory (defaults to the current dir).
      # @return [Proc]
      #
      def self.files_only(cwd: nil)
        FileSystemCompletion.new(cwd: cwd, omit_directories: true)
      end

      ##
      # Returns a new completion object searching the current directory for
      # directories (but not files).
      #
      # @param [String] cwd Working directory (defaults to the current dir).
      # @return [Proc]
      #
      def self.directories_only(cwd: nil)
        FileSystemCompletion.new(cwd: cwd, omit_files: true)
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
      # @return [Array<String>] an array of completion candidates.
      #
      def call(substring)
        if substring.empty? || substring.end_with?("/")
          dir = ::File.expand_path(substring, @cwd)
          name = ""
        else
          dir, name = ::File.split(substring)
          dir = ::File.expand_path(dir, @cwd)
        end
        children = ::Dir.glob(name, base: dir).find_all { |child| child != "." && child != ".." }
        if children.empty?
          children = ::Dir.children(dir).sort.find_all { |child| child.start_with?(name) }
        end
        children.find_all do |child|
          path = ::File.join(dir, child)
          @include_files && File.file?(path) || @include_directories && File.directory?(path)
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
        @values = values.flatten.map(&:to_s).sort
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
      # @return [Array<String>] an array of completion candidates.
      #
      def call(substring)
        @values.find_all { |val| val.start_with?(substring) }
      end
    end
  end
end
