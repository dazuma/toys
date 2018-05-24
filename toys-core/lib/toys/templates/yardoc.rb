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
    # A template for tools that run yardoc
    #
    class Yardoc
      include Template

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "yardoc".freeze

      ##
      # Create the template settings for the Yardoc template.
      #
      # @param [String] name Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param [Array<String>] files An array of globs indicating the files
      #     to document.
      # @param [Array<String>] options Additional options passed to YARD
      # @param [Array<String>] stats_options Additional options passed to YARD
      #     stats
      #
      def initialize(name: DEFAULT_TOOL_NAME,
                     files: [],
                     options: [],
                     stats_options: [])
        @name = name
        @files = files
        @options = options
        @stats_options = stats_options
      end

      attr_accessor :name
      attr_accessor :files
      attr_accessor :options
      attr_accessor :stats_options

      to_expand do |template|
        tool(template.name) do
          desc "Run yardoc on the current project."

          include :exec

          script do
            require "yard"
            files = []
            patterns = Array(template.files)
            patterns = ["lib/**/*.rb"] if patterns.empty?
            patterns.each do |pattern|
              files.concat(::Dir.glob(pattern))
            end
            files.uniq!

            unless template.stats_options.empty?
              template.options << "--no-stats"
              template.stats_options << "--use-cache"
            end

            yardoc = ::YARD::CLI::Yardoc.new
            yardoc.run(*(template.options + files))
            unless template.stats_options.empty?
              ::YARD::CLI::Stats.run(*template.stats_options)
            end
          end
        end
      end
    end
  end
end
