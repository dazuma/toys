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
      DEFAULT_GEM_VERSION_REQUIREMENTS = "~> 3.0"

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
      # @param [String] pattern A glob indicating the spec files to load.
      #     Defaults to {DEFAULT_PATTERN}.
      # @param [Boolean] warnings If true, runs specs with Ruby warnings.
      #     Defaults to true.
      #
      def initialize(name: nil,
                     gem_version: nil,
                     libs: nil,
                     pattern: nil,
                     warnings: true)
        @name = name || DEFAULT_TOOL_NAME
        @gem_version = gem_version || DEFAULT_GEM_VERSION_REQUIREMENTS
        @libs = libs || DEFAULT_LIBS
        @pattern = pattern || DEFAULT_PATTERN
        @warnings = warnings
      end

      attr_accessor :name
      attr_accessor :gem_version
      attr_accessor :libs
      attr_accessor :pattern
      attr_accessor :warnings

      to_expand do |template|
        tool(template.name) do
          desc "Run rspec on the current project."

          include :exec
          include :gems

          flag :warnings, "-w", "--[no-]warnings",
               default: template.warnings,
               desc: "Turn on Ruby warnings (defaults to #{template.warnings})"

          remaining_args :specs, desc: "Specs to run (defaults to all specs)"

          to_run do
            gem "rspec", *Array(template.gem_version)

            ::Dir.chdir(context_directory || ::Dir.getwd) do
              rspec_libs = template.libs
              rspec_pattern = specs.join(" ")
              rspec_pattern = template.pattern if rspec_pattern.empty?
              rspec_warnings = warnings

              result = exec_proc(proc do
                $VERBOSE = 2 if rspec_warnings
                rspec_libs.each do |lib|
                  $LOAD_PATH.unshift(lib)
                end
                require "rspec/core"
                ARGV.clear
                ARGV.concat(["--pattern", rspec_pattern])
                ::RSpec::Core::Runner.invoke
              end)

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
