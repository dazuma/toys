# frozen_string_literal: true

require_relative "change_set"
require_relative "changelog_file"
require_relative "version_rb_file"

module Toys
  module Release
    ##
    # Represents a particular releasable component in the release system
    #
    class Component
      ##
      # Factory method
      #
      # @param repo_settings [Toys::Release::RepoSettings] the repo settings
      # @param name [String] The component name
      # @param environment_utils [Toys::Release::EnvironmentUtils] env utils
      #
      def self.build(repo_settings, name, environment_utils)
        settings = repo_settings.component_settings(name)
        if settings.type == "gem"
          GemComponent.new(repo_settings, settings, environment_utils)
        else
          Component.new(repo_settings, settings, environment_utils)
        end
      end

      # @private
      def initialize(repo_settings, settings, environment_utils)
        @repo_settings = repo_settings
        @settings = settings
        @utils = environment_utils
        @changelog_file = ChangelogFile.new(changelog_path(from: :absolute), @utils)
        @version_rb_file = VersionRbFile.new(version_rb_path(from: :absolute), @utils, @settings.version_constant)
        @coordination_group = nil
      end

      ##
      # @return [Toys::Release::ComponentSettings] The component settings
      #
      attr_reader :settings

      ##
      # @return [Toys::Release::ChangelogFile] The changelog file in this
      #     component
      #
      attr_reader :changelog_file

      ##
      # @return [Toys::Release::VersionRbFile] The version.rb file in this
      #     component
      #
      attr_reader :version_rb_file

      ##
      # @return [Array<Component>] The coordination group containing this
      #     component. If this component is not coordinated, it will be part of
      #     a one-element coordination group.
      #
      attr_reader :coordination_group

      ##
      # @return [String] The type of the component, either `component` or `gem`.
      #
      def type
        settings.type
      end

      ##
      # @return [String] The name of the component, e.g. the gem name.
      #
      def name
        settings.name
      end

      ##
      # Change the working directory to the component directory.
      #
      def cd(&block)
        ::Dir.chdir(directory(from: :absolute), &block)
      end

      ##
      # Returns the directory path. It can be returned either as a relative path
      # from the context directory or an absolute path.
      #
      # @param from [:context,:absolute] From where (defaults to `:context`)
      # @return [String] The directory path
      #
      def directory(from: :context)
        case from
        when :context
          settings.directory
        when :absolute
          ::File.expand_path(settings.directory, @utils.context_directory)
        else
          raise ArgumentError, "Unknown from value: #{from.inspect}"
        end
      end

      ##
      # Returns the path to a given file. It can be returned as a relative path
      # from the component directory, a relative path from the context
      # directory, or an absolute path.
      #
      # @param from [:directory,:context,:absolute] From where (defaults to
      #     `:directory`)
      # @return [String] The path to the file
      #
      def file_path(path, from: :directory)
        case from
        when :directory
          path
        when :context
          ::File.join(directory, path)
        when :absolute
          ::File.expand_path(path, directory(from: :absolute))
        else
          raise ArgumentError, "Unknown from value: #{from.inspect}"
        end
      end

      ##
      # Returns the path to the changelog. It can be returned as a relative
      # path from the component directory, a relative path from the context
      # directory, or an absolute path.
      #
      # @param from [:directory,:context,:absolute] From where (defaults to
      #     `:directory`)
      # @return [String] The path to the changelog
      #
      def changelog_path(from: :directory)
        file_path(settings.changelog_path, from: from)
      end

      ##
      # Returns the path to the version.rb. It can be returned as a relative
      # path from the component directory, a relative path from the context
      # directory, or an absolute path.
      #
      # @param from [:directory,:context,:absolute] From where (defaults to
      #     `:directory`)
      # @return [String] The path to the `version.rb` file
      #
      def version_rb_path(from: :directory)
        file_path(settings.version_rb_path, from: from)
      end

      ##
      # Validates the component and reports any errors.
      #
      def validate
        @utils.accumulate_errors("Component \"#{name}\" failed validation") do
          path = directory(from: :absolute)
          @utils.error("Missing directory #{path} for #{name}") unless ::File.directory?(path)
          @utils.error("Missing changelog #{changelog_file.path} for #{name}") unless changelog_file.exists?
          @utils.error("Missing version #{version_rb_file.path} for #{name}") unless version_rb_file.exists?
          version_constant = settings.version_constant.join("::")
          unless version_rb_file.eval_version
            @utils.error("#{version_rb_file.path} for #{name} didn't define #{version_constant}")
          end
          yield if block_given?
        end
      end

      ##
      # Returns the version of the latest release tag on the given branch.
      #
      # @param ref [String] The branch name or head ref. Optional. Defaults to
      #     the current HEAD.
      # @return [Gem::Version,nil] The version, or nil if no release tags found.
      #
      def latest_tag_version(ref: nil)
        ref ||= "HEAD"
        last_version = nil
        @utils.capture(["git", "tag", "--merged", ref], e: true).split("\n").each do |tag|
          match = %r{^#{name}/v(\d+\.\d+\.\d+(?:\.\w+)*)$}.match(tag)
          next unless match
          version = ::Gem::Version.new(match[1])
          last_version = version if !last_version || version > last_version
        end
        last_version
      end

      ##
      # Returns the latest release tag on the given branch.
      #
      # @param ref [String] The branch name or head ref. Optional. Defaults to
      #     the current HEAD.
      # @return [String,nil] The tag, or nil if no release tags found.
      #
      def latest_tag(ref: nil)
        version_tag(latest_tag_version(ref: ref))
      end

      ##
      # Returns the tag for the given version.
      #
      # @param version [::Gem::Version,nil]
      # @return [String] The tag, for a version
      # @return [nil] if the given version is nil.
      #
      def version_tag(version)
        version ? "#{name}/v#{version}" : nil
      end

      ##
      # Gets the current version from the changelog.
      #
      # @param at [String,nil] An optional committish
      # @return [::Gem::Version,nil] The current version
      #
      def current_changelog_version(at: nil)
        if at
          path = changelog_path(from: :context)
          content = @utils.capture(["git", "show", "#{at}:#{path}"], e: true)
          return ChangelogFile.current_version_from_content(content)
        end
        changelog_file.current_version
      end

      ##
      # Gets the current version from the version constant.
      #
      # @param at [String,nil] An optional committish
      # @return [::Gem::Version,nil] The current version
      #
      def current_constant_version(at: nil)
        if at
          path = version_rb_path(from: :context)
          content = @utils.capture(["git", "show", "#{at}:#{path}"], e: true)
          return VersionRbFile.current_version_from_content(content)
        end
        version_rb_file.current_version
      end

      ##
      # Verify the given version matches the current version from the changelog
      # and version constant. Reports any errors found.
      #
      # @param version [String,::Gem::Version] The claimed version
      #
      def verify_version(version)
        @utils.accumulate_errors("Requested #{name} version #{version} doesn't match existing files.") do
          changelog_version = changelog_file.current_version
          if version.to_s != changelog_version.to_s
            @utils.error("#{changelog_file.path} reports version #{changelog_version}.")
          end
          constant_version = version_rb_file.current_version
          if version.to_s != constant_version.to_s
            @utils.error("#{version_rb_file.path} reports version #{constant_version}.")
          end
        end
      end

      ##
      # Returns a list of commit messages, since the given committish, that are
      # relevant to this component.
      #
      # @param from [String,nil] The starting point, defaults to the last
      #     release tag. Set to nil explicitly to use the first commit.
      # @param to [String] The endpoint. Defaults to HEAD.
      # @return [ChangeSet]
      #
      def make_change_set(from: :default, to: nil)
        to ||= "HEAD"
        from = latest_tag(ref: to) if from == :default
        commits = from ? "#{from}..#{to}" : to
        changeset = ChangeSet.new(@repo_settings)
        shas = @utils.capture(["git", "log", commits, "--format=%H"], e: true).split("\n")
        shas.reverse_each do |sha|
          message = touched_message(sha)
          changeset.add_message(sha, message) if message
        end
        changeset.finish
      end

      ##
      # Run bundler
      #
      def bundle
        cd do
          exec_result = @utils.exec(["bundle", "install"])
          @utils.error("Bundle install failed for #{name}.") unless exec_result.success?
        end
        self
      end

      ##
      # Checks if the given sha touches this component. If so, returns the
      # commit message, otherwise returns nil.
      #
      # @return [String] if the given commit touches this component
      # @return [nil] if the given commit does not touch this component
      #
      def touched_message(sha)
        dir = settings.directory
        dir = "#{dir}/" unless dir.end_with?("/")

        message = @utils.capture(["git", "log", sha, "--max-count=1", "--format=%B"], e: true)
        return message if dir == "./" || /(^|\n)touch-component: #{name}(\s|$)/i.match?(message)

        result = @utils.exec(["git", "rev-parse", "#{sha}^"], out: :capture, err: :null)
        parent_sha =
          if result.success?
            result.captured_out.strip
          else
            @utils.capture(["git", "hash-object", "-t", "tree", "--stdin"], in: :null).strip
          end
        files = @utils.capture(["git", "diff", "--name-only", "#{parent_sha}..#{sha}"], e: true)
        files.split("\n").each do |file|
          return message if (file.start_with?(dir) ||
                            settings.include_globs.any? { |pattern| ::File.fnmatch?(pattern, file) }) &&
                            settings.exclude_globs.none? { |pattern| ::File.fnmatch?(pattern, file) }
        end
        nil
      end

      # @private
      attr_writer :coordination_group

      # @private
      def eql?(other)
        name == other.name
      end
      alias == eql?

      # @private
      def hash
        name.hash
      end
    end

    ##
    # Subclass for Gem components
    #
    class GemComponent < Component
      ##
      # Returns the path to the gemspec. It can be returned as a relative path
      # from the component directory, a relative path from the context
      # directory, or an absolute path.
      #
      # @param from [:directory,:context,:absolute] From where (defaults to
      #     `:directory`)
      # @return [String] The path to the gemspec file
      #
      def gemspec_path(from: :directory)
        file_path("#{name}.gemspec", from: from)
      end

      ##
      # Validates the component and reports any errors.
      # Includes both errors from the base class and gem-specific errors.
      #
      def validate
        super do
          path = gemspec_path(from: :absolute)
          @utils.error("Missing gemspec #{path} for #{name}") unless ::File.file?(path)
        end
      end

      ##
      # Return a list of released versions
      #
      # @return [Array<::Gem::Version>]
      #
      def released_versions
        content = @utils.capture(["gem", "info", "-r", "-a", name], e: true)
        match = /#{name} \(([\w., ]+)\)/.match(content)
        return [] unless match
        match[1].split(/,\s+/).map { |str| ::Gem::Version.new(str) }
      end

      ##
      # Determines if a version has been released
      #
      # @param version [::Gem::Version,String] The version to check
      # @return [boolean] Whether the version has been released
      #
      def version_released?(version)
        cmd = ["gem", "search", name, "--exact", "--remote", "--version", version.to_s]
        content = @utils.capture(cmd)
        content.include?("#{name} (#{version})")
      end
    end
  end
end
