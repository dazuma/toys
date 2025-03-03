# frozen_string_literal: true

module ToysReleaser
  ##
  # Miscellaneous logic related to release requests.
  #
  class RequestLogic
    def initialize(repository, request_spec)
      @repository = repository
      @settings = repository.settings
      @utils = repository.utils
      @request_spec = request_spec
    end

    def verify_unit_status
      @utils.accumulate_errors("One or more releasable units was in an inconsistent state") do
        if @request_spec.empty?
          @utils.error("No units to release.")
        end
        @request_spec.resolved_units.each do |unit_spec|
          unit = @repository.releasable_unit(unit_spec.unit_name)
          changelog_version = unit.changelog_file.current_version
          if changelog_version >= unit_spec.version
            @utils.error("Cannot add version #{unit_spec.version} to #{unit.name} changelog" \
              " because the existing changelog already contains version #{changelog_version}.")
          end
          constant_version = unit.version_rb_file.current_version
          if constant_version >= unit_spec.version
            @utils.error("Cannot change #{unit.name} version constant to #{unit_spec.version}" \
              " because the existing version constant is already at #{constant_version}.")
          end
        end
        # TODO: Look for existing release pull requests
      end
      self
    end

    def determine_release_branch
      if @request_spec.single_unit?
        @repository.release_branch_name(@request_spec.resolved_units[0].unit_name)
      else
        @repository.multi_release_branch_name
      end
    end

    def build_commit_title
      if @request_spec.single_unit?
        "release: Release #{format_unit_info(@request_spec.resolved_units[0])}"
      else
        "release: Release #{@request_spec.resolved_units.size} items"
      end
    end

    def build_commit_details
      if @request_spec.single_unit?
        ""
      else
        lines = @request_spec.resolved_units.map do |resolved_unit|
          "* #{format_unit_info(resolved_unit)}"
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
      @request_spec.resolved_units.each do |resolved_unit|
        unit = @repository.releasable_unit(resolved_unit.unit_name)
        unit.changelog_file.append(resolved_unit.change_set, resolved_unit.version)
        unit.version_rb_file.update_version(resolved_unit.version)
      end
    end

    private

    def format_unit_info(resolved_unit, bold: false)
      last_release = resolved_unit.last_version ? "was #{resolved_unit.last_version}" : "initial release"
      decor = bold ? "**" : ""
      "#{decor}#{resolved_unit.unit_name} #{resolved_unit.version}#{decor} (#{last_release})"
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
        "This pull request prepares new gem releases for the following gems:",
        "",
      ]
      @request_spec.resolved_units.each do |resolved_unit|
        lines << " *  #{format_unit_info(resolved_unit, bold: true)}"
      end
      lines << ""
      lines <<
        "For each gem, this pull request modifies the gem version and provides" \
          " an initial changelog entry based on" \
          " [conventional commit](https://conventionalcommits.org) messages." \
          " You can edit these changes before merging, to release a different" \
          " version or to alter the changelog text."
      lines.join("\n")
    end

    def build_pr_body_footer
      lines = ["The generated changelog entries have been copied below:"]
      @request_spec.resolved_units.each do |resolved_unit|
        lines << ""
        lines << "----"
        lines << ""
        lines << "## #{resolved_unit.unit_name}"
        lines << ""
        resolved_unit.change_set.change_groups.each do |group|
          lines.concat(group.prefixed_changes.map { |line| " *  #{line}" })
        end
      end
      lines.join("\n")
    end
  end
end
