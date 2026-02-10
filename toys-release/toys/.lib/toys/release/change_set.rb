# frozen_string_literal: true

require "toys/release/semver"

module Toys
  module Release
    ##
    # Represents a set of changes from commit messages.
    #
    # Organizes the change commit messages into groups, and computes the semver
    # release type.
    #
    class ChangeSet
      ##
      # Create a new ChangeSet
      #
      # @param repo_settings [RepoSettings] the repo settings
      # @param component_settings [ComponentSettings] the component settings
      #
      def initialize(repo_settings, component_settings)
        @commit_tags = component_settings.commit_tags
        @breaking_change_header = component_settings.breaking_change_header
        @no_significant_updates_notice = component_settings.no_significant_updates_notice
        @semver = Semver::NONE
        @change_groups = nil
        @inputs = []
        @significant_shas = nil
        @description_normalizer = create_description_normalizer(
          component_settings.issue_number_suffix_handling, repo_settings.repo_path
        )
      end

      ##
      # Add a commit.
      #
      # @param commit [Toys::Release::CommitInfo] The commit.
      #
      def add_commit(commit)
        raise "ChangeSet locked" if finished?
        lines = commit.message.split("\n")
        return if lines.empty?
        input = Input.new(commit.sha)
        lines.each { |line| analyze_line(line, input) }
        @inputs << input if input.significant?
        self
      end

      ##
      # Finish constructing a change set. After this method, new commit messages
      # cannot be added.
      #
      def finish # rubocop:disable Metrics/AbcSize
        raise "ChangeSet locked" if finished?
        @semver = Semver::NONE
        change_groups = {breaking: Group.new(@breaking_change_header)}
        @commit_tags.each do |tag_info|
          tag_info.all_headers.each { |header| change_groups[header] = Group.new(header) }
        end
        apply_reverts
        @inputs.each do |input|
          @semver = input.semver if input.semver > @semver
          input.changes.each do |(header, change)|
            change_groups.fetch(header, nil)&.add([change])
          end
          change_groups[:breaking].add(input.breaks)
        end
        @change_groups = change_groups.values.find_all { |group| !group.empty? }
        if @change_groups.empty? && @semver.significant?
          @change_groups << Group.new(nil).add(@no_significant_updates_notice)
        end
        @significant_shas = @inputs.map(&:sha)
        @inputs = nil
        self
      end

      ##
      # Force a non-empty changeset even if there are no significant updates.
      # May be called only on a finished changeset.
      #
      def force_release!
        raise "ChangeSet not finished" unless finished?
        if @change_groups.empty?
          @semver = Semver::PATCH
          @change_groups << Group.new(nil).add(@no_significant_updates_notice)
        end
        self
      end

      ##
      # @return [boolean] Whether this change set is finished.
      #
      def finished?
        @inputs.nil?
      end

      ##
      # @return [boolean] Whether this change set is empty. Valid only after
      #     the change set is finished.
      #
      def empty?
        @change_groups&.empty?
      end

      ##
      # @return [Array<String>] All significant SHAs. Valid only after the
      #     change set is finished.
      #
      attr_reader :significant_shas

      ##
      # @return [Integer] The semver change.
      #
      attr_reader :semver

      ##
      # @return [Array<Group>] An array of change groups, in order. Returns nil
      #     if the change set is not finished.
      #
      attr_reader :change_groups

      ##
      # Suggest a next version based on the changeset's changes.
      #
      # @param last [::Gem::Version,nil] The last released version, or nil if
      #     no releases have happened yet.
      # @return [::Gem::Version,nil] Suggested next version, or nil for none.
      #
      def suggested_version(last)
        raise "ChangeSet not finished" unless finished?
        return nil unless semver.significant?
        semver.bump(last)
      end

      ##
      # A group of changes with the same header.
      #
      # These changes should be rendered together in a changelog, either as a
      # list of changes under a heading, or as a list of changes, each preceded
      # by the header as a prefix.
      #
      class Group
        def initialize(header)
          @header = header
          @changes = []
          @prefixed_changes = nil
        end

        ##
        # @return [String] Header/prefix for changes in this group. May be nil
        #     for no header.
        #
        attr_reader :header

        ##
        # @return [Array<String>] Array of individual changes, in order.
        #
        attr_reader :changes

        ##
        # @return [Array<String>] Array of changes prefixed by the header.
        #
        def prefixed_changes
          @prefixed_changes ||= changes.map { |change| header ? "#{header}: #{change}" : change }
        end

        ##
        # @return [boolean] Whether this group is empty.
        #
        def empty?
          changes.empty?
        end

        # @private
        def add(chs)
          @changes.concat(Array(chs))
          self
        end

        # @private
        def to_s
          prefixed_changes.join("\n")
        end
      end

      # @private
      def to_s
        (["Semver: #{semver}"] + change_groups).join("\n")
      end

      private

      def analyze_line(line, input)
        match = /^(?<tag>[\w-]+|BREAKING CHANGE)(?:\((?<scope>[^()]+)\))?(?<bang>!?):\s+(?<content>.*)$/.match(line)
        return unless match
        case match[:tag]
        when /^BREAKING[\s_-]CHANGE$/
          description = @description_normalizer.call(match[:content])
          input.apply_breaking_change(description)
        when /^semver-change$/i
          input.apply_semver_change(match[:content].split.first)
        when /^revert-commit$/i
          input.add_revert(match[:content].split.first)
        else
          tag_info = @commit_tags.find { |tag| tag.tag == match[:tag] }
          description = @description_normalizer.call(match[:content])
          input.apply_commit(tag_info, match[:scope], match[:bang], description)
        end
      end

      def apply_reverts
        reverts = []
        @inputs.reverse_each do |input|
          next if reverts.any? { |revert_sha| input.sha.start_with?(revert_sha) }
          reverts += input.reverts
        end
        @inputs.delete_if { |input| reverts.any? { |revert_sha| input.sha.start_with?(revert_sha) } }
      end

      def create_description_normalizer(issue_number_suffix_handling, repo_path)
        proc do |description|
          description = description.strip
          match = /^([a-z])(.*)$/.match(description)
          description = match[1].upcase + match[2] if match
          unless issue_number_suffix_handling == :plain
            suffixes = []
            while (match = /^(.*\S)(\s*\(#\d+\))$/.match(description))
              suffixes << match[2]
              description = match[1]
            end
            if issue_number_suffix_handling == :link
              reconstruction = [description]
              until suffixes.empty?
                reconstruction << suffixes.pop.sub(/#(\d+)/, "[#\\1](https://github.com/#{repo_path}/pull/\\1)")
              end
              description = reconstruction.join
            end
          end
          description
        end
      end

      ##
      # @private
      # Analyzed commit info
      #
      class Input
        # @private
        def initialize(sha)
          @sha = sha
          @changes = []
          @breaks = []
          @semver = Semver::NONE
          @semver_locked = false
          @reverts = []
        end

        attr_reader :sha
        attr_reader :changes
        attr_reader :breaks
        attr_reader :semver
        attr_reader :semver_locked
        attr_reader :reverts

        # @private
        def significant?
          @semver.significant? || !reverts.empty? || !changes.empty? || !breaks.empty?
        end

        # @private
        def apply_breaking_change(description)
          @semver = Semver::MAJOR unless semver_locked
          @breaks << description
          self
        end

        # @private
        def apply_semver_change(value)
          semver = Semver.for_name(value)
          if semver
            @semver = semver
            @semver_locked = true
          end
          self
        end

        # @private
        def apply_commit(tag_info, scope, bang, description)
          if tag_info
            commit_header = tag_info.header(scope)
            commit_semver = tag_info.semver(scope)
            @changes << [commit_header, description] if commit_header
            @semver = commit_semver if !@semver_locked && (commit_semver > @semver)
          end
          if bang == "!"
            @semver = Semver::MAJOR unless @semver_locked
            @breaks << description
          end
          self
        end

        # @private
        def add_revert(sha)
          @reverts << sha
        end
      end
    end
  end
end
