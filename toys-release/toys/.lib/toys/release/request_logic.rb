# frozen_string_literal: true

require "json"

module Toys
  module Release
    ##
    # Miscellaneous logic related to release requests.
    #
    class RequestLogic
      ##
      # Construct a RequestLogic
      #
      # @param repository [Toys::Release::Repository]
      # @param request_spec [Toys::Release::RequestSpec]
      # @param target_branch [String] Optional target branch. Defaults to the
      #     current branch.
      #
      def initialize(repository, request_spec, target_branch: nil)
        @repository = repository
        @settings = repository.settings
        @utils = repository.utils
        @request_spec = request_spec
        @target_branch = target_branch || @repository.current_branch
      end

      ##
      # Perform component verification, including:
      #
      # * That there is at least one component to release in the request spec
      # * That each component has not already released the specified version
      #
      def verify_component_status
        if @request_spec.empty?
          @utils.error("No components to release.")
        end
        @utils.accumulate_errors("One or more components was in an inconsistent state") do
          @request_spec.resolved_components.each do |component_spec|
            component = @repository.component_named(component_spec.component_name)
            changelog_version = component.changelog_file.current_version
            if changelog_version && changelog_version >= component_spec.version
              @utils.error("Cannot add version #{component_spec.version} to #{component.name} changelog because the" \
                " existing changelog already contains version #{changelog_version}.")
            end
            constant_version = component.version_rb_file.current_version
            if constant_version >= component_spec.version
              @utils.error("Cannot change #{component.name} version constant to #{component_spec.version} because the" \
                " existing version constant is already at #{constant_version}.")
            end
          end
        end
        self
      end

      ##
      # Attempt to verify that no other release pull request is already open
      # for this release.
      #
      def verify_pull_request_status
        @utils.accumulate_errors("One or more existing release pull requests conflicts with this release") do
          cur_requested_components = @request_spec.serializable_requested_components
          existing_prs = @repository.find_release_prs(branch: @target_branch)
          existing_prs.each do |pr|
            if pr.requested_components&.keys&.any? { |comp_name| cur_requested_components.include?(comp_name) }
              @utils.error("An existing release pull request (##{pr.number}) overlaps with this one")
            end
          end
        end
        self
      end

      ##
      # @return [String] A commit title for this release
      #
      def build_commit_title
        if @request_spec.single_component?
          "release: Release #{format_component_info(@request_spec.resolved_components[0])}"
        else
          "release: Release #{@request_spec.resolved_components.size} items"
        end
      end

      ##
      # @return [String] Commit details for this release
      #
      def build_commit_details
        if @request_spec.single_component?
          ""
        else
          lines = @request_spec.resolved_components.map do |resolved_component|
            "* #{format_component_info(resolved_component)}"
          end
          lines.join("\n")
        end
      end

      ##
      # @return [String] Pull reqeust body for this release
      #
      def build_pr_body
        if @settings.enable_release_automation?
          build_automation_pr_body
        else
          build_standalone_pr_body
        end
      end

      ##
      # @return [Array<String>] The set of labels to apply to a pull request
      #
      def determine_pr_labels
        return unless @settings.enable_release_automation?
        [@settings.release_pending_label]
      end

      ##
      # Go through and update changelog and version files for each component.
      #
      def change_files
        @request_spec.resolved_components.each do |resolved_component|
          component = @repository.component_named(resolved_component.component_name)
          component.changelog_file.append(resolved_component.change_set, resolved_component.version)
          component.version_rb_file.update_version(resolved_component.version)
        end
      end

      ##
      # Update an existing pull request to match the request spec
      #
      def update_existing_pr(pull)
        release_branch = pull.head_ref
        @repository.create_branch(release_branch)
        change_files
        commit_title = build_commit_title
        @repository.git_commit(commit_title,
                               commit_details: build_commit_details,
                               signoff: @repository.settings.signoff_commits?)
        @utils.exec(["git", "push", "-f", "origin", release_branch])
        pull.update(body: build_pr_body, title: commit_title)
      end

      private

      def format_component_info(resolved_component, bold: false)
        last_release = resolved_component.last_version ? "was #{resolved_component.last_version}" : "initial release"
        decor = bold ? "**" : ""
        "#{decor}#{resolved_component.component_name} #{resolved_component.version}#{decor} (#{last_release})"
      end

      def build_automation_pr_body
        <<~STR
          #{build_pr_body_header}

           *  To confirm this release, merge this pull request, ensuring the \
          #{@settings.release_pending_label.inspect} label is set. The release \
          script will trigger automatically on merge.
           *  To abort this release, close this pull request without merging.

          #{build_pr_body_changes}

          ----

          #{build_pr_body_metadata}
        STR
      end

      def build_standalone_pr_body
        <<~STR
          #{build_pr_body_header}

          You can run the `release perform` script once these changes are merged.

          #{build_pr_body_changes}

          ----

          #{build_pr_body_metadata}
        STR
      end

      def build_pr_body_header
        lines = [
          "This pull request prepares new releases for the following components:",
          "",
        ]
        @request_spec.resolved_components.each do |resolved_component|
          lines << " *  #{format_component_info(resolved_component, bold: true)}"
        end
        lines << ""
        lines <<
          "For each releasable component, this pull request modifies the" \
            " version and provides an initial changelog entry based on" \
            " [conventional commit](https://conventionalcommits.org) messages." \
            " You can edit these changes before merging, to release a different" \
            " version or to alter the changelog text."
        lines.join("\n")
      end

      def build_pr_body_changes
        lines = ["The generated changelog entries have been copied below:"]
        @request_spec.resolved_components.each do |resolved_component|
          lines << ""
          lines << "----"
          lines << ""
          lines << "## #{resolved_component.component_name}"
          lines << ""
          resolved_component.change_set.change_groups.each do |group|
            lines.concat(group.prefixed_changes.map { |line| " *  #{line}" })
          end
        end
        lines.join("\n")
      end

      def build_pr_body_metadata
        metadata = {
          "requested_components" => @request_spec.serializable_requested_components,
          "request_sha" => @repository.current_sha(@target_branch),
        }
        metadata_json = ::JSON.pretty_generate(metadata)
        "```\n# release_metadata DO NOT REMOVE OR MODIFY\n#{metadata_json}\n```"
      end
    end
  end
end
