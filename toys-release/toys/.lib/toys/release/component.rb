# frozen_string_literal: true

require "toys/release/change_set"
require "toys/release/changelog_file"
require "toys/release/gemspec_file"
require "toys/release/version_rb_file"

module Toys
  module Release
    ##
    # Represents a particular releasable component in the release system
    #
    class Component
      ##
      # Constructor
      #
      # @param repository [Toys::Release::Repository] the repository
      # @param name [String] The component name
      # @param environment_utils [Toys::Release::EnvironmentUtils] env utils
      #
      def initialize(repository, name, environment_utils)
        @repository = repository
        @settings = repository.settings.component_settings(name)
        @utils = environment_utils
        @changelog_file = ChangelogFile.new(changelog_path(from: :absolute), @utils)
        @version_rb_file = VersionRbFile.new(version_rb_path(from: :absolute), @utils)
        @gemspec_file = GemspecFile.new(gemspec_path(from: :absolute), @utils)
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
      # @return [Toys::Release::GemspecFile] The .gemspec file in this
      #     component
      #
      attr_reader :gemspec_file

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
      # from the repo root directory or an absolute path.
      #
      # @param from [:repo_root,:absolute] From where (defaults to `:repo_root`)
      # @return [String] The directory path
      #
      def directory(from: :repo_root)
        case from
        when :repo_root
          settings.directory
        when :absolute
          ::File.expand_path(settings.directory, @utils.repo_root_directory)
        else
          raise ArgumentError, "Unknown from value: #{from.inspect}"
        end
      end

      ##
      # Returns the path to a given file. It can be returned as a relative path
      # from the component directory, a relative path from the repo root
      # directory, or an absolute path.
      #
      # @param from [:directory,:repo_root,:absolute] From where (defaults to
      #     `:directory`)
      # @return [String] The path to the file
      #
      def file_path(path, from: :directory)
        case from
        when :directory
          path
        when :repo_root
          ::File.join(directory, path)
        when :absolute
          ::File.expand_path(path, directory(from: :absolute))
        else
          raise ArgumentError, "Unknown from value: #{from.inspect}"
        end
      end

      ##
      # Returns the path to the changelog. It can be returned as a relative
      # path from the component directory, a relative path from the repo root
      # directory, or an absolute path.
      #
      # @param from [:directory,:repo_root,:absolute] From where (defaults to
      #     `:directory`)
      # @return [String] The path to the changelog
      #
      def changelog_path(from: :directory)
        file_path(settings.changelog_path, from: from)
      end

      ##
      # Returns the path to the version.rb. It can be returned as a relative
      # path from the component directory, a relative path from the repo root
      # directory, or an absolute path.
      #
      # @param from [:directory,:repo_root,:absolute] From where (defaults to
      #     `:directory`)
      # @return [String] The path to the `version.rb` file
      #
      def version_rb_path(from: :directory)
        file_path(settings.version_rb_path, from: from)
      end

      ##
      # Returns the path to the gemspec. It can be returned as a relative
      # path from the component directory, a relative path from the repo root
      # directory, or an absolute path.
      #
      # @param from [:directory,:repo_root,:absolute] From where (defaults to
      #     `:directory`)
      # @return [String] The path to the gemspec
      #
      def gemspec_path(from: :directory)
        file_path("#{name}.gemspec", from: from)
      end

      ##
      # Validates the component and reports any errors.
      #
      def validate
        @utils.accumulate_errors("Component \"#{name}\" failed validation") do
          path = directory(from: :absolute)
          @utils.error("Missing directory #{path} for #{name}") unless ::File.directory?(path)
          @utils.error("Missing changelog #{changelog_file.path} for #{name}") unless changelog_file.exists?
          validate_version_rb_file
          validate_gemspec_file
          yield if block_given?
        end
      end

      ##
      # Validates the version.rb file
      #
      def validate_version_rb_file
        if !version_rb_file.exists?
          @utils.error("Missing version #{version_rb_file.path} for #{name}")
        elsif version_rb_file.current_version.nil?
          @utils.error("Unable to read VERSION constant from #{version_rb_file.path} for #{name}")
        end
      end

      ##
      # Validates the gemspec file if this component updates from dependencies
      #
      def validate_gemspec_file
        update_deps_settings = settings.update_dependencies
        return unless update_deps_settings
        if gemspec_file.exists?
          cur_deps = gemspec_file.current_dependencies
          update_deps_settings.dependencies.each do |dep_name|
            @utils.error("Gemspec #{gemspec_file.path} is missing #{dep_name}") unless cur_deps.key?(dep_name)
          end
        else
          @utils.error("Missing gemspec #{gemspec_file.path} for #{name}")
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
          path = changelog_path(from: :repo_root)
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
          path = version_rb_path(from: :repo_root)
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
      # Returns a changeset with the changes, from the given commit range, that
      # are relevant to this component.
      #
      # @param commits [Array<Toys::Release::CommitInfo>,nil] Commits to add.
      #     If not provided, uses `from` and `to` to get commits.
      # @param from [String,nil] The starting point, defaults to the last
      #     release tag. Set to nil explicitly to search the full history of
      #     the `to` commit.
      # @param to [String] The endpoint. Defaults to HEAD.
      #
      # @return [Toys::Release::ChangeSet]
      #
      def make_change_set(commits: nil, from: :default, to: nil)
        commits ||= begin
          to ||= "HEAD"
          from = latest_tag(ref: to) if from == :default
          @repository.commit_info_sequence(from: from, to: to)
        end
        changeset = ChangeSet.new(@repository.settings, @settings)
        commits.each do |commit|
          changeset.add_commit(commit) if touched?(commit)
        end
        changeset.finish
      end

      ##
      # Run bundler
      #
      # @return [Toys::Utils::Exec::Result]
      #
      def bundle
        cd do
          exec_result = @utils.exec(["bundle", "install"])
          @utils.error("Bundle install failed for #{name}.") unless exec_result.success?
          exec_result
        end
      end

      ##
      # Checks if the given commit touches this component.
      #
      # @param commit [Toys::Release::CommitInfo] A commit to check
      # @return [boolean] Whether the given commit touches this component
      #
      def touched?(commit)
        dir = settings.directory
        dir = "#{dir}/" unless dir.end_with?("/")

        escaped_name = ::Regexp.escape(name)
        return true if dir == "./" || /(^|\n)touch-component:\s+#{escaped_name}(\s|$)/i.match?(commit.message)
        return false if /(^|\n)no-touch-component:\s+#{escaped_name}(\s|$)/i.match?(commit.message)
        commit.modified_paths.any? do |file|
          (file.start_with?(dir) || settings.include_globs.any? { |pattern| ::File.fnmatch?(pattern, file) }) &&
            settings.exclude_globs.none? { |pattern| ::File.fnmatch?(pattern, file) }
        end
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
  end
end
