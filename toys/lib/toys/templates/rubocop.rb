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
      DEFAULT_TOOL_NAME = "rubocop".freeze

      ##
      # Create the template settings for the Rubocop template.
      #
      # @param [String] name Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param [String,Array<String>] gem_version Version requirements for
      #     the rubocop gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param [Boolean] fail_on_error If true, exits with a nonzero code if
      #     Rubocop fails. Defaults to true.
      # @param [Array<String>] options Additional options passed to the Rubocop
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

      to_expand do |template|
        tool(template.name) do
          desc "Run rubocop on the current project."

          run do
            gem("rubocop", *Array(template.gem_version))
            require "rubocop"

            cli = ::RuboCop::CLI.new
            logger.info "Running RuboCop..."
            result = cli.run(template.options)
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
