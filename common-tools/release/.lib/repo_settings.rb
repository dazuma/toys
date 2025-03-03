# frozen_string_literal: true

require "yaml"

require_relative "semver"

module ToysReleaser
  ##
  # How to handle a conventional commit tag
  #
  class CommitTagSettings
    ##
    # Create a CommitTagSettings from either a tag name string (which will
    # default to patch releases) or a hash with fields.
    #
    def initialize(input)
      semver_name = nil
      case input
      when ::String
        @tag = input
      when ::Hash
        if input.size == 1
          key = input.keys.first
          value = input.values.first
          if value.is_a?(::Hash)
            @tag = key
            @header = value["header"] || value["label"]
            semver_name = value["semver"]
          elsif key == "tag"
            @tag = value
          else
            @tag = key
            semver_name = value
          end
        else
          @tag = input["tag"]
          @header = input["header"] || input["label"]
          semver_name = input["semver"]
        end
      end
      raise "tag missing in #{input}" unless @tag
      @header ||= @tag.upcase
      @semver = Semver.for_name(semver_name || "patch")
      raise "unknown semver: #{semver_name} in #{input}" unless @semver
    end

    ##
    # @return [String] The conventional commit tag being described
    #
    attr_reader :tag

    ##
    # @return [String] A header describing this type of change in a changelog
    #
    attr_reader :header

    ##
    # @return [ToysReleaser::Semver] The semver type for this tag.
    #
    attr_reader :semver
  end

  ##
  # Configuration of a single component
  #
  class ComponentSettings
    ##
    # Create a ComponentSettings from input data structures
    #
    # @param info [Hash] Nested hash input
    # @param has_multiple_components [boolean] Whether there are other components
    #
    def initialize(repo_settings, info, has_multiple_components)
      @name = info["name"]
      @type = info["type"] || "component"
      @directory = info["directory"] || (has_multiple_components ? name : ".")

      read_file_modification_info(info)
      read_gh_pages_info(repo_settings, info, has_multiple_components)
      read_tasks_info(repo_settings, info)
    end

    ##
    # @return [String] The name of the component
    #
    attr_reader :name

    ##
    # @return [String] The type of component. Default is `"component"`.
    #     Subclasses may define other types.
    #
    attr_reader :type

    ##
    # @return [String] The directory within the repo in which the component
    #     is located
    #
    attr_reader :directory

    ##
    # @return [String] Path to the changelog relative to the component's
    #     directory
    #
    attr_reader :changelog_path

    ##
    # @return [String] Path to version.rb relative to the component's directory
    #
    attr_reader :version_rb_path

    ##
    # @return [Array<String>] The constant used to define the version, as an
    #     array representing the module path
    #
    attr_reader :version_constant

    ##
    # @return [boolean] Whether gh-pages publication is enabled.
    #
    attr_reader :gh_pages_enabled

    ##
    # @return [String] The directory within the gh_pages branch where the
    #     reference documentation should be built
    #
    attr_reader :gh_pages_directory

    ##
    # @return [String] The name of the Javascript variable representing this
    #     gem's version in gh_pages
    #
    attr_reader :gh_pages_version_var

    ##
    # @return [Array<TaskSettings>] A list of build tasks.
    #
    attr_reader :tasks

    ##
    # @return [TaskSettings,nil] The unique task with the given name
    #
    def task_named(name)
      tasks.find { |t| t.name == name }
    end

    private

    def read_file_modification_info(info)
      segments = info["name"].split("-")
      name_path = segments.join("/")
      @version_rb_path = info["version_rb_path"] || "lib/#{name_path}/version.rb"
      @version_constant = info["version_constant"] ||
                          (segments.map { |seg| camelize(seg) } + ["VERSION"])
      @version_constant = @version_constant.split("::") if @version_constant.is_a?(::String)
      @changelog_path = info["changelog_path"] || "CHANGELOG.md"
    end

    def read_gh_pages_info(repo_settings, info, has_multiple_components)
      @gh_pages_directory = info["gh_pages_directory"] || (has_multiple_components ? name : ".")
      @gh_pages_version_var = info["gh_pages_version_var"] ||
                              (has_multiple_components ? "version_#{name}".tr("-", "_") : "version")
      @gh_pages_enabled = info.fetch("gh_pages_enabled") do |_key|
        repo_settings.gh_pages_enabled ||
          info.key?("gh_pages_directory") ||
          info.key?("gh_pages_version_var")
      end
    end

    def read_tasks_info(repo_settings, info)
      @tasks = info["tasks"] ? repo_settings.read_tasks(info["tasks"]) : repo_settings.default_tasks(@type)
      @tasks = repo_settings.modify_tasks(@tasks, info["modify_tasks"] || [])
      @tasks = repo_settings.prepend_tasks(@tasks, info["prepend_tasks"] || [])
      @tasks = repo_settings.append_tasks(@tasks, info["append_tasks"] || [])
      @tasks = repo_settings.delete_tasks(@tasks, info["delete_tasks"] || [])
    end

    def camelize(str)
      str.to_s
         .sub(/^_/, "")
         .sub(/_$/, "")
         .gsub(/_+/, "_")
         .gsub(/(?:^|_)([a-zA-Z])/) { ::Regexp.last_match(1).upcase }
    end
  end

  ##
  # Configuration of a task
  #
  class TaskSettings
    def initialize(name, task, options)
      @name = name
      @task = task
      @options = options
    end

    ##
    # @return [String] Name of this task
    #
    attr_reader :name

    ##
    # @return [String] Type of task
    #
    attr_reader :task

    ##
    # @return [Hash{String=>Object}] Options for this task
    #
    attr_reader :options

    ##
    # Make a deep copy
    #
    # @return [TaskSettings] A deep copy
    #
    def deep_copy
      TaskSettings.new(name, task, RepoSettings.deep_copy(options))
    end
  end

  ##
  # Full repo configuration
  #
  class RepoSettings
    ##
    # Load repo settings from the current environment.
    #
    # @param environment_utils [ToysReleaser::EnvrionmentUtils]
    # @return [RepoSettings]
    #
    def self.load_from_environment(enviroment_utils)
      file_path = enviroment_utils.tool_context.find_data("releases.yml")
      enviroment_utils.error("Unable to find releases.yml data file") unless file_path
      info = ::YAML.load_file(file_path)
      settings = RepoSettings.new(info)
      errors = settings.errors
      enviroment_utils.error("Errors while loading releases.yml", *errors) unless errors.empty?
      settings
    end

    ##
    # Basic deep copy tool that will handle nested arrays and hashes
    #
    def self.deep_copy(obj)
      case obj
      when ::Hash
        obj.transform_values { |v| deep_copy(v) }
      when ::Array
        obj.map { |v| deep_copy(v) }
      else
        obj.dup
      end
    end

    ##
    # Create a repo configuration object.
    #
    # @param info [Hash] Configuration hash read from JSON.
    #
    def initialize(info)
      @warnings = []
      @errors = []
      @default_component_name = nil
      read_global_info(info)
      read_commit_lint_info(info)
      read_commit_tag_info(info)
      read_default_task_info(info)
      read_component_info(info)
      read_coordination_info(info)
    end

    ##
    # @return[Array<String>] Non-fatal warnings detected when loading the
    #     settings, or the empty array if there were no warnings.
    #
    attr_reader :warnings

    ##
    # @return[Array<String>] Fatal errors detected when loading the settings,
    #     or the empty array if there were no errors.
    #
    attr_reader :errors

    ##
    # @return [String] The repo path in the form `owner/repo`.
    #
    attr_reader :repo_path

    ##
    # @return [String] The name of the main branch (typically `main`)
    #
    attr_reader :main_branch

    ##
    # @return [String] The name of a git user to use for commits
    #
    attr_reader :git_user_name

    ##
    # @return [String] The email of a git user to use for commits
    #
    attr_reader :git_user_email

    ##
    # @return [String] The name of the default component to release
    #
    attr_reader :default_component_name

    ##
    # @return [Array<Array<String>>] An array of groups of component names whose
    #     releases should be coordinated.
    #
    attr_reader :coordination_groups

    ##
    # @return [Regexp,nil] A regular expression identifying all the GitHub
    #     checks that must pass before a release will take place, or nil to
    #     ignore GitHub checks
    #
    attr_reader :required_checks_regexp

    ##
    # @return [Regexp,nil] A regular expression identifying all the
    #     release-related GitHub checks
    #
    attr_reader :release_jobs_regexp

    ##
    # @return [Numeric] The number of seconds that releases will wait for
    #     checks to complete.
    #
    attr_reader :required_checks_timeout

    ##
    # @return [boolean] Whether gh-pages publication is enabled.
    #
    attr_reader :gh_pages_enabled

    ##
    # @return [Array<String>] The merge strategies allowed when linting
    #     commit messages.
    #
    attr_reader :commit_lint_merge

    ##
    # @return [Array<String>] The allowed conventional commit types when
    #     linting commit messages.
    #
    attr_reader :commit_lint_allowed_types

    ##
    # @return [Hash{String=>CommitTagSettings}] The conventional commit types
    #     recognized as release-triggering, along with the type of change they
    #     map to.
    #
    attr_reader :release_commit_tags

    ##
    # @return [String] Header for breaking changes in a changelog
    #
    attr_reader :breaking_change_header

    ##
    # @return [String] No significant updates notice
    #
    attr_reader :no_significant_updates_notice

    ##
    # @return [String] GitHub label applied for pending release
    #
    attr_reader :release_pending_label

    ##
    # @return [String] GitHub label applied for release in error state
    #
    attr_reader :release_error_label

    ##
    # @return [String] GitHub label applied for aborted release
    #
    attr_reader :release_aborted_label

    ##
    # @return [String] GitHub label applied for completed release
    #
    attr_reader :release_complete_label

    ##
    # @return [String] Prefix for release branches
    #
    attr_reader :release_branch_prefix

    ##
    # @return [String] The owner of the repo
    #
    def repo_owner
      repo_path.split("/").first
    end

    ##
    # @return [String] The name of the repo
    #
    def repo_name
      repo_path.split("/").last
    end

    ##
    # @return [boolean] Whether to signoff release commits
    #
    def signoff_commits?
      @signoff_commits
    end

    ##
    # @return [boolean] Whether the automation should perform releases in
    #     response to release pull requests being merged.
    #
    def enable_release_automation?
      @enable_release_automation
    end

    ##
    # @return [boolean] Whether conventional commit linting errors should fail
    #     GitHub checks.
    #
    def commit_lint_fail_checks?
      @commit_lint_fail_checks
    end

    ##
    # @return [boolean] Whether to perform conventional commit linting.
    #
    def commit_lint_active?
      @commit_lint_active
    end

    ##
    # @return [Array<String>] A list of all component names.
    #
    def all_component_names
      @components.keys
    end

    ##
    # @return [Array<ComponentSettings>] A list of all component settings.
    #
    def all_component_settings
      @components.values
    end

    ##
    # Get the settings for a single component.
    #
    # @param name [String] Name of a component.
    # @return [ComponentSettings,nil] The component settings for the given
    #     name, or nil if the name is not found.
    #
    def component_settings(name)
      @components[name]
    end

    ##
    # Get the default task pipeline settings for a component type
    #
    # @param component_type [String] Type of component
    # @return [Array<TaskSettings>] Task pipeline
    #
    def default_tasks(component_type)
      (@default_tasks[component_type] || @default_tasks["component"]).map(&:deep_copy)
    end

    # @private
    def read_tasks(info)
      tasks = []
      info.each do |task_info|
        task_info = task_info.dup
        name = task_info.delete("name")
        type = task_info.delete("task")
        if type
          tasks << TaskSettings.new(name, type, task_info)
        else
          @errors << "No task type provided for task #{name.inspect}"
        end
      end
      tasks
    end

    # @private
    def modify_tasks(tasks, modifications)
      modifications.each do |mod_name, mod_data|
        task_to_modify = tasks.find { |task| task.name == mod_name }
        unless task_to_modify
          @errors << "Task name to modify #{mod_name} not found."
          next
        end
        opts = task_to_modify.options
        mod_data.each do |key, value|
          if value.nil?
            opts.delete(key)
          else
            opts[key] = value
          end
        end
      end
      tasks
    end

    # @private
    def prepend_tasks(tasks, info)
      pre_tasks = read_tasks(info)
      pre_tasks + tasks
    end

    # @private
    def append_tasks(tasks, info)
      post_tasks = read_tasks(info)
      tasks + post_tasks
    end

    # @private
    def delete_tasks(tasks, info)
      info.each do |del_name|
        index = tasks.find_index { |task| task.name == del_name }
        if index
          tasks.delete_at(index)
        else
          @errors << "Unable to find task named #{del_name} to delete."
        end
      end
      tasks
    end

    private

    DEFAULT_MAIN_BRAMCH = "main"
    private_constant :DEFAULT_MAIN_BRAMCH

    DEFAULT_RELEASE_COMMIT_TAGS = [
      {
        "tag" => "feat",
        "header" => "ADDED",
        "semver" => "minor",
      }.freeze,
      {
        "tag" => "fix",
        "header" => "FIXED",
      }.freeze,
      "docs",
    ].freeze
    private_constant :DEFAULT_RELEASE_COMMIT_TAGS

    DEFAULT_TASKS = {
      "component" => [
        {
          "name" => "github-release",
          "task" => "GitHubRelease",
        }.freeze,
      ].freeze,
      "gem" => [
        {
          "name" => "bundle",
          "task" => "Bundle",
        }.freeze,
        {
          "name" => "build_gem",
          "task" => "BuildGem",
        }.freeze,
        {
          "name" => "build_yard",
          "task" => "BuildYard",
          "require_gh_pages_enabled" => true,
        }.freeze,
        {
          "name" => "github_release",
          "task" => "GitHubRelease",
        }.freeze,
        {
          "name" => "release_gem",
          "task" => "ReleaseGem",
          "input" => "build_gem",
        }.freeze,
        {
          "name" => "push_gh_pages",
          "task" => "PushGhPages",
          "input" => "build_yard",
        }.freeze,
      ].freeze,
    }.freeze
    private_constant :DEFAULT_TASKS

    DEFAULT_BREAKING_CHANGE_HEADER = "BREAKING CHANGE"
    private_constant :DEFAULT_BREAKING_CHANGE_HEADER

    DEFAULT_NO_SIGNIFICANT_UPDATES_NOTICE = "No significant updates."
    private_constant :DEFAULT_NO_SIGNIFICANT_UPDATES_NOTICE

    DEFAULT_RELEASE_PENDING_LABEL = "release: pending"
    private_constant :DEFAULT_RELEASE_PENDING_LABEL

    DEFAULT_RELEASE_ERROR_LABEL = "release: error"
    private_constant :DEFAULT_RELEASE_ERROR_LABEL

    DEFAULT_RELEASE_ABORTED_LABEL = "release: aborted"
    private_constant :DEFAULT_RELEASE_ABORTED_LABEL

    DEFAULT_RELEASE_COMPLETE_LABEL = "release: complete"
    private_constant :DEFAULT_RELEASE_COMPLETE_LABEL

    def read_global_info(info)
      @main_branch = info["main_branch"] || DEFAULT_MAIN_BRAMCH
      @repo_path = info["repo"]
      @signoff_commits = info["signoff_commits"] ? true : false
      @gh_pages_enabled = info["gh_pages_enabled"] ? true : false
      @enable_release_automation = info["enable_release_automation"] != false
      required_checks = info["required_checks"]
      @required_checks_regexp = required_checks == false ? nil : ::Regexp.new(required_checks.to_s)
      @required_checks_timeout = info["required_checks_timeout"] || 900
      @release_jobs_regexp = ::Regexp.new(info["release_jobs_regexp"] || "^release-")
      @release_branch_prefix = info["release_branch_prefix"] || "release"
      @git_user_name = info["git_user_name"]
      @git_user_email = info["git_user_email"]
      @release_pending_label = info["release_pending_label"] || DEFAULT_RELEASE_PENDING_LABEL
      @release_error_label = info["release_error_label"] || DEFAULT_RELEASE_ERROR_LABEL
      @release_aborted_label = info["release_aborted_label"] || DEFAULT_RELEASE_ABORTED_LABEL
      @release_complete_label = info["release_complete_label"] || DEFAULT_RELEASE_COMPLETE_LABEL
      @errors << "Repo key missing from releases.yml" unless @repo_path
    end

    def read_commit_lint_info(info)
      info = info["commit_lint"]
      @commit_lint_active = !info.nil?
      info = {} unless info.is_a?(::Hash)
      @commit_lint_fail_checks = info["fail_checks"] ? true : false
      @commit_lint_merge = Array(info["merge"] || ["squash", "merge", "rebase"])
      @commit_lint_allowed_types = info["allowed_types"]
      if @commit_lint_allowed_types
        @commit_lint_allowed_types = Array(@commit_lint_allowed_types).map(&:downcase)
      end
    end

    def read_commit_tag_info(info)
      release_commit_tag_data = info["release_commit_tags"] || DEFAULT_RELEASE_COMMIT_TAGS
      @release_commit_tags = release_commit_tag_data.to_h do |value|
        settings = CommitTagSettings.new(value)
        [settings.tag, settings]
      end
      @breaking_change_header = info["breaking_change_header"] || DEFAULT_BREAKING_CHANGE_HEADER
      @no_significant_updates_notice = info["no_significant_updates_notice"] || DEFAULT_NO_SIGNIFICANT_UPDATES_NOTICE
    end

    def read_default_task_info(info) # rubocop:disable Metrics/AbcSize
      default_task_data = info["default_tasks"] || DEFAULT_TASKS
      @default_tasks = {}
      default_task_data.each do |key, data|
        @default_tasks[key] = read_tasks(data)
      end
      (info["modify_default_tasks"] || {}).each do |key, data|
        @default_tasks[key] = modify_tasks(@default_tasks[key], data)
      end
      (info["append_default_tasks"] || {}).each do |key, data|
        @default_tasks[key] = append_tasks(@default_tasks[key], data)
      end
      (info["prepend_default_tasks"] || {}).each do |key, data|
        @default_tasks[key] = prepend_tasks(@default_tasks[key], data)
      end
      (info["delete_default_tasks"] || {}).each do |key, data|
        @default_tasks[key] = delete_tasks(@default_tasks[key], data)
      end
    end

    def read_component_info(info)
      @components = {}
      @default_component_name = nil
      @has_multiple_components = (info["components"]&.size.to_i + info["gems"]&.size.to_i) > 1
      info["gems"]&.each do |component_info|
        component_info["type"] = "gem"
        read_component_settings(component_info)
      end
      info["components"]&.each do |component_info|
        read_component_settings(component_info)
      end
      @errors << "No components found" if @components.empty?
    end

    def read_component_settings(component_info)
      component = ComponentSettings.new(self, component_info, @has_multiple_components)
      if component.name.empty?
        @errors << "A component is missing a name"
      elsif @components[component.name]
        @errors << "Duplicate component #{component.name.inspect}"
      else
        @components[component.name] = component
        @default_component_name ||= component.name
      end
    end

    def read_coordination_info(info)
      if info["coordinate_versions"]
        @coordination_groups = [@components.keys]
        return
      end
      @coordination_groups = Array(info["coordination_groups"])
      @coordination_groups = [@coordination_groups] if @coordination_groups.first.is_a?(::String)
      seen = {}
      @coordination_groups.each do |group|
        group.each do |member|
          if !@components.key?(member)
            @errors << "Unrecognized component #{member.inspect} listed in a coordination group"
          elsif seen.key?(member)
            @errors << "Component #{member.inspect} is in multiple coordination groups"
          else
            seen[member] = true
          end
        end
      end
    end
  end
end
