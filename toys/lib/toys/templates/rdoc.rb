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
    # A template that generates rdoc tools.
    #
    class Rdoc
      include Template

      ##
      # Default version requirements for the rdoc gem.
      # @return [Array<String>]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = ">= 5.0.0"

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "rdoc"

      ##
      # Default output directory
      # @return [String]
      #
      DEFAULT_OUTPUT_DIR = "html"

      ##
      # Create the template settings for the Rdoc template.
      #
      # @param [String] name Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param [String,Array<String>] gem_version Version requirements for
      #     the rdoc gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param [Array<String>] files An array of globs indicating the files
      #     to document.
      # @param [String] output_dir Name of directory to receive html output
      #     files. Defaults to {DEFAULT_OUTPUT_DIR}.
      # @param [String,nil] markup Markup format. Allowed values include
      #     "rdoc", "rd", and "tomdoc". Default is "rdoc".
      # @param [String,nil] title Title of RDoc documentation. If `nil`, RDoc
      #     will use a default title.
      # @param [String,nil] main Name of the file to use as the main top level
      #     document. Default is none.
      # @param [String,nil] template Name of the template to use. If `nil`,
      #     RDoc will use its default template.
      # @param [String,nil] generator Name of the format generator. If `nil`,
      #     RDoc will use its default generator.
      # @param [Array<String>] options Additional options to pass to RDoc.
      #
      def initialize(name: nil,
                     gem_version: nil,
                     files: [],
                     output_dir: nil,
                     markup: nil,
                     title: nil,
                     main: nil,
                     template: nil,
                     generator: nil,
                     options: [])
        @name = name || DEFAULT_TOOL_NAME
        @gem_version = gem_version || DEFAULT_GEM_VERSION_REQUIREMENTS
        @files = files
        @output_dir = output_dir || DEFAULT_OUTPUT_DIR
        @markup = markup
        @title = title
        @main = main
        @template = template
        @generator = generator
        @options = options
      end

      attr_accessor :name
      attr_accessor :gem_version
      attr_accessor :files
      attr_accessor :output_dir
      attr_accessor :markup
      attr_accessor :title
      attr_accessor :main
      attr_accessor :template
      attr_accessor :generator
      attr_accessor :options

      to_expand do |template|
        tool(template.name) do
          desc "Run rdoc on the current project."

          include :exec, exit_on_nonzero_status: true
          include :gems

          to_run do
            gem "rdoc", *Array(template.gem_version)
            require "rdoc"

            ::Dir.chdir(context_directory || ::Dir.getwd) do
              files = []
              patterns = Array(template.files)
              patterns = ["lib/**/*.rb"] if patterns.empty?
              patterns.each do |pattern|
                files.concat(::Dir.glob(pattern))
              end
              files.uniq!

              args = template.options.dup
              args << "-o" << template.output_dir
              args << "--markup" << template.markup if template.markup
              args << "--main" << template.main if template.main
              args << "--title" << template.title if template.title
              args << "-T" << template.template if template.template
              args << "-f" << template.generator if template.generator

              exec_proc(proc { RDoc::RDoc.new.document(args + files) })
            end
          end
        end
      end
    end
  end
end
