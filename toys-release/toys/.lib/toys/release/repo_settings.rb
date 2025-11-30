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
      # @private
      # Create a CommitTagSettings from either a tag name string (which will
      # default to patch releases) or a hash with fields.
      #
      def initialize(input)
        @scopes = {}
        case input
        when ::String
          init_from_string(input)
        when ::Hash
          init_from_hash(input)
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

      ##
      # Make specified modifications to the settings
      #
      # @param input [Hash] Modifications
      #
      def modify(input)
        if input.key?("header") || input.key?("label")
          @header = input.fetch("header", input["label"]) || :hidden
        end
        if input.key?("semver")
          @semver = load_semver(input["semver"])
        end
        input["scopes"]&.each do |key, value|
          if value.nil?
            @scopes.delete(key)
          else
            scope_info = load_scope(key, value)
            @scopes[key] = scope_info if scope_info
          end
        end
      end

      private

      def init_from_string(input)
        @tag = input
        @header = @tag.upcase
        @semver = Semver::PATCH
      end

      def init_from_hash(input)
        if input.size == 1
          key = input.keys.first
          value = input.values.first
          if value.is_a?(::Hash)
            @tag = key
            load_hash(value)
          elsif key == "tag"
            @tag = value
            @header = @tag.upcase
            @semver = Semver::PATCH
          else
            @tag = key
            @header = @tag.upcase
            @semver = load_semver(value)
          end
        else
          @tag = input["tag"]
          raise "tag missing in #{input}" unless @tag
          load_hash(input)
        end
      end

      def load_hash(input)
        @header = input.fetch("header", input.fetch("label", @tag.upcase)) || :hidden
        @semver = load_semver(input.fetch("semver", "patch"))
        input["scopes"]&.each do |key, value|
          scope_info = load_scope(key, value)
          @scopes[key] = scope_info if scope_info
        end
      end

      def load_scope(key, value)
        case value
        when ::String
          semver = load_semver(value, key)
          ScopeInfo.new(semver, nil)
        when ::Hash
          semver = load_semver(value["semver"], key) if value.key?("semver")
          header = value.fetch("header", value.fetch("label", :inherit)) || :hidden
          header = nil if header == :inherit
          ScopeInfo.new(semver, header)
        end
      end

      def load_semver(value, scope = nil)
        result = Semver.for_name(value || "none")
        unless result
          tag = scope ? "#{@tag}(#{scope})" : @tag
          raise "Unknown semver: #{value} for tag #{tag}"
        end
        result
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
      # @param info [Hash] Nested hash input
      # @param has_multiple_components [boolean] Whether there are other
      #     components
      #
      def initialize(repo_settings, info, has_multiple_components)
        @name = info["name"]
        @type = info["type"] || "component"

        read_path_info(info, has_multiple_components)
        read_file_modification_info(info)
        read_gh_pages_info(repo_settings, info, has_multiple_components)
        read_steps_info(repo_settings, info)
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
      # @return [Array<StepSettings>] A list of build steps.
      #
      attr_reader :steps

      ##
      # @return [StepSettings,nil] The unique step with the given name
      #
      def step_named(name)
        steps.find { |t| t.name == name }
      end

      private

      def read_path_info(info, has_multiple_components)
        @directory = info["directory"] || (has_multiple_components ? name : ".")
        @include_globs = Array(info["include_globs"])
        @exclude_globs = Array(info["exclude_globs"])
      end

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

      def read_steps_info(repo_settings, info)
        @steps = info["steps"] ? repo_settings.read_steps(info["steps"]) : repo_settings.default_steps(@type)
        @steps = repo_settings.modify_steps(@steps, info["modify_steps"] || [])
        @steps = repo_settings.prepend_steps(@steps, info["prepend_steps"] || [])
        @steps = repo_settings.append_steps(@steps, info["append_steps"] || [])
        @steps = repo_settings.delete_steps(@steps, info["delete_steps"] || [])
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
      def initialize(info)
        @step_name = @dest = @source_path = @dest_path = nil
        case info
        when ::String
          @step_name = info
          @dest = "component"
        when ::Hash
          @step_name = info["name"]
          @dest = info.fetch("dest", "component")
          @dest = "none" if @dest == false
          @source_path = info["source_path"]
          @dest_path = info["dest_path"]
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
      # @return [Hash] the hash representation
      #
      def to_h
        {
          "name" => step_name,
          "dest" => dest,
          "source_path" => source_path,
          "dest_path" => dest_path,
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
      def initialize(info)
        @source = @source_path = @dest_path = nil
        case info
        when ::String
          @source_path = info
          @source = "component"
        when ::Hash
          @source = info.fetch("source", "component")
          @source_path = info["source_path"]
          @dest_path = info["dest_path"]
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
      # @return [Hash] the hash representation
      #
      def to_h
        {
          "source" => source,
          "source_path" => source_path,
          "dest_path" => dest_path,
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
      def initialize(info)
        from_h(info.dup)
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
        StepSettings.new(to_h)
      end

      ##
      # @private
      # Initialize the step from the given hash.
      # The hash will be deconstructed in place.
      #
      def from_h(info)
        @type = info.delete("type") || info["name"] || "noop"
        @name = info.delete("name") || "_anon_#{@type}_#{object_id}"
        @requested = info.delete("run") ? true : false
        @inputs = Array(info.delete("inputs")).map { |input_info| InputSettings.new(input_info) }
        @outputs = Array(info.delete("outputs")).map { |output_info| OutputSettings.new(output_info) }
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
        @default_component_name = nil
        read_global_info(info)
        read_label_info(info)
        read_commit_tag_info(info)
        read_default_step_info(info)
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
      # Get the default step pipeline settings for a component type
      #
      # @param component_type [String] Type of component
      # @return [Array<StepSettings>] Step pipeline
      #
      def default_steps(component_type)
        (@default_steps[component_type] || @default_steps["component"]).map(&:deep_copy)
      end

      # @private
      def read_steps(info)
        info.map { |step_info| StepSettings.new(step_info) }
      end

      # @private
      def modify_steps(steps, modifications)
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
            step.from_h(modified_info)
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
        info.each do |del_name|
          index = steps.find_index { |step| step.name == del_name }
          if index
            steps.delete_at(index)
          else
            @errors << "Unable to find step named #{del_name} to delete."
          end
        end
        steps
      end

      private

      DEFAULT_MAIN_BRAMCH = "main"
      private_constant :DEFAULT_MAIN_BRAMCH

      DEFAULT_RELEASE_COMMIT_TAGS = ::YAML.load(<<~STRING) # rubocop:disable Security/YAMLLoad
        - tag: feat
          header: ADDED
          semver: minor
        - tag: fix
          header: FIXED
        - docs
      STRING
      private_constant :DEFAULT_RELEASE_COMMIT_TAGS

      DEFAULT_STEPS = ::YAML.load(<<~STRING) # rubocop:disable Security/YAMLLoad
        component:
          - name: release_github
        gem:
          - name: bundle
          - name: build_gem
          - name: build_yard
          - name: release_github
          - name: release_gem
            source: build_gem
          - name: push_gh_pages
            source: build_yard
      STRING
      private_constant :DEFAULT_STEPS

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
        @errors << "Repo key missing from releases.yml" unless @repo_path
      end

      def read_label_info(info)
        @release_pending_label = info["release_pending_label"] || DEFAULT_RELEASE_PENDING_LABEL
        @release_error_label = info["release_error_label"] || DEFAULT_RELEASE_ERROR_LABEL
        @release_aborted_label = info["release_aborted_label"] || DEFAULT_RELEASE_ABORTED_LABEL
        @release_complete_label = info["release_complete_label"] || DEFAULT_RELEASE_COMPLETE_LABEL
      end

      def read_commit_tag_info(info)
        @release_commit_tags = read_commit_tag_info_set(info["release_commit_tags"] || DEFAULT_RELEASE_COMMIT_TAGS)
        info["modify_release_commit_tags"]&.each do |tag, data|
          if data.nil?
            @release_commit_tags.delete(tag)
          elsif (tag_settings = @release_commit_tags[tag])
            tag_settings.modify(data)
          end
        end
        @release_commit_tags = read_commit_tag_info_set(info["prepend_release_commit_tags"]).merge(@release_commit_tags)
        @release_commit_tags.merge!(read_commit_tag_info_set(info["append_release_commit_tags"]))
        @breaking_change_header = info["breaking_change_header"] || DEFAULT_BREAKING_CHANGE_HEADER
        @no_significant_updates_notice = info["no_significant_updates_notice"] || DEFAULT_NO_SIGNIFICANT_UPDATES_NOTICE
      end

      def read_commit_tag_info_set(input)
        input.to_h do |value|
          settings = CommitTagSettings.new(value)
          [settings.tag, settings]
        end
      end

      def read_default_step_info(info) # rubocop:disable Metrics/AbcSize
        default_step_data = info["default_steps"] || DEFAULT_STEPS
        @default_steps = {}
        default_step_data.each do |key, data|
          @default_steps[key] = read_steps(data)
        end
        (info["modify_default_steps"] || {}).each do |key, data|
          @default_steps[key] = modify_steps(@default_steps[key], data)
        end
        (info["append_default_steps"] || {}).each do |key, data|
          @default_steps[key] = append_steps(@default_steps[key], data)
        end
        (info["prepend_default_steps"] || {}).each do |key, data|
          @default_steps[key] = prepend_steps(@default_steps[key], data)
        end
        (info["delete_default_steps"] || {}).each do |key, data|
          @default_steps[key] = delete_steps(@default_steps[key], data)
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
end
