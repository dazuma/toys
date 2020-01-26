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
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param gem_version [String,Array<String>] Version requirements for
      #     the minitest gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param libs [Array<String>] An array of library paths to add to the
      #     ruby require path. Defaults to {DEFAULT_LIBS}.
      # @param files [Array<String>] An array of globs indicating the test
      #     files to load. Defaults to {DEFAULT_FILES}.
      # @param warnings [Boolean] If true, runs tests with Ruby warnings.
      #     Defaults to true.
      # @param bundler [Boolean,Hash] If `false` (the default), bundler is not
      #     enabled for this tool. If `true` or a Hash of options, bundler is
      #     enabled. See the documentation for the
      #     [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      #     for information on available options.
      #
      def initialize(name: nil,
                     gem_version: nil,
                     libs: nil,
                     files: nil,
                     seed: nil,
                     verbose: false,
                     warnings: true,
                     bundler: nil)
        @name = name || DEFAULT_TOOL_NAME
        @gem_version = gem_version || DEFAULT_GEM_VERSION_REQUIREMENTS
        @libs = libs || DEFAULT_LIBS
        @files = files || DEFAULT_FILES
        @seed = seed
        @verbose = verbose
        @warnings = warnings
        self.bundler = bundler
      end

      attr_accessor :name
      attr_accessor :gem_version
      attr_accessor :libs
      attr_accessor :files
      attr_accessor :seed
      attr_accessor :verbose
      attr_accessor :warnings

      ##
      # Activate bundler for this tool.
      #
      # See the documentation for the
      # [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      # for information on the options that can be passed.
      #
      # @param opts [keywords] Options for bundler
      # @return [self]
      #
      def bundler(**opts)
        @bundler_settings = opts
        self
      end

      ##
      # Set the bundler state and options for this tool.
      #
      # Pass `false` to disable bundler. Pass `true` or a hash of options to
      # enable bundler. See the documentation for the
      # [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      # for information on the options that can be passed.
      #
      # @param opts [true,false,Hash] Whether bundler should be enabled for
      #     this tool.
      # @return [self]
      #
      def bundler=(opts)
        @bundler_settings =
          if opts && !opts.is_a?(::Hash)
            {}
          else
            opts
          end
      end

      ## @private
      attr_reader :bundler_settings

      on_expand do |template|
        tool(template.name) do
          desc "Run minitest on the current project."

          include :exec
          include :gems

          if template.bundler_settings
            include :bundler, **template.bundler_settings
          end

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
                         complete: :file_system,
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
