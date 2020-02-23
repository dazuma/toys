# frozen_string_literal: true

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
      # Default remote for pushing tags.
      # @return [String]
      #
      DEFAULT_PUSH_REMOTE = "origin"

      ##
      # Create the template settings for the GemBuild template.
      #
      # @param name [String] Name of the tool to create. Defaults to
      #     {DEFAULT_TOOL_NAME}.
      # @param gem_name [String] Name of the gem to build. If not provided,
      #     searches the context and current directories and uses the first
      #     gemspec file it finds.
      # @param output [String] Path to the gem package to generate. Optional.
      #     If not provided, defaults to a file name based on the gem name and
      #     version, under "pkg" in the current directory.
      # @param output_flags [Array<String>,true] Provide flags on the tool that
      #     set the output path. Optional. If not provided, no flags are
      #     created. You may set this to an array of flags (e.g. `["-o"]`) or
      #     set to `true` to choose {DEFAULT_OUTPUT_FLAGS}.
      # @param push_gem [Boolean] If true, pushes the built gem to rubygems.
      # @param install_gem [Boolean] If true, installs the built gem locally.
      # @param tag [Boolean] If true, tags the git repo with the gem version.
      # @param push_tag [Boolean,String] If truthy, pushes the new tag to
      #     a git remote. You may specify which remote by setting the value to
      #     a string. Otherwise, if the value is simply `true`, the "origin"
      #     remote is used by default.
      #
      def initialize(name: nil,
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
        @output_flags = output_flags
        @push_gem = push_gem
        @install_gem = install_gem
        @tag = tag
        @push_tag = push_tag
      end

      ##
      # Name of the tool to create.
      #
      # @param value [String]
      # @return [String]
      #
      attr_writer :name

      ##
      # Name of the gem to build. If `nil`, searches the context and current
      # directories and uses the first gemspec file it finds.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :gem_name

      ##
      # Path to the gem package to generate. If `nil`, defaults to a file name
      # based on the gem name and version, under "pkg" in the current directory.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :output

      ##
      # Flags that set the output path on the generated tool. If `nil`, no
      # flags are generated. If set to `true`, {DEFAULT_OUTPUT_FLAGS} is used.
      #
      # @param value [Array<String>,true,nil]
      # @return [Array<String>,true,nil]
      #
      attr_writer :output_flags

      ##
      # Whether the tool should push the gem to Rubygems.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :push_gem

      ##
      # Whether the tool should install the built gen locally.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :install_gem

      ##
      # Whether to tag the git repo with the gem version.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :tag

      ##
      # Whether to push the new tag to a git remote. This may be set to the
      # name of the remote as a string, to `true` to use {DEFAULT_PUSH_REMOTE}
      # by default, or to `false` to disable pushing.
      #
      # @param value [Boolean,String]
      # @return [Boolean,String]
      #
      attr_writer :push_tag

      # @private
      attr_reader :output
      # @private
      attr_reader :push_gem
      # @private
      attr_reader :install_gem
      # @private
      attr_reader :tag

      # @private
      def name
        @name || DEFAULT_TOOL_NAME
      end

      # @private
      def gem_name
        return @gem_name if @gem_name
        candidates = ::Dir.glob("*.gemspec")
        if candidates.empty?
          raise ToolDefinitionError, "Could not find a gemspec"
        end
        candidates.first.sub(/\.gemspec$/, "")
      end

      # @private
      def output_flags
        @output_flags == true ? DEFAULT_OUTPUT_FLAGS : Array(@output_flags)
      end

      # @private
      def push_tag
        @push_tag == true ? DEFAULT_PUSH_REMOTE : @push_tag
      end

      # @private
      def task_names
        names = []
        names << "Install" if @install_gem
        names << "Release" if @push_gem
        names.empty? ? "Build" : names.join(" and ")
      end

      on_expand do |template|
        tool(template.name) do
          desc "#{template.task_names} the gem: #{template.gem_name}"

          flag :yes, "-y", "--yes", desc: "Do not ask for interactive confirmation"
          if template.output_flags.empty?
            static :output, template.output
          else
            flag :output do
              flags(template.output_flags.map { |f| "#{f} VAL" })
              desc "output gem with the given filename"
              default template.output
              complete_values :file_system
            end
          end

          include :exec, exit_on_nonzero_status: true
          include :fileutils
          include :terminal

          to_run do
            require "rubygems"
            require "rubygems/package"
            ::Dir.chdir(context_directory || ::Dir.getwd) do
              gem_name = template.gem_name
              gemspec = ::Gem::Specification.load("#{gem_name}.gemspec")
              ::Gem::Package.build(gemspec)
              version = gemspec.version
              archive_name = "#{gem_name}-#{version}.gem"
              archive_path = output || "pkg/#{archive_name}"
              if archive_name != archive_path
                mkdir_p(::File.dirname(archive_path))
                mv(archive_name, archive_path)
              end
              if template.install_gem
                exit(1) unless yes || confirm("Install #{gem_name} #{version}? ", default: true)
                exec ["gem", "install", archive_path]
              end
              if template.push_gem
                if ::File.directory?(".git") && capture("git status -s").strip != ""
                  logger.error "Cannot push the gem when there are uncommited changes"
                  exit(1)
                end
                exit(1) unless yes || confirm("Release #{gem_name} #{version}? ", default: true)
                exec(["gem", "push", archive_path])
                if template.tag
                  exec(["git", "tag", "v#{version}"])
                  if template.push_tag
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
