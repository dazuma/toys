# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "toys/utils/exec"
require "toys/utils/xdg"

module Toys
  module Utils
    ##
    # This object provides cached access to remote git data. Given a remote
    # repository, a path, and a commit, it makes the files availble in the
    # local filesystem. Access is cached, so repeated requests do not hit the
    # remote repository again.
    #
    # This class is used by the Loader to load tools from git. Tools can also
    # use the `:git_cache` mixin for direct access to this class.
    #
    class GitCache
      ##
      # GitCache encountered a failure
      #
      class Error < ::StandardError
        ##
        # Create a GitCache::Error.
        #
        # @param message [String] The error message
        # @param result [Toys::Utils::Exec::Result] The result of a git
        #     command execution, or `nil` if this error was not due to a git
        #     command error.
        #
        def initialize(message, result)
          super(message)
          @exec_result = result
        end

        ##
        # @return [Toys::Utils::Exec::Result] The result of a git command
        #     execution, or `nil` if this error was not due to a git command
        #     error.
        #
        attr_reader :exec_result
      end

      # @private
      class RepoInfo
        # @private
        def initialize(io, remote, timestamp)
          @data = ::JSON.parse(io.read) rescue {} # rubocop:disable Style/RescueModifier
          @data["remote"] = remote
          @data["refs"] ||= {}
          @data["sources"] ||= {}
          @modified = false
          @timestamp = timestamp
        end

        # @private
        def modified?
          @modified
        end

        # @private
        def dump(io)
          ::JSON.dump(@data, io)
        end

        # @private
        def ref_stale?(ref, age)
          ref_info = @data["refs"][ref]
          last_updated = ref_info ? ref_info.fetch("updated", 0) : 0
          @timestamp >= last_updated + age
        end

        # @private
        def update_ref!(ref)
          (@data["refs"][ref] ||= {})["updated"] = @timestamp
          @modified = true
        end

        # @private
        def access_ref!(ref, sha)
          ref_info = @data["refs"][ref] ||= {}
          ref_info["sha"] = sha
          ref_info["accessed"] = @timestamp
          @modified = true
        end

        # @private
        def access_source!(sha, path)
          ((@data["sources"][sha] ||= {})[path] ||= {})["accessed"] = @timestamp
          @modified = true
        end
      end

      ##
      # Access a git cache.
      #
      # @param cache_dir [String] The path to the cache directory. Defaults to
      #     a specific directory in the user's XDG cache.
      #
      def initialize(cache_dir: nil)
        @cache_dir = ::File.expand_path(cache_dir || default_cache_dir)
        @exec = Utils::Exec.new(out: :capture, err: :capture)
      end

      ##
      # Find the given git-based files from the git cache, loading from the
      # remote repo if necessary.
      #
      # @param remote [String] The URL of the git repo. Required.
      # @param path [String] The path to the file or directory within the repo.
      #     Optional. Defaults to the entire repo.
      # @param commit [String] The commit reference, which may be a SHA or any
      #     git ref such as a branch or tag. Optional. Defaults to `HEAD`.
      # @param update [Boolean,Integer] Whether to update of non-SHA commit
      #     references if they were previously loaded. This is useful, for
      #     example, if the commit is `HEAD` or a branch name. Pass `true` or
      #     `false` to specify whether to update, or an integer to update if
      #     last update was done at least that many seconds ago. Default is
      #     `false`.
      #
      # @return [String] The full path to the cached files.
      #
      def find(remote, path: nil, commit: nil, update: false, timestamp: nil)
        path ||= ""
        commit ||= "HEAD"
        timestamp ||= ::Time.now.to_i
        dir = ensure_dir(remote)
        lock_repo(dir, remote, timestamp) do |repo_info|
          ensure_repo(dir, remote)
          sha = ensure_commit(dir, commit, repo_info, update)
          ensure_source(dir, sha, path.to_s, repo_info)
        end
      end

      ##
      # The cache directory.
      #
      # @return [String]
      #
      attr_reader :cache_dir

      # @private Used for testing
      def repo_dir_for(remote)
        ::File.join(@cache_dir, remote_dir_name(remote), "repo")
      end

      private

      def remote_dir_name(remote)
        ::Digest::MD5.hexdigest(remote)
      end

      def source_name(sha, path)
        digest = ::Digest::MD5.hexdigest("#{sha}#{path}")
        "#{digest}#{::File.extname(path)}"
      end

      def repo_dir_name
        "repo"
      end

      def default_cache_dir
        ::File.join(XDG.new.cache_home, "toys", "git")
      end

      def git(dir, cmd, error_message: nil)
        result = @exec.exec(["git"] + cmd, chdir: dir)
        if result.failed?
          raise GitCache::Error.new("Could not run git command line", result)
        end
        if block_given?
          yield result
        elsif result.error? && error_message
          raise GitCache::Error.new(error_message, result)
        else
          result
        end
      end

      def ensure_dir(remote)
        dir = ::File.join(@cache_dir, remote_dir_name(remote))
        ::FileUtils.mkdir_p(dir)
        dir
      end

      def lock_repo(dir, remote, timestamp)
        lock_path = ::File.join(dir, "repo.lock")
        ::File.open(lock_path, ::File::RDWR | ::File::CREAT) do |file|
          file.flock(::File::LOCK_EX)
          repo_info = RepoInfo.new(file, remote, timestamp)
          begin
            yield repo_info
          ensure
            if repo_info.modified?
              file.rewind
              file.truncate(0)
              repo_info.dump(file)
            end
          end
        end
      end

      def ensure_repo(dir, remote)
        repo_dir = ::File.join(dir, repo_dir_name)
        ::FileUtils.mkdir_p(repo_dir)
        result = git(repo_dir, ["remote", "get-url", "origin"])
        unless result.success? && result.captured_out.strip == remote
          ::FileUtils.rm_rf(repo_dir)
          ::FileUtils.mkdir_p(repo_dir)
          git(repo_dir, ["init"],
              error_message: "Unable to initialize git repository")
          git(repo_dir, ["remote", "add", "origin", remote],
              error_message: "Unable to add git remote")
        end
      end

      def ensure_commit(dir, commit, repo_info, update = false)
        local_commit = "toys-git-cache/#{commit}"
        repo_dir = ::File.join(dir, repo_dir_name)
        is_sha = commit =~ /^[0-9a-f]{40}$/
        if update.is_a?(::Numeric) && !is_sha
          update = repo_info.ref_stale?(commit, update)
        end
        if update && !is_sha || !commit_exists?(repo_dir, local_commit)
          git(repo_dir, ["fetch", "--depth=1", "--force", "origin", "#{commit}:#{local_commit}"],
              error_message: "Unable to to fetch commit: #{commit}")
          repo_info.update_ref!(commit)
        end
        result = git(repo_dir, ["rev-parse", local_commit],
                     error_message: "Unable to retrieve commit: #{local_commit}")
        sha = result.captured_out.strip
        repo_info.access_ref!(commit, sha)
        sha
      end

      def commit_exists?(repo_dir, commit)
        result = git(repo_dir, ["cat-file", "-t", commit])
        result.success? && result.captured_out.strip == "commit"
      end

      def ensure_source(dir, sha, path, repo_info)
        source_path = ::File.join(dir, source_name(sha, path))
        unless ::File.exist?(source_path)
          repo_dir = ::File.join(dir, repo_dir_name)
          git(repo_dir, ["checkout", sha])
          from_path = ::File.join(repo_dir, path)
          ::FileUtils.cp_r(from_path, source_path)
        end
        repo_info.access_source!(sha, path)
        source_path
      end
    end
  end
end
