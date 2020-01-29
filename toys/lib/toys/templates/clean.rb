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
    # A template for tools that clean build artifacts
    #
    class Clean
      include Template

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "clean"

      ##
      # Create the template settings for the Clean template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param paths [Array<String>] An array of glob patterns indicating what
      #     to clean.
      #
      def initialize(name: nil, paths: [])
        @name = name
        @paths = paths
      end

      ##
      # Name of the tool to create.
      #
      # @param value [String]
      # @return [String]
      #
      attr_writer :name

      ##
      # An array of glob patterns indicating what to clean.
      #
      # @param value [Array<String>]
      # @return [Array<String>]
      #
      attr_writer :paths

      # @private
      def paths
        Array(@paths)
      end

      # @private
      def name
        @name || DEFAULT_TOOL_NAME
      end

      on_expand do |template|
        tool(template.name) do
          desc "Clean built files and directories."

          include :fileutils

          to_run do
            ::Dir.chdir(context_directory || ::Dir.getwd) do
              files = []
              template.paths.each do |pattern|
                files.concat(::Dir.glob(pattern))
              end
              files.uniq.each do |file|
                if ::File.exist?(file)
                  rm_rf(file)
                  puts "Cleaned: #{file}"
                end
              end
            end
          end
        end
      end
    end
  end
end
