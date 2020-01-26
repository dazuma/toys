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
    # A template that generates yardoc tools.
    #
    class Yardoc
      include Template

      ##
      # Default version requirements for the yard gem.
      # @return [String]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = "~> 0.9"

      ##
      # Default tool name
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "yardoc"

      ##
      # Create the template settings for the Yardoc template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param gem_version [String,Array<String>] Version requirements for
      #     the yard gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param files [Array<String>] An array of globs indicating the files
      #     to document.
      # @param generate_output [Boolean] Whether to generate output. Setting to
      #     false causes yardoc to emit warnings/errors but not generate html.
      #     Defaults to true.
      # @param generate_output_flag [Boolean] Whether to create a flag
      #     `--[no-]output` that can control whether output is generated.
      #     Defaults to false.
      # @param output_dir [String,nil] Output directory. Defaults to "doc".
      # @param fail_on_warning [Boolean] Whether the tool should return a
      #     nonzero error code if any warnings happen. Defaults to false.
      # @param fail_on_undocumented_objects [Boolean] Whether the tool should
      #     return a nonzero error code if any objects remain undocumented.
      #     Defaults to false.
      # @param show_public [Boolean] Show public methods. Defaults to true.
      # @param show_protected [Boolean] Show protected methods. Defaults to
      #     false.
      # @param show_private [Boolean] Show private methods. Defaults to false.
      # @param hide_private_tag [Boolean] Hide methods with the `@private` tag.
      #     Defaults to false.
      # @param readme [String,nil] Name of the readme file used as the title
      #     page, or `nil` to use the default.
      # @param markup [String,nil] Markup style used in documentation. Defaults
      #     to "rdoc".
      # @param template [String,nil] Template to use. Defaults to "default".
      # @param template_path [String,nil] The optional template path to look
      #     for templates in.
      # @param format [String,nil] The output format for the template. Defaults
      #     to "html".
      # @param options [Array<String>] Additional options passed to YARD
      # @param stats_options [Array<String>] Additional options passed to YARD
      #     stats
      # @param bundler [Boolean,Hash] If `false` (the default), bundler is not
      #     enabled for this tool. If `true` or a Hash of options, bundler is
      #     enabled. See the documentation for the
      #     [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      #     for information on available options.
      #
      def initialize(name: nil,
                     gem_version: nil,
                     files: [],
                     generate_output: true,
                     generate_output_flag: false,
                     output_dir: nil,
                     fail_on_warning: false,
                     fail_on_undocumented_objects: false,
                     show_public: true,
                     show_protected: false,
                     show_private: false,
                     hide_private_tag: false,
                     readme: nil,
                     markup: nil,
                     template: nil,
                     template_path: nil,
                     format: nil,
                     options: [],
                     stats_options: [],
                     bundler: nil)
        @name = name || DEFAULT_TOOL_NAME
        @gem_version = gem_version || DEFAULT_GEM_VERSION_REQUIREMENTS
        @files = files
        @generate_output = generate_output
        @generate_output_flag = generate_output_flag
        @output_dir = output_dir
        @fail_on_warning = fail_on_warning
        @fail_on_undocumented_objects = fail_on_undocumented_objects
        @show_public = show_public
        @show_protected = show_protected
        @show_private = show_private
        @hide_private_tag = hide_private_tag
        @readme = readme
        @markup = markup
        @template = template
        @template_path = template_path
        @format = format
        @options = options
        @stats_options = stats_options
        self.bundler = bundler
      end

      attr_accessor :name
      attr_accessor :gem_version
      attr_accessor :files
      attr_accessor :generate_output
      attr_accessor :generate_output_flag
      attr_accessor :output_dir
      attr_accessor :fail_on_warning
      attr_accessor :fail_on_undocumented_objects
      attr_accessor :show_public
      attr_accessor :show_protected
      attr_accessor :show_private
      attr_accessor :hide_private_tag
      attr_accessor :readme
      attr_accessor :markup
      attr_accessor :template
      attr_accessor :template_path
      attr_accessor :format
      attr_accessor :options
      attr_accessor :stats_options

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
          desc "Run yardoc on the current project."

          if template.generate_output_flag
            flag :generate_output, "--[no-]output",
                 default: template.generate_output,
                 desc: "Whether to generate output"
          else
            static :generate_output, template.generate_output
          end

          include :exec
          include :terminal
          include :gems

          if template.bundler_settings
            include :bundler, **template.bundler_settings
          end

          to_run do
            gem_requirements = Array(template.gem_version)
            gem "yard", *gem_requirements

            ::Dir.chdir(context_directory || ::Dir.getwd) do
              files = []
              patterns = Array(template.files)
              patterns = ["lib/**/*.rb"] if patterns.empty?
              patterns.each do |pattern|
                files.concat(::Dir.glob(pattern))
              end
              files.uniq!

              run_options = template.options.dup
              stats_options = template.stats_options.dup
              stats_options << "--list-undoc" if template.fail_on_undocumented_objects
              run_options << "--fail-on-warning" if template.fail_on_warning
              run_options << "--no-output" unless generate_output
              run_options << "--output-dir" << template.output_dir if template.output_dir
              run_options << "--no-public" unless template.show_public
              run_options << "--protected" if template.show_protected
              run_options << "--private" if template.show_private
              run_options << "--no-private" if template.hide_private_tag
              run_options << "-r" << template.readme if template.readme
              run_options << "-m" << template.markup if template.markup
              run_options << "-t" << template.template if template.template
              run_options << "-p" << template.template_path if template.template_path
              run_options << "-f" << template.format if template.format
              unless stats_options.empty?
                run_options << "--no-stats"
                stats_options << "--use-cache"
              end
              run_options.concat(files)

              result = exec_ruby([], in: :controller) do |controller|
                controller.in.puts("gem 'yard', *#{gem_requirements.inspect}")
                controller.in.puts("require 'yard'")
                controller.in.puts("::YARD::CLI::Yardoc.run(*#{run_options.inspect})")
              end
              if result.error?
                puts("Yardoc encountered errors", :red, :bold) unless verbosity.negative?
                exit(1)
              end
              unless stats_options.empty?
                result = exec_ruby([], in: :controller, out: :capture) do |controller|
                  controller.in.puts("gem 'yard', *#{gem_requirements.inspect}")
                  controller.in.puts("require 'yard'")
                  controller.in.puts("::YARD::CLI::Stats.run(*#{stats_options.inspect})")
                end
                puts result.captured_out
                if result.error?
                  puts("Yardoc encountered errors", :red, :bold) unless verbosity.negative?
                  exit(1)
                end
                exit_on_nonzero_status(result)
                if template.fail_on_undocumented_objects
                  if result.captured_out =~ /Undocumented\sObjects:/
                    unless verbosity.negative?
                      puts("Yardoc encountered undocumented objects", :red, :bold)
                    end
                    exit(1)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
