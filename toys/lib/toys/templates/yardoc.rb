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
    # A template that generates yardoc tools.
    #
    class Yardoc
      include Template

      ##
      # Default version requirements for the yard gem.
      # @return [String]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = "~> 0.9".freeze

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
      # @param [String,Array<String>] gem_version Version requirements for
      #     the yard gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param [Array<String>] files An array of globs indicating the files
      #     to document.
      # @param [Boolean] generate_output Whether to generate output. Setting to
      #     false causes yardoc to emit warnings/errors but not generate html.
      #     Defaults to true.
      # @param [Boolean] generate_output_flag Whether to create a flag
      #     `--[no-]output` that can control whether output is generated.
      #     Defaults to false.
      # @param [String,nil] output_dir Output directory. Defaults to "doc".
      # @param [Boolean] fail_on_warning Whether the tool should return a
      #     nonzero error code if any warnings happen. Defaults to false.
      # @param [Boolean] fail_on_undocumented_objects Whether the tool should
      #     return a nonzero error code if any objects remain undocumented.
      #     Defaults to false.
      # @param [Boolean] show_public Show public methods. Defaults to true.
      # @param [Boolean] show_protected Show protected methods. Defaults to
      #     false.
      # @param [Boolean] show_private Show private methods. Defaults to false.
      # @param [Boolean] hide_private_tag Hide methods with the `@private` tag.
      #     Defaults to false.
      # @param [String,nil] readme Name of the readme file used as the title
      #     page, or `nil` to use the default.
      # @param [String,nil] markup Markup style used in documentation. Defaults
      #     to "rdoc".
      # @param [String,nil] template Template to use. Defaults to "default".
      # @param [String,nil] template_path The optional template path to look
      #     for templates in.
      # @param [String,nil] format The output format for the template. Defaults
      #     to "html".
      # @param [Array<String>] options Additional options passed to YARD
      # @param [Array<String>] stats_options Additional options passed to YARD
      #     stats
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
                     stats_options: [])
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

      to_expand do |template|
        tool(template.name) do
          desc "Run yardoc on the current project."

          if template.generate_output_flag
            flag :generate_output, "--[no-]output",
                 default: template.generate_output,
                 desc: "Whether to generate output"
          else
            set :generate_output, template.generate_output
          end

          include :exec

          run do
            ::Toys::Utils::Gems.activate("yard", *Array(template.gem_version))
            require "yard"

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
            run_options << "--no-output" unless option(:generate_output)
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

            exec_proc(proc { ::YARD::CLI::Yardoc.run(*run_options) },
                      exit_on_nonzero_status: true)
            unless stats_options.empty?
              result = exec_proc(proc { ::YARD::CLI::Stats.run(*stats_options) }, out: :capture)
              puts result.captured_out
              exit_on_nonzero_status(result)
              if template.fail_on_undocumented_objects
                exit(1) if result.captured_out =~ /Undocumented\sObjects:/
              end
            end
          end
        end
      end
    end
  end
end
