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
    # A template for tools that run rubocop
    #
    class Rubocop
      include Template

      ##
      # Default version requirements for the rubocop gem.
      # @return [Array<String>]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = [].freeze

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "rubocop"

      ##
      # Create the template settings for the Rubocop template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param gem_version [String,Array<String>] Version requirements for
      #     the rubocop gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param fail_on_error [Boolean] If true, exits with a nonzero code if
      #     Rubocop fails. Defaults to true.
      # @param options [Array<String>] Additional options passed to the Rubocop
      #     CLI.
      #
      def initialize(name: DEFAULT_TOOL_NAME,
                     gem_version: nil,
                     fail_on_error: true,
                     options: [])
        @name = name
        @gem_version = gem_version || DEFAULT_GEM_VERSION_REQUIREMENTS
        @fail_on_error = fail_on_error
        @options = options
      end

      attr_accessor :name
      attr_accessor :gem_version
      attr_accessor :fail_on_error
      attr_accessor :options

      on_expand do |template|
        tool(template.name) do
          desc "Run rubocop on the current project."

          include :gems

          to_run do
            gem "rubocop", *Array(template.gem_version)
            require "rubocop"

            ::Dir.chdir(context_directory || ::Dir.getwd) do
              rubocop = ::RuboCop::CLI.new
              logger.info "Running RuboCop..."
              result = rubocop.run(template.options)
              if result.nonzero?
                logger.error "RuboCop failed!"
                exit(1) if template.fail_on_error
              end
            end
          end
        end
      end
    end
  end
end
