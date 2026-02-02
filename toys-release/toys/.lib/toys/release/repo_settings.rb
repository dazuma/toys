# frozen_string_literal: true

require "yaml"

require "toys/release/semver"

module Toys
  module Release
    ##
    # How to handle a conventional commit tag
    #
    class CommitTagSettings
      # @private
      ScopeInfo = ::Struct.new(:semver, :header)

      ##
      # Create an empty settings for an unknown tag
      #
      # @param tag [String] Conventional commit tag
      # @return [CommitTagSettings]
      #
      def self.empty(tag)
        new({"tag" => tag, "header" => nil}, [])
      end

      ##
      # @private
      # Create a CommitTagSettings from an input hash.
      #
      def initialize(info, errors)
        @tag = info.delete("tag").to_s
        errors << "Commit tag missing : #{info}" if @tag.empty?
        @header = info.fetch("header", @tag.upcase) || :hidden
        info.delete("header")
        @semver = load_semver(info.delete("semver"), errors)
        @scopes = {}
        info.delete("scopes")&.each do |scope_info|
          load_scope(scope_info, errors)
        end
        info.each_key do |key|
          errors << "Unknown key #{key.inspect} in configuration of tag #{@tag.inspect}"
        end
      end

      ##
      # @return [String] The conventional commit tag being described
      #
      attr_reader :tag

      ##
      # Return the semver type for this tag and scope.
      #
      # @param scope [String,nil] The scope, or nil for no scope
      # @return [Toys::Release::Semver] The semver type
      #
      def semver(scope = nil)
        @scopes[scope]&.semver || @semver
      end

      ##
      # Return a header describing this type of change in a changelog.
      #
      # @param scope [String,nil] The scope, or nil for no scope
      # @return [String] The header
      # @return [:hidden] if this type of change should not appear in the
      #     changelog
      #
      def header(scope = nil)
        @scopes[scope]&.header || @header
      end

      ##
      # Return an array of all headers used by this tag
      #
      # @return [Array<String>]
      #
      def all_headers
        @all_headers ||= begin
          result = []
          result << @header unless @header == :hidden
          @scopes.each_value do |scope_info|
            result << scope_info.header unless scope_info.header.nil? || scope_info.header == :hidden
          end
          result.uniq
        end
      end

      private

      def load_scope(info, errors)
        scope = info.delete("scope").to_s
        errors << "Commit tag scope missing under tag #{@tag.inspect} : #{info}" if scope.empty?
        scope_semver = load_semver(info.delete("semver"), errors, scope) if info.key?("semver")
        scope_header = info.fetch("header", :inherit) || :hidden
        info.delete("header")
        scope_header = nil if scope_header == :inherit
        @scopes[scope] = ScopeInfo.new(scope_semver, scope_header)
        info.each_key do |key|
          errors << "Unknown key #{key.inspect} in configuration of tag \"#{@tag}(#{scope})\""
        end
      end

      def load_semver(value, errors, scope = nil)
        result = Semver.for_name(value || "none")
        unless result
          tag = scope ? "#{@tag}(#{scope})" : @tag
          errors << "Unknown semver: #{value} for tag #{tag}"
          result = Semver::NONE
        end
        result
      end
    end

    ##
    # Configuration of dependency updating
    #
    class UpdateDepSettings
      # @private
      def initialize(info, errors)
        @dependencies = Array(info.delete("dependencies"))
        load_semvers(info, errors)
        check_problems(info, errors)
      end

      ##
      # @return [Array<String>] List of component names included in dependency
      #     updates.
      #
      attr_reader :dependencies

      ##
      # @return [Toys::Release::Semver] The minimum semver level of a
      #     dependency update that should trigger an update of the kitchen sink
      #     component. NONE indicates all dependency updates should trigger.
      #
      attr_reader :dependency_semver_threshold

      ##
      # @return [Toys::Release::Semver] The highest semver level allowed to
      #     float in the pessimistic dependency version constraints used to
      #     specify the dependencies. NONE indicates that dependencies should
      #     require the exact release version.
      #
      attr_reader :pessimistic_constraint_level

      private

      def load_semvers(info, errors)
        dependency_semver_threshold = info.delete("dependency_semver_threshold") || "minor"
        dependency_semver_threshold = "none" if dependency_semver_threshold.to_s.downcase == "all"
        @dependency_semver_threshold = Semver.for_name(dependency_semver_threshold)
        unless @dependency_semver_threshold
          errors << "Unrecognized value: #{dependency_semver_threshold} for dependency_semver_threshold"
          @dependency_semver_threshold = Semver::NONE
        end
        pessimistic_constraint_level = info.delete("pessimistic_constraint_level") || "minor"
        pessimistic_constraint_level = "none" if pessimistic_constraint_level.to_s.downcase == "exact"
        @pessimistic_constraint_level = Toys::Release::Semver.for_name(pessimistic_constraint_level)
        unless @pessimistic_constraint_level
          errors << "Unrecognized value: #{pessimistic_constraint_level} for pessimistic_constraint_level"
          @pessimistic_constraint_level = Semver::NONE
        end
      end

      def check_problems(info, errors)
        info.each_key do |key|
          errors << "Unknown key #{key.inspect} for update_dependencies"
        end
        errors << 'update_dependencies is missing required key "dependencies"' if @dependencies.empty?
      end
    end

    ##
    # Configuration of a single component
    #
    class ComponentSettings
      ##
      # @private
      # Create a ComponentSettings from input data structures
      #
      # @param repo_settings [Toys::Release::RepoSettings]
      # @param info [Hash] Nested hash input
      # @param has_multiple_components [boolean] Whether there are other
      #     components
      #
      def initialize(repo_settings, info, has_multiple_components)
        @name = info.delete("name").to_s
        read_path_info(info, has_multiple_components)
        read_file_modification_info(info)
        read_gh_pages_info(info, repo_settings, has_multiple_components)
        read_steps_info(info, repo_settings)
        read_commit_tag_info(info, repo_settings)
        read_update_deps(info, repo_settings)
        check_problems(info, repo_settings)
      end

      ##
      # @return [String] The name of the component
      #
      attr_reader :name

      ##
      # @return [String] The directory within the repo in which the component
      #     is located
      #
      attr_reader :directory

      ##
      # @return [Array<String>] Additional globs that should be checked for
      #     changes
      #
      attr_reader :include_globs

      ##
      # @return [Array<String>] Globs that should be ignored when checking for
      #     changes
      #
      attr_reader :exclude_globs

      ##
      # @return [String] Path to the changelog relative to the component's
      #     directory
      #
      attr_reader :changelog_path

      ##
      # @return [String] Path to version.rb relative to the component's
      #     directory
      #
      attr_reader :version_rb_path

      ##
      # @return [String,Array<String>,nil] Deprecated and unused
      #
      attr_reader :version_constant

      ##
      # @return [boolean] Whether gh-pages publication is enabled.
      #
      attr_reader :gh_pages_enabled

      ##
      # @return [String,nil] The directory within the gh_pages branch where the
      #     reference documentation should be built, or nil if gh_pages is not
      #     enabled.
      #
      attr_reader :gh_pages_directory

      ##
      # @return [String,nil] The name of the Javascript variable representing
      #     this gem's version in gh_pages, or nil if gh_pages is not enabled.
      #
      attr_reader :gh_pages_version_var

      ##
      # @return [Array<StepSettings>] A list of build steps.
      #
      attr_reader :steps

      ##
      # @return [Array<CommitTagSettings>] The conventional commit types
      #     recognized as release-triggering, along with information on the
      #     change they map to.
      #
      attr_reader :commit_tags

      ##
      # @return [:plain,:link,:delete] What to do with issue number suffixes in
      #     commit messages.
      #
      attr_reader :issue_number_suffix_handling

      ##
      # @return [String] Header for breaking changes in a changelog
      #
      attr_reader :breaking_change_header

      ##
      # @return [String] Header for dependency updates in a changelog
      #
      attr_reader :update_dependency_header

      ##
      # @return [String] Notice displayed in the changelog when there are
      #     otherwise no significant updates in the release
      #
      attr_reader :no_significant_updates_notice

      ##
      # @return [UpdateDepsSettings,nil] Configuration for treating this
      #     component as a kitchen sink that updates when dependencies update.
      #
      attr_reader :update_dependencies

      ##
      # @return [StepSettings,nil] The unique step with the given name
      #
      def step_named(name)
        steps.find { |t| t.name == name }
      end

      ##
      # Look up the settings for the given named tag.
      #
      # @param tag [String] Conventional commit tag to look up
      # @return [CommitTagSettings] The commit tag settings for the given tag
      #
      def commit_tag_named(tag)
        commit_tags.find { |elem| elem.tag == tag } || CommitTagSettings.empty(tag)
      end

      private

      def read_path_info(info, has_multiple_components)
        @directory = info.delete("directory") || (has_multiple_components ? name : ".")
        @include_globs = Array(info.delete("include_globs"))
        @exclude_globs = Array(info.delete("exclude_globs"))
      end

      def read_file_modification_info(info)
        name_path = @name.split("-").join("/")
        @version_rb_path = info.delete("version_rb_path") || "lib/#{name_path}/version.rb"
        @changelog_path = info.delete("changelog_path") || "CHANGELOG.md"
        @version_constant = info.delete("version_constant")
      end

      def read_gh_pages_info(info, repo_settings, has_multiple_components)
        @gh_pages_enabled = info.delete("gh_pages_enabled")
        @gh_pages_directory = info.delete("gh_pages_directory")
        @gh_pages_version_var = info.delete("gh_pages_version_var")
        if @gh_pages_enabled || @gh_pages_directory || @gh_pages_version_var ||
           (@gh_pages_enabled.nil? && repo_settings.gh_pages_enabled)
          @gh_pages_enabled = true
          @gh_pages_directory ||= has_multiple_components ? name : "."
          @gh_pages_version_var ||= has_multiple_components ? "version_#{name}".gsub(/\W/, "_") : "version"
        else
          @gh_pages_enabled = false
          @gh_pages_directory = @gh_pages_version_var = nil
        end
      end

      def read_steps_info(info, repo_settings)
        steps_info = info.delete("steps")
        @steps = steps_info ? repo_settings.read_steps(steps_info) : repo_settings.steps.map(&:deep_copy)
        modify_steps_info = info.delete("modify_steps")
        @steps = repo_settings.modify_steps(@steps, modify_steps_info) if modify_steps_info
        prepend_steps_info = info.delete("prepend_steps")
        @steps = repo_settings.prepend_steps(@steps, prepend_steps_info) if prepend_steps_info
        append_steps_info = info.delete("append_steps")
        @steps = repo_settings.append_steps(@steps, append_steps_info) if append_steps_info
        delete_steps_info = info.delete("delete_steps")
        @steps = repo_settings.delete_steps(@steps, delete_steps_info) if delete_steps_info
      end

      def read_commit_tag_info(info, repo_settings)
        commit_tags_info = info.delete("commit_tags")
        @commit_tags =
          if commit_tags_info
            repo_settings.read_commit_tags(commit_tags_info)
          else
            repo_settings.commit_tags.dup
          end
        @breaking_change_header = info.delete("breaking_change_header") || repo_settings.breaking_change_header
        @update_dependency_header = info.delete("update_dependency_header") || repo_settings.update_dependency_header
        @no_significant_updates_notice =
          info.delete("no_significant_updates_notice") || repo_settings.no_significant_updates_notice
        @issue_number_suffix_handling =
          repo_settings.read_issue_number_suffix_handling(info, repo_settings.issue_number_suffix_handling)
      end

      def read_update_deps(info, repo_settings)
        update_deps_info = info.delete("update_dependencies")
        @update_dependencies =
          if update_deps_info
            UpdateDepSettings.new(update_deps_info, repo_settings.errors)
          end
      end

      def camelize(str)
        str.to_s
           .sub(/^_/, "")
           .sub(/_$/, "")
           .gsub(/_+/, "_")
           .gsub(/(?:^|_)([a-zA-Z])/) { ::Regexp.last_match(1).upcase }
      end

      def check_problems(info, repo_settings)
        info.each_key do |key|
          repo_settings.errors << "Unknown key #{key.inspect} in component #{@name.inspect}"
        end
        repo_settings.errors << 'Component is missing required key "name"' if @name.empty?
      end
    end

    ##
    # Configuration of input settings for a step.
    # An input declares a dependency on a step, and copies any files output by
    # that dependency.
    #
    class InputSettings
      ##
      # @private
      # Construct input settings
      #
      # @param info [Hash,String] Config data
      #
      def initialize(info, errors, containing_step_name)
        @step_name = @dest = @source_path = @dest_path = nil
        case info
        when ::String
          @step_name = info
          @dest = "component"
        when ::Hash
          @step_name = info.delete("name").to_s
          if @step_name.empty?
            errors << "Missing required key \"name\" in input for step #{containing_step_name.inspect}"
          end
          @dest = info.delete("dest")
          if @dest == false
            @dest = "none"
          elsif @dest.nil?
            @dest = "component"
          end
          @source_path = info.delete("source_path")
          @dest_path = info.delete("dest_path")
          @collisions = info.delete("collisions") || "error"
          info.each_key do |key|
            errors << "Unknown key #{key.inspect} in input for step #{containing_step_name.inspect}"
          end
        end
      end

      ##
      # @return [String] Name of the step to copy data from.
      #
      attr_reader :step_name

      ##
      # @return [String,false] Where to copy data to. Possible values are
      #     "component", "repo_root", "output", "temp", and "none". If "none",
      #     no copying is performed and this input declares a dependency only.
      #
      attr_reader :dest

      ##
      # @return [String,nil] Path in the source to copy from. Can be a path to
      #     a file or a directory. If nil, copy everything from the input.
      #
      attr_reader :source_path

      ##
      # @return [String,nil] Path in the destination to copy to, relative to
      #     the destination. If nil, uses the source path.
      #
      attr_reader :dest_path

      ##
      # @return [String] What to do if a collision occurs. Possible values are
      #     "error", "replace", and "keep".
      #
      attr_reader :collisions

      ##
      # @return [Hash] the hash representation
      #
      def to_h
        {
          "name" => step_name,
          "dest" => dest,
          "source_path" => source_path,
          "dest_path" => dest_path,
          "collisions" => collisions,
        }
      end
    end

    ##
    # Configuration of output info for a step.
    # An output automatically copies files from the repo directory to this
    # step's output where they can be imported by another step.
    #
    class OutputSettings
      ##
      # @private
      # Construct output settings
      #
      # @param info [Hash,String] Config data
      #
      def initialize(info, errors, containing_step_name)
        @source = @source_path = @dest_path = nil
        case info
        when ::String
          @source_path = info
          @source = "component"
        when ::Hash
          @source = info.delete("source") || "component"
          @source_path = info.delete("source_path")
          @dest_path = info.delete("dest_path")
          @collisions = info.delete("collisions") || "error"
          info.each_key do |key|
            errors << "Unknown key #{key.inspect} in output for step #{containing_step_name.inspect}"
          end
        end
      end

      ##
      # @return [String] Where to copy data from. Possible values are
      #     "component", "repo_root", and "temp".
      #
      attr_reader :source

      ##
      # @return [String,nil] Path to copy from, relative to the source. Can be
      #     a file or a directory. If nil, copy everything in the source.
      #
      attr_reader :source_path

      ##
      # @return [String,nil] Path in the step's output to copy to.
      #     If nil, uses the source path.
      #
      attr_reader :dest_path

      ##
      # @return [String] What to do if a collision occurs. Possible values are
      #     "error", "replace", and "keep".
      #
      attr_reader :collisions

      ##
      # @return [Hash] the hash representation
      #
      def to_h
        {
          "source" => source,
          "source_path" => source_path,
          "dest_path" => dest_path,
          "collisions" => collisions,
        }
      end
    end

    ##
    # @private
    # Configuration of a step
    #
    class StepSettings
      ##
      # Create a StepSettings
      #
      def initialize(info, errors)
        from_h(info.dup, errors)
      end

      ##
      # @return [String] Name of this step
      #
      attr_reader :name

      ##
      # @return [String] Type of step
      #
      attr_reader :type

      ##
      # @return [boolean] Whether this step is explicitly requested
      #
      def requested?
        @requested
      end

      ##
      # @return [Array<InputSettings>] Inputs for this step
      #
      attr_reader :inputs

      ##
      # @return [Array<OutputSettings>] Extra outputs for this step
      #
      attr_reader :outputs

      ##
      # @return [Hash{String=>Object}] Options for this step
      #
      attr_reader :options

      ##
      # @return [Hash] the hash representation
      #
      def to_h
        {
          "name" => name,
          "type" => type,
          "run" => requested?,
          "inputs" => inputs.map(&:to_h),
          "outputs" => outputs.map(&:to_h),
        }.merge(RepoSettings.deep_copy(options))
      end

      ##
      # Make a deep copy
      #
      # @return [StepSettings] A deep copy
      #
      def deep_copy
        StepSettings.new(to_h, [])
      end

      ##
      # @private
      # Initialize the step from the given hash.
      # The hash will be deconstructed in place.
      #
      def from_h(info, errors)
        @type = info.delete("type") || info["name"] || "noop"
        @name = info.delete("name") || "_anon_#{@type}_#{object_id}"
        @requested = info.delete("run") ? true : false
        @inputs = Array(info.delete("inputs")).map do |input_info|
          InputSettings.new(input_info, errors, @name)
        end
        @outputs = Array(info.delete("outputs")).map do |output_info|
          OutputSettings.new(output_info, errors, @name)
        end
        @options = info
      end
    end

    ##
    # Full repo configuration
    #
    class RepoSettings
      ##
      # Load repo settings from the current environment.
      #
      # @param environment_utils [Toys::Release::EnvrionmentUtils]
      # @return [Toys::Release::RepoSettings]
      #
      def self.load_from_environment(environment_utils)
        file_path = environment_utils.tool_context.find_data("releases.yml")
        environment_utils.error("Unable to find releases.yml data file") unless file_path
        info = ::YAML.load_file(file_path)
        settings = RepoSettings.new(info)
        warnings = settings.warnings
        environment_utils.warning("Warnings while loading releases.yml", *warnings) unless warnings.empty?
        errors = settings.errors
        environment_utils.error("Errors while loading releases.yml", *errors) unless errors.empty?
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
      # @private
      # Create a repo configuration object.
      #
      # @param info [Hash] Configuration hash read from JSON.
      #
      def initialize(info)
        @warnings = []
        @errors = []
        read_global_info(info)
        read_required_checks_info(info)
        read_label_info(info)
        read_default_commit_tag_info(info)
        read_default_step_info(info)
        read_component_info(info)
        read_coordination_info(info)
        check_global_problems(info)
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
      # @return [Array<Array<String>>] An array of groups of component names
      #     whose releases should be coordinated.
      #
      attr_reader :coordination_groups

      ##
      # @return [Regexp,nil] A regular expression identifying all the GitHub
      #     checks that must pass before a release will take place, or nil to
      #     ignore GitHub checks
      #
      attr_reader :required_checks_regexp

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
      # @return [boolean] Whether commits update existing release requests
      #
      attr_reader :update_existing_requests

      ##
      # @return [Array<CommitTagSettings>] The conventional commit types
      #     recognized as release-triggering, along with information on the
      #     change they map to.
      #
      attr_reader :commit_tags

      ##
      # Get the build step pipeline
      #
      # @return [Array<StepSettings>] Step pipeline
      #
      attr_reader :steps

      ##
      # What to do with issue number suffixes in commit messages.
      #
      # @return [:plain,:link,:delete]
      #
      attr_reader :issue_number_suffix_handling

      ##
      # @return [String] Header for breaking changes in a changelog
      #
      attr_reader :breaking_change_header

      ##
      # @return [String] Header for dependency updates in a changelog
      #
      attr_reader :update_dependency_header

      ##
      # @return [String] Notice displayed in the changelog when there are
      #     otherwise no significant updates in the release
      #
      attr_reader :no_significant_updates_notice

      ##
      # @return [String] The bullet character used in changelog entries
      #
      attr_reader :changelog_bullet

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
      # Look up the settings for the given named tag.
      #
      # @param tag [String] Conventional commit tag to look up
      # @return [CommitTagSettings] The commit tag settings for the given tag
      #
      def commit_tag_named(tag)
        commit_tags.find { |elem| elem.tag == tag } || CommitTagSettings.empty(tag)
      end

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

      # @private
      def read_steps(info)
        Array(info).map { |step_info| StepSettings.new(step_info, @errors) }
      end

      # @private
      def modify_steps(steps, modifications) # rubocop:disable Metrics/MethodLength
        unless modifications.is_a?(::Array)
          @errors << "modify_steps expected an array of modification dictionaries"
          return steps
        end
        modifications.each do |mod_data|
          mod_name = mod_data.delete("name")
          mod_type = mod_data.delete("type")
          count = 0
          steps.each do |step|
            next if (mod_name && step.name != mod_name) || (mod_type && step.type != mod_type)
            count += 1
            modified_info = step.to_h
            mod_data.each do |key, value|
              if value.nil?
                modified_info.delete(key)
              else
                modified_info[key] = value
              end
            end
            step.from_h(modified_info, @errors)
          end
          if count.zero?
            @errors << "Unable to find step to modify for name=#{mod_name.inspect} and type=#{mod_type.inspect}."
          end
        end
        steps
      end

      # @private
      def prepend_steps(steps, info)
        before = []
        insert = []
        after = steps
        case info
        when ::Hash
          if (before_name = info["before"])
            before_index = steps.find_index { |step| step.name == before_name }
            if before_index
              before = steps[...before_index]
              after = steps[before_index..]
            else
              @errors << "Unable to find step named #{before_name} in prepend_steps.before"
            end
          end
          if (steps_info = info["steps"]).is_a?(::Array)
            insert = read_steps(steps_info)
          else
            @errors << "steps expected in prepend_steps"
          end
        when ::Array
          insert = read_steps(info)
        else
          @errors << "prepend_steps expected a hash or array"
        end
        before + insert + after
      end

      # @private
      def append_steps(steps, info)
        before = steps
        insert = []
        after = []
        case info
        when ::Hash
          if (after_name = info["after"])
            after_index = steps.find_index { |step| step.name == after_name }
            if after_index
              before = steps[..after_index]
              after = steps[(after_index + 1)..]
            else
              @errors << "Unable to find step named #{after_name} in append_steps.after"
            end
          end
          if (steps_info = info["steps"]).is_a?(::Array)
            insert = read_steps(steps_info)
          else
            @errors << "steps expected in append_steps"
          end
        when ::Array
          insert = read_steps(info)
        else
          @errors << "append_steps expected a hash or array"
        end
        before + insert + after
      end

      # @private
      def delete_steps(steps, info)
        if info.is_a?(::Array)
          info.each do |del_name|
            index = steps.find_index { |step| step.name == del_name }
            if index
              steps.delete_at(index)
            else
              @errors << "Unable to find step named #{del_name} to delete."
            end
          end
        else
          @errors << "delete_steps expected an array of names"
        end
        steps
      end

      # @private
      def read_commit_tags(info)
        Array(info).map { |tag_info| CommitTagSettings.new(tag_info, @errors) }
      end

      # @private
      def read_issue_number_suffix_handling(info, default)
        value = info.delete("issue_number_suffix_handling")
        return default if value.nil?
        processed_value = value.to_s.downcase
        if ["plain", "link", "delete"].include?(processed_value)
          processed_value.to_sym
        else
          message = "Unrecognized issue_number_suffix_handling setting: #{value.inspect}. " \
            "Expected \"plain\", \"link\", or \"delete\"."
          @errors << message
          default
        end
      end

      private

      DEFAULT_MAIN_BRAMCH = "main"
      private_constant :DEFAULT_MAIN_BRAMCH

      DEFAULT_COMMIT_TAGS_YAML = <<~STRING
        - tag: feat
          semver: minor
          header: ADDED
        - tag: fix
          semver: patch
          header: FIXED
        - tag: docs
          semver: patch
      STRING
      private_constant :DEFAULT_COMMIT_TAGS_YAML

      DEFAULT_STEPS_YAML = <<~STRING
        - name: bundle
        - name: build_gem
        - name: build_yard
        - name: release_github
        - name: release_gem
          source: build_gem
        - name: push_gh_pages
          source: build_yard
      STRING
      private_constant :DEFAULT_STEPS_YAML

      DEFAULT_ISSUE_NUMBER_SUFFIX_HANDLING = :plain
      private_constant :DEFAULT_ISSUE_NUMBER_SUFFIX_HANDLING

      DEFAULT_BREAKING_CHANGE_HEADER = "BREAKING CHANGE"
      private_constant :DEFAULT_BREAKING_CHANGE_HEADER

      DEFAULT_UPDATE_DEPENDENCY_HEADER = "DEPENDENCY"
      private_constant :DEFAULT_UPDATE_DEPENDENCY_HEADER

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

      DEFAULT_CHANGELOG_BULLET = "*"
      private_constant :DEFAULT_CHANGELOG_BULLET

      def read_global_info(info)
        @main_branch = info.delete("main_branch") || DEFAULT_MAIN_BRAMCH
        @repo_path = info.delete("repo")
        @signoff_commits = info.delete("signoff_commits") ? true : false
        @gh_pages_enabled = info.delete("gh_pages_enabled") ? true : false
        @enable_release_automation = info.delete("enable_release_automation") != false
        @update_existing_requests = info.delete("update_existing_requests") ? true : false
        @release_branch_prefix = info.delete("release_branch_prefix") || "release"
        @git_user_name = info.delete("git_user_name")
        @git_user_email = info.delete("git_user_email")
      end

      def read_required_checks_info(info)
        required_checks = info.delete("required_checks")
        @required_checks_regexp =
          case required_checks
          when false, nil
            nil
          when true
            //
          else
            ::Regexp.new(required_checks.to_s)
          end
        @required_checks_timeout = info.delete("required_checks_timeout") || 900
      end

      def read_label_info(info)
        @release_pending_label = info.delete("release_pending_label") || DEFAULT_RELEASE_PENDING_LABEL
        @release_error_label = info.delete("release_error_label") || DEFAULT_RELEASE_ERROR_LABEL
        @release_aborted_label = info.delete("release_aborted_label") || DEFAULT_RELEASE_ABORTED_LABEL
        @release_complete_label = info.delete("release_complete_label") || DEFAULT_RELEASE_COMPLETE_LABEL
      end

      def read_default_commit_tag_info(info)
        @commit_tags = read_commit_tags(info.delete("commit_tags") || ::YAML.load(DEFAULT_COMMIT_TAGS_YAML))
        @breaking_change_header = info.delete("breaking_change_header") || DEFAULT_BREAKING_CHANGE_HEADER
        @update_dependency_header = info.delete("update_dependency_header") || DEFAULT_UPDATE_DEPENDENCY_HEADER
        @no_significant_updates_notice =
          info.delete("no_significant_updates_notice") || DEFAULT_NO_SIGNIFICANT_UPDATES_NOTICE
        @issue_number_suffix_handling = read_issue_number_suffix_handling(info, DEFAULT_ISSUE_NUMBER_SUFFIX_HANDLING)
        @changelog_bullet = info.delete("changelog_bullet") || DEFAULT_CHANGELOG_BULLET
        unless ["*", "-"].include?(@changelog_bullet)
          @errors << "Unrecognized changelog_bullet setting: #{@changelog_bullet.inspect}. Expected \"*\" or \"-\"."
          @changelog_bullet = DEFAULT_CHANGELOG_BULLET
        end
      end

      def read_default_step_info(info)
        @steps = read_steps(info.delete("steps") || ::YAML.load(DEFAULT_STEPS_YAML))
        @steps = modify_steps(@steps, info.delete("modify_steps") || [])
        @steps = prepend_steps(@steps, info.delete("prepend_steps") || [])
        @steps = append_steps(@steps, info.delete("append_steps") || [])
        @steps = delete_steps(@steps, info.delete("delete_steps") || [])
      end

      def read_component_info(info)
        @components = {}
        component_info_array = Array(info.delete("components")) + Array(info.delete("gems"))
        @has_multiple_components = component_info_array.size > 1
        component_info_array.each do |component_info|
          component = ComponentSettings.new(self, component_info, @has_multiple_components)
          if component.name.empty?
            @errors << "A component is missing a name"
          elsif @components[component.name]
            @errors << "Duplicate component #{component.name.inspect}"
          else
            @components[component.name] = component
            if component.version_constant
              @warnings << "Found deprecated version_constant setting in component #{component.name.inspect}"
            end
          end
        end
        @errors << "No components found" if @components.empty?
      end

      def read_coordination_info(info)
        @coordination_groups = Array(info.delete("coordination_groups"))
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
        if info.delete("coordinate_versions") && @coordination_groups.empty?
          @coordination_groups = [@components.keys]
        end
      end

      def check_global_problems(info)
        info.each_key do |key|
          @errors << "Unknown top level key #{key.inspect} in releases.yml"
        end
        @errors << 'Required key "repo" missing from releases.yml' unless @repo_path
        @errors << 'Required key "git_user_name" missing from releases.yml' unless @git_user_name
        @errors << 'Required key "git_user_email" missing from releases.yml' unless @git_user_email
        @coordination_groups.each do |group|
          next unless group.size > 1
          group.each do |component_name|
            component = @components[component_name]
            if component.update_dependencies
              @errors << "Component #{component_name} cannot be in a coordination group and have update_dependencies"
            end
          end
        end
        # TODO: Ensure there aren't transitive update_dependencies relationships
      end
    end
  end
end
