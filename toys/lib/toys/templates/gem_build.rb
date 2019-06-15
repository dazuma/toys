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
    # A template for tools that build, install, and release gems
    #
    class GemBuild
      include Template

      ##
      # Default tool name.
      # @return [String]
      #
      DEFAULT_TOOL_NAME = "build"

      ##
      # Default output flags. If `output_flags` is set to `true`, this is the
      # value used.
      # @return [Array<String>]
      #
      DEFAULT_OUTPUT_FLAGS = ["-o", "--output"].freeze

      ##
      # Create the template settings for the GemBuild template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param gem_name [String] Name of the gem to build. If not provided,
      #     defaults to the first gemspec file it finds.
      # @param push_gem [Boolean] If true, pushes the built gem to rubygems.
      # @param install_gem [Boolean] If true, installs the built gem locally.
      # @param tag [Boolean] If true, tags the git repo with the gem version.
      # @param push_tag [Boolean,String] If truthy, pushes the new tag to
      #     a git remote. You may specify which remote by setting the value to
      #     a string. Otherwise, if the value is simply `true`, the "origin"
      #     remote is used by default.
      #
      def initialize(name: DEFAULT_TOOL_NAME,
                     gem_name: nil,
                     output: nil,
                     output_flags: nil,
                     push_gem: false,
                     install_gem: false,
                     tag: false,
                     push_tag: false)
        @name = name
        @gem_name = gem_name
        @output = output
        @output_flags = output_flags == true ? DEFAULT_OUTPUT_FLAGS : output_flags
        @push_gem = push_gem
        @install_gem = install_gem
        @tag = tag
        @push_tag = push_tag
      end

      attr_accessor :name
      attr_accessor :gem_name
      attr_accessor :output
      attr_accessor :output_flags
      attr_accessor :push_gem
      attr_accessor :install_gem
      attr_accessor :tag
      attr_accessor :push_tag

      expansion do |template|
        unless template.gem_name
          candidates = ::Dir.chdir(context_directory || ::Dir.getwd) do
            ::Dir.glob("*.gemspec")
          end
          if candidates.empty?
            raise ToolDefinitionError, "Could not find a gemspec"
          end
          template.gem_name = candidates.first.sub(/\.gemspec$/, "")
        end
        task_names = []
        task_names << "Install" if template.install_gem
        task_names << "Release" if template.push_gem
        task_names = task_names.empty? ? "Build" : task_names.join(" and ")

        tool(template.name) do
          desc "#{task_names} the gem: #{template.gem_name}"

          flag :yes, "-y", "--yes", desc: "Do not ask for interactive confirmation"
          if template.output_flags
            flag :output do
              flags(Array(template.output_flags).map { |f| "#{f} VAL" })
              desc "output gem with the given filename"
              default template.output
              complete_values :file_system
            end
          else
            static :output, template.output
          end

          include :exec, exit_on_nonzero_status: true
          include :fileutils
          include :terminal

          to_run do
            require "rubygems/package"
            ::Dir.chdir(context_directory || ::Dir.getwd) do
              gemspec_path = "#{template.gem_name}.gemspec"
              gemspec = ::Gem::Specification.load(gemspec_path)
              version = gemspec.version
              gem_archive_path = output || "pkg/#{template.gem_name}-#{version}.gem"
              mkdir_p(::File.dirname(gem_archive_path))
              exec ["gem", "build", "--output", gem_archive_path, gemspec_path]
              if template.install_gem
                exit(1) unless yes || confirm("Install #{gem_archive_path}? ", default: true)
                exec ["gem", "install", gem_archive_path]
              end
              if template.push_gem
                if ::File.directory?(".git") && capture("git status -s").strip != ""
                  logger.error "Cannot push the gem when there are uncommited changes"
                  exit(1)
                end
                exit(1) unless yes || confirm("Release #{gem_archive_path}? ", default: true)
                exec(["gem", "push", gem_archive_path])
                if template.tag
                  exec(["git", "tag", "v#{version}"])
                  if template.push_tag
                    template.push_tag = "origin" if template.push_tag == true
                    exec(["git", "push", template.push_tag, "v#{version}"])
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
