# frozen_string_literal: true

# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
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
      # @param [String] name Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param [String,Array<String>] gem_version Version requirements for
      #     the rspec gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param [Array<String>] libs An array of library paths to add to the
      #     ruby require path. Defaults to {DEFAULT_LIBS}.
      # @param [String] options The path to a custom options file.
      # @param [String] order The order in which to run examples. Default is
      #     {DEFAULT_ORDER}.
      # @param [String] format Choose a formatter code. Default is `p`.
      # @param [String] out Write output to a file instead of stdout.
      # @param [Boolean] backtrace Enable full backtrace (default is false).
      # @param [String] pattern A glob indicating the spec files to load.
      #     Defaults to {DEFAULT_PATTERN}.
      # @param [Boolean] warnings If true, runs specs with Ruby warnings.
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

          remaining_args :files, desc: "Paths to the specs to run (defaults to all specs)"

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
