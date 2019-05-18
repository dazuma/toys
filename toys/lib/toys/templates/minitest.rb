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
  module Templates
    ##
    # A template for tools that run minitest
    #
    class Minitest
      include Template

      ##
      # Default version requirements for the minitest gem.
      # @return [Array<String>]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = "~> 5.0"

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "test"

      ##
      # Default set of library paths
      # @return [Array<String>]
      #
      DEFAULT_LIBS = ["lib"].freeze

      ##
      # Default set of test file globs
      # @return [Array<String>]
      #
      DEFAULT_FILES = ["test/**/test*.rb"].freeze

      ##
      # Create the template settings for the Minitest template.
      #
      # @param [String] name Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param [String,Array<String>] gem_version Version requirements for
      #     the minitest gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param [Array<String>] libs An array of library paths to add to the
      #     ruby require path. Defaults to {DEFAULT_LIBS}.
      # @param [Array<String>] files An array of globs indicating the test
      #     files to load. Defaults to {DEFAULT_FILES}.
      # @param [Boolean] warnings If true, runs tests with Ruby warnings.
      #     Defaults to true.
      #
      def initialize(name: nil,
                     gem_version: nil,
                     libs: nil,
                     files: nil,
                     seed: nil,
                     verbose: false,
                     warnings: true)
        @name = name || DEFAULT_TOOL_NAME
        @gem_version = gem_version || DEFAULT_GEM_VERSION_REQUIREMENTS
        @libs = libs || DEFAULT_LIBS
        @files = files || DEFAULT_FILES
        @seed = seed
        @verbose = verbose
        @warnings = warnings
      end

      attr_accessor :name
      attr_accessor :gem_version
      attr_accessor :libs
      attr_accessor :files
      attr_accessor :seed
      attr_accessor :verbose
      attr_accessor :warnings

      to_expand do |template|
        tool(template.name) do
          desc "Run minitest on the current project."

          include :exec
          include :gems

          flag :seed, "-s", "--seed SEED",
               default: template.seed, desc: "Sets random seed."
          flag :warnings, "-w", "--[no-]warnings",
               default: template.warnings,
               desc: "Turn on Ruby warnings (defaults to #{template.warnings})"
          flag :name, "-n", "--name PATTERN",
               desc: "Filter run on /regexp/ or string."
          flag :exclude, "-e", "--exclude PATTERN",
               desc: "Exclude /regexp/ or string from run."

          remaining_args :tests,
                         completion: :file_system,
                         desc: "Paths to the tests to run (defaults to all tests)"

          to_run do
            gem "minitest", *Array(template.gem_version)

            ::Dir.chdir(context_directory || ::Dir.getwd) do
              ruby_args = []
              libs = Array(template.libs)
              ruby_args << "-I#{libs.join(::File::PATH_SEPARATOR)}" unless libs.empty?
              ruby_args << "-w" if warnings
              ruby_args << "-"
              ruby_args << "--seed" << seed if seed
              vv = verbosity
              vv += 1 if template.verbose
              ruby_args << "--verbose" if vv.positive?
              ruby_args << "--name" << name if name
              ruby_args << "--exclude" << exclude if exclude

              if tests.empty?
                Array(template.files).each do |pattern|
                  tests.concat(::Dir.glob(pattern))
                end
                tests.uniq!
              end

              result = exec_ruby(ruby_args, in: :controller) do |controller|
                controller.in.puts("require 'minitest/autorun'")
                tests.each do |file|
                  controller.in.puts("load '#{file}'")
                end
              end
              if result.error?
                logger.error("Minitest failed!")
                exit(result.exit_code)
              end
            end
          end
        end
      end
    end
  end
end
