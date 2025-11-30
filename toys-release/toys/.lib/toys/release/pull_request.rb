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
      # Perform various updates to a pull request
      #
      # @param labels [String,Array<String>,nil] One or more release-related
      #     labels that should be applied. All existing release-related labels
      #     are replaced with this list. Optional; no label updates are applied
      #     if not present.
      # @param state [String,nil] New pull request state. Optional; the state is
      #     not modified if not present.
      # @return [self]
      #
      def update(labels: nil, state: nil)
        body = {}
        body[:state] = state if state && self.state != state
        if labels
          labels = Array(labels)
          release_labels, other_labels = self.labels.partition do |label|
            repository.release_related_label?(label)
          end
          body[:labels] = other_labels + labels unless release_labels.sort == labels.sort
        end
        unless body.empty?
          cmd = ["gh", "api", "-XPATCH", "repos/#{repository.settings.repo_path}/issues/#{number}",
                 "--input", "-", "-H", "Accept: application/vnd.github.v3+json"]
          repository.utils.exec(cmd, in: [:string, ::JSON.dump(body)], out: :null, e: true)
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
        cmd = ["gh", "api", "repos/#{repository.settings.repo_path}/issues/#{number}/comments",
               "--input", "-", "-H", "Accept: application/vnd.github.v3+json"]
        repository.utils.exec(cmd, in: [:string, ::JSON.dump(body: message)], out: :null, e: true)
        self
      end
    end
  end
end
