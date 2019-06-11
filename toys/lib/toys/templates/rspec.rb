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
    # A template for tools that run rspec
    #
    class Rspec
      include Template

      ##
      # Default version requirements for the rspec gem.
      # @return [Array<String>]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = "~> 3.1"

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "spec"

      ##
      # Default set of library paths
      # @return [Array<String>]
      #
      DEFAULT_LIBS = ["lib"].freeze

      ##
      # Default order type
      # @return [String]
      #
      DEFAULT_ORDER = "defined"

      ##
      # Default spec file glob
      # @return [String]
      #
      DEFAULT_PATTERN = "spec/**/*_spec.rb"

      ##
      # Create the template settings for the RSpec template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param gem_version [String,Array<String>] Version requirements for
      #     the rspec gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param libs [Array<String>] An array of library paths to add to the
      #     ruby require path. Defaults to {DEFAULT_LIBS}.
      # @param options [String] The path to a custom options file.
      # @param order [String] The order in which to run examples. Default is
      #     {DEFAULT_ORDER}.
      # @param format [String] Choose a formatter code. Default is `p`.
      # @param out [String] Write output to a file instead of stdout.
      # @param backtrace [Boolean] Enable full backtrace (default is false).
      # @param pattern [String] A glob indicating the spec files to load.
      #     Defaults to {DEFAULT_PATTERN}.
      # @param warnings [Boolean] If true, runs specs with Ruby warnings.
      #     Defaults to true.
      #
      def initialize(name: nil,
                     gem_version: nil,
                     libs: nil,
                     options: nil,
                     order: nil,
                     format: nil,
                     out: nil,
                     backtrace: false,
                     pattern: nil,
                     warnings: true)
        @name = name || DEFAULT_TOOL_NAME
        @gem_version = gem_version || DEFAULT_GEM_VERSION_REQUIREMENTS
        @libs = libs || DEFAULT_LIBS
        @options = options
        @order = order || DEFAULT_ORDER
        @format = format || "p"
        @out = out
        @backtrace = backtrace
        @pattern = pattern || DEFAULT_PATTERN
        @warnings = warnings
      end

      attr_accessor :name
      attr_accessor :gem_version
      attr_accessor :libs
      attr_accessor :options
      attr_accessor :order
      attr_accessor :format
      attr_accessor :out
      attr_accessor :backtrace
      attr_accessor :pattern
      attr_accessor :warnings

      to_expand do |template|
        tool(template.name) do
          desc "Run rspec on the current project."

          include :exec
          include :gems

          flag :order, "--order TYPE",
               default: template.order,
               desc: "Run examples by the specified order type (default: #{template.order})"
          flag :format, "-f", "--format FORMATTER",
               default: template.format,
               desc: "Choose a formatter (default: #{template.format})"
          flag :out, "-o", "--out FILE",
               default: template.out,
               desc: "Write output to a file (default: #{template.out.inspect})"
          flag :backtrace, "-b", "--[no-]backtrace",
               default: template.backtrace,
               desc: "Enable full backtrace (default: #{template.backtrace})"
          flag :warnings, "-w", "--[no-]warnings",
               default: template.warnings,
               desc: "Turn on Ruby warnings (default: #{template.warnings})"
          flag :pattern, "-P", "--pattern PATTERN",
               default: template.pattern,
               desc: "Load files matching pattern (default: #{template.pattern.inspect})"
          flag :exclude_pattern, "--exclude-pattern PATTERN",
               desc: "Load files except those matching pattern."
          flag :example, "-e", "--example STRING",
               desc: "Run examples whose full nested names include STRING" \
                     " (may be used more than once)."
          flag :tag, "-t", "--tag TAG",
               desc: "Run examples with the specified tag, or exclude" \
                     " examples by adding ~ before the tag."

          remaining_args :files,
                         complete: :file_system,
                         desc: "Paths to the specs to run (defaults to all specs)"

          to_run do
            gem "rspec", *Array(template.gem_version)

            ::Dir.chdir(context_directory || ::Dir.getwd) do
              ruby_args = []
              libs = Array(template.libs)
              ruby_args << "-I#{libs.join(::File::PATH_SEPARATOR)}" unless libs.empty?
              ruby_args << "-w" if warnings
              ruby_args << "-"
              ruby_args << "--options" << template.options if template.options
              ruby_args << "--order" << order if order
              ruby_args << "--format" << format if format
              ruby_args << "--out" << out if out
              ruby_args << "--backtrace" if backtrace
              ruby_args << "--pattern" << pattern
              ruby_args << "--exclude-pattern" << exclude_pattern if exclude_pattern
              ruby_args << "--example" << example if example
              ruby_args << "--tag" << tag if tag
              ruby_args.concat(files)

              result = exec_ruby(ruby_args, in: :controller) do |controller|
                controller.in.puts("require 'rspec/core'")
                controller.in.puts("::RSpec::Core::Runner.invoke")
              end
              if result.error?
                logger.error("RSpec failed!")
                exit(result.exit_code)
              end
            end
          end
        end
      end
    end
  end
end
