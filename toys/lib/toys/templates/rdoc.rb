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
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param gem_version [String,Array<String>] Version requirements for
      #     the rdoc gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param files [Array<String>] An array of globs indicating the files
      #     to document.
      # @param output_dir [String] Name of directory to receive html output
      #     files. Defaults to {DEFAULT_OUTPUT_DIR}.
      # @param markup [String,nil] Markup format. Allowed values include
      #     "rdoc", "rd", and "tomdoc". Default is "rdoc".
      # @param title [String,nil] Title of RDoc documentation. If `nil`, RDoc
      #     will use a default title.
      # @param main [String,nil] Name of the file to use as the main top level
      #     document. Default is none.
      # @param template [String,nil] Name of the template to use. If `nil`,
      #     RDoc will use its default template.
      # @param generator [String,nil] Name of the format generator. If `nil`,
      #     RDoc will use its default generator.
      # @param options [Array<String>] Additional options to pass to RDoc.
      # @param bundler [Boolean,Hash] If `false` (the default), bundler is not
      #     enabled for this tool. If `true` or a Hash of options, bundler is
      #     enabled. See the documentation for the
      #     [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      #     for information on available options.
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
                     options: [],
                     bundler: nil)
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
        self.bundler = bundler
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
          desc "Run rdoc on the current project."

          include :exec, exit_on_nonzero_status: true
          include :gems

          if template.bundler_settings
            include :bundler, **template.bundler_settings
          end

          to_run do
            gem_requirements = Array(template.gem_version)
            gem "rdoc", *gem_requirements

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

              exec_ruby([], in: :controller) do |controller|
                controller.in.puts("gem 'rdoc', *#{gem_requirements.inspect}")
                controller.in.puts("require 'rdoc'")
                controller.in.puts("::RDoc::RDoc.new.document(*#{(args + files).inspect})")
              end
            end
          end
        end
      end
    end
  end
end
