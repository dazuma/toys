# frozen_string_literal: true

require "json"

module Toys
  module Release
    ##
    # Represents a release pull request
    #
    class PullRequest
      ##
      # Create a pull request object
      #
      # @param repository [Repository]
      # @param resource [Hash] The resource hash describing the pull request
      #
      def initialize(repository, resource)
        @repository = repository
        @resource = resource
      end

      ##
      # @return [Repository]
      #
      attr_reader :repository

      ##
      # @return [Hash] The resource hash describing the pull request
      #
      attr_reader :resource

      ##
      # @return [Integer] The pull request number
      #
      def number
        resource["number"].to_i
      end

      ##
      # @return [String] The pull request title
      #
      def title
        resource["title"]
      end

      ##
      # @return [String] The pull request state
      #
      def state
        resource["state"]
      end

      ##
      # @return [Array<String>] The current label names
      #
      def labels
        resource["labels"].map { |label_info| label_info["name"] }
      end

      ##
      # @return [String] The pull request URL
      #
      def url
        "https://github.com/#{repository.settings.repo_path}/pull/#{number}"
      end

      ##
      # @return [String] The SHA of the merge commit
      #
      def merge_commit_sha
        resource["merge_commit_sha"]
      end

      ##
      # @return [String] The SHA of the pull request head
      #
      def head_sha
        resource["head"]["sha"]
      end

      ##
      # @return [String] The SHA of the pull request base
      #
      def base_sha
        resource["base"]["sha"]
      end

      ##
      # @return [String] The ref of the pull request head
      #
      def head_ref
        resource["head"]["ref"]
      end

      ##
      # @return [String] The ref of the pull request base
      #
      def base_ref
        resource["base"]["ref"]
      end

      ##
      # @return [boolean] Whether the pull request has been merged
      #
      def merged?
        resource["merged_at"] ? true : false
      end

      ##
      # @return [String] The pull request description text
      #
      def description
        resource["body"]
      end

      ##
      # Attempt to parse metadata from the pull request description.
      #
      # @return [Hash,nil] The metadata hash, or nil if not found.
      #
      def release_metadata
        match = /```\n# release_metadata(?:\s[^\n]*)?\n(\{\n(?:[^\n]*\n)+\}\n)```\n/.match(description)
        ::JSON.parse(match[1]) rescue nil # rubocop:disable Style/RescueModifier
      end

      ##
      # Attempt to parse request arguments from the release metadata.
      #
      # @return [Array<String>,nil] The arguments, or nil if not found.
      #
      def request_arguments
        metadata = release_metadata
        metadata ? metadata["request_arguments"] : nil
      end

      ##
      # Perform various updates to a pull request
      #
      # @param labels [String,Array<String>,nil] One or more release-related
      #     labels that should be applied. All existing release-related labels
      #     are replaced with this list. Optional; if not present, no label
      #     updates are applied.
      # @param state [String,nil] New pull request state. Optional; if not
      #     present, the state is not modified.
      # @param title [String,nil] New pull request title. Optional; if not
      #     present, the title is not modified.
      # @param body [String,nil] New pull request body. Optional; if not
      #     present, the body is not modified.
      # @return [self]
      #
      def update(labels: nil, state: nil, title: nil, body: nil)
        content = {}
        content[:state] = state if state && self.state != state
        content[:body] = body if body
        content[:title] = title if title
        if labels
          labels = Array(labels)
          release_labels, other_labels = self.labels.partition do |label|
            repository.release_related_label?(label)
          end
          content[:labels] = other_labels + labels unless release_labels.sort == labels.sort
        end
        unless content.empty?
          cmd = [
            "gh", "api",
            "--method", "PATCH",
            "repos/#{repository.settings.repo_path}/issues/#{number}",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: 2022-11-28",
            "--input", "-"
          ]
          repository.utils.exec(cmd, in: [:string, ::JSON.dump(content)], out: :null, e: true)
        end
        self
      end

      ##
      # Add a comment to a pull request
      #
      # @param message [String] A comment to add to the pull request.
      # @return [self]
      #
      def add_comment(message)
        content = {body: message}
        cmd = [
          "gh", "api",
          "--method", "POST",
          "repos/#{repository.settings.repo_path}/issues/#{number}/comments",
          "-H", "Accept: application/vnd.github+json",
          "-H", "X-GitHub-Api-Version: 2022-11-28",
          "--input", "-"
        ]
        repository.utils.exec(cmd, in: [:string, ::JSON.dump(content)], out: :null, e: true)
        self
      end
    end
  end
end
