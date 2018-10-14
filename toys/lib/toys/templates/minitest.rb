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
                     warnings: true)
        @name = name || DEFAULT_TOOL_NAME
        @gem_version = gem_version || DEFAULT_GEM_VERSION_REQUIREMENTS
        @libs = libs || DEFAULT_LIBS
        @files = files || DEFAULT_FILES
        @warnings = warnings
      end

      attr_accessor :name
      attr_accessor :gem_version
      attr_accessor :libs
      attr_accessor :files
      attr_accessor :warnings

      to_expand do |template|
        tool(template.name) do
          desc "Run minitest on the current project."

          include :exec
          include :gems

          flag :warnings, "-w", "--[no-]warnings",
               default: template.warnings,
               desc: "Turn on Ruby warnings (defaults to #{template.warnings})"

          remaining_args :tests, desc: "Paths to the tests to run (defaults to all tests)"

          to_run do
            gem "minitest", *Array(template.gem_version)

            ::Dir.chdir(context_directory || ::Dir.getwd) do
              ruby_args = []
              unless template.libs.empty?
                lib_path = template.libs.join(::File::PATH_SEPARATOR)
                ruby_args << "-I#{lib_path}"
              end
              ruby_args << "-w" if warnings

              if tests.empty?
                Array(template.files).each do |pattern|
                  tests.concat(::Dir.glob(pattern))
                end
                tests.uniq!
              end

              result = ruby(ruby_args, in: :controller) do |controller|
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
