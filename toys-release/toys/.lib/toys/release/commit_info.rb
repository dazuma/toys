# frozen_string_literal: true

module Toys
  module Release
    ##
    # Represents info about a commit
    #
    class CommitInfo
      ##
      # Create a new CommitInfo
      #
      # @param environment_utils [Toys::Release::EnvironmentUtils]
      # @param sha [String]
      #
      def initialize(environment_utils, sha, message: nil)
        @utils = environment_utils
        @sha = sha
        @message = message
        @parent_sha = nil
        @modified_paths = nil
      end

      ##
      # @return [String] The SHA of this commit
      #
      attr_reader :sha

      ##
      # @return [boolean] Whether this commit is valid.
      #
      def exist?
        !message.empty?
      end

      ##
      # @return [String] The commit message, or the empty string if this commit
      #     does not exist.
      #
      def message
        @message ||= begin
          git_cmd = ["git", "log", sha, "--max-count=1", "--format=%B"]
          result = @utils.exec(git_cmd, out: :capture, err: :null)
          result.success? ? result.captured_out.strip : ""
        end
      end

      ##
      # @return [String] The SHA of this commit's parent, for diffs, or the
      #     empty string if this commit does not exist.
      #
      def parent_sha
        @parent_sha ||=
          if exist?
            result = @utils.exec(["git", "rev-parse", "#{sha}^"], out: :capture, err: :null)
            if result.success?
              result.captured_out.strip
            else
              @utils.capture(["git", "hash-object", "-t", "tree", "--stdin"], e: true, in: :null).strip
            end
          else
            ""
          end
      end

      ##
      # @return [Array<String>] A list of paths modified by this commit, or the
      #     empty array if this commit does not exist.
      #
      def modified_paths
        @modified_paths ||=
          if exist?
            git_cmd = ["git", "diff", "--name-only", "#{parent_sha}..#{sha}"]
            @utils.capture(git_cmd, e: true).split("\n").sort
          else
            []
          end
      end
    end
  end
end
