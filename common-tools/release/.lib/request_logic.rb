# frozen_string_literal: true

module ToysReleaser
  ##
  # Miscellaneous logic related to release requests.
  #
  class RequestLogic
    def initialize(repository, request_spec, target_branch: nil)
      @repository = repository
      @settings = repository.settings
      @utils = repository.utils
      @request_spec = request_spec
      @target_branch = target_branch || @repository.current_branch
    end

    def verify_component_status
      @utils.accumulate_errors("One or more components was in an inconsistent state") do
        if @request_spec.empty?
          @utils.error("No components to release.")
        end
        @request_spec.resolved_components.each do |component_spec|
          component = @repository.component_named(component_spec.component_name)
          changelog_version = component.changelog_file.current_version
          if changelog_version >= component_spec.version
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

    def verify_pull_request_status
      @utils.accumulate_errors("One or more existing release pull requests conflicts with this release") do
        existing_prs = @repository.find_release_prs(branch: @target_branch)
        if @request_spec.single_component?
          component_name = @request_spec.resolved_components.first.component_name
          release_branch_name = @repository.release_branch_name(@target_branch, component_name)
          existing_prs.each do |pr|
            if pr.head_ref == release_branch_name
              @utils.error("A release pull request (##{pr.number}) is already open for #{component_name}")
            elsif pr.head_ref =~ %r{release/multi/\d{14}-\d{6}/#{@target_branch}}
              @utils.error("A release pull request (##{pr.number}) is already open for multiple components")
            end
          end
        else
          existing_prs.each do |pr|
            if pr.head_ref.end_with?("/#{@target_branch}")
              @utils.error("A release pull request (##{pr.number}) is already open")
            end
          end
        end
      end
      self
    end

    def determine_release_branch
      if @request_spec.single_component?
        @repository.release_branch_name(@target_branch, @request_spec.resolved_components[0].component_name)
      else
        @repository.multi_release_branch_name(@target_branch)
      end
    end

    def build_commit_title
      if @request_spec.single_component?
        "release: Release #{format_component_info(@request_spec.resolved_components[0])}"
      else
        "release: Release #{@request_spec.resolved_components.size} items"
      end
    end

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

    def build_pr_body
      if @settings.enable_release_automation?
        build_automation_pr_body
      else
        build_standalone_pr_body
      end
    end

    def determine_pr_labels
      return unless @settings.enable_release_automation?
      [@settings.release_pending_label]
    end

    def change_files
      @request_spec.resolved_components.each do |resolved_component|
        component = @repository.component_named(resolved_component.component_name)
        component.changelog_file.append(resolved_component.change_set, resolved_component.version)
        component.version_rb_file.update_version(resolved_component.version)
      end
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

        #{build_pr_body_footer}
      STR
    end

    def build_standalone_pr_body
      <<~STR
        #{build_pr_body_header}

        You can run the `release perform` script once these changes are merged.

        #{build_pr_body_footer}
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

    def build_pr_body_footer
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
  end
end
