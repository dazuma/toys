# frozen_string_literal: true

module Toys
  module Utils
    ##
    # This object provides cached access to remote git data. Given a remote
    # repository, a path, and a commit, it makes the files availble in the
    # local filesystem. Access is cached, so repeated requests for the same
    # commit and path in the same repo do not hit the remote repository again.
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

      ##
      # Information about a remote git repository in the cache.
      #
      # This object is returned from {GitCache#repo_info}.
      #
      class RepoInfo
        include ::Comparable

        ##
        # The base directory of this git repository's cache entry. This
        # directory contains all cached data related to this repo. Deleting it
        # effectively removes the repo from the cache.
        #
        # @return [String]
        #
        attr_reader :base_dir

        ##
        # The git remote, usually a file system path or URL.
        #
        # @return [String]
        #
        attr_reader :remote

        ##
        # The last time any cached data from this repo was accessed, or `nil`
        # if the information is unavailable.
        #
        # @return [Time,nil]
        #
        attr_reader :last_accessed

        ##
        # A list of git refs (branches, tags, shas) that have been accessed
        # from this repo.
        #
        # @return [Array<RefInfo>]
        #
        attr_reader :refs

        ##
        # A list of shared source files and directories accessed for this repo.
        #
        # @return [Array<SourceInfo>]
        #
        attr_reader :sources

        ##
        # Convert this RepoInfo to a hash suitable for JSON output
        #
        # @return [Hash]
        #
        def to_h
          result = {
            "remote" => remote,
            "base_dir" => base_dir,
          }
          result["last_accessed"] = last_accessed.to_i if last_accessed
          result["refs"] = refs.map(&:to_h)
          result["sources"] = sources.map(&:to_h)
          result
        end

        ##
        # Comparison function
        #
        # @param other [RepoInfo]
        # @return [Integer]
        #
        def <=>(other)
          remote <=> other.remote
        end

        ##
        # @private
        #
        def initialize(base_dir, data)
          @base_dir = base_dir
          @remote = data["remote"]
          accessed = data["accessed"]
          @last_accessed = accessed ? ::Time.at(accessed).utc : nil
          @refs = (data["refs"] || {}).map { |ref, ref_data| RefInfo.new(ref, ref_data) }
          @sources = (data["sources"] || {}).flat_map do |sha, sha_data|
            sha_data.map do |path, path_data|
              SourceInfo.new(base_dir, sha, path, path_data)
            end
          end
          @refs.sort!
          @sources.sort!
        end
      end

      ##
      # Information about a git ref used in a cache.
      #
      class RefInfo
        include ::Comparable

        ##
        # The git ref
        #
        # @return [String]
        #
        attr_reader :ref

        ##
        # The git sha last associated with the ref
        #
        # @return [String]
        #
        attr_reader :sha

        ##
        # The timestamp when this ref was last accessed
        #
        # @return [Time]
        #
        attr_reader :last_accessed

        ##
        # The timestamp when this ref was last updated
        #
        # @return [Time]
        #
        attr_reader :last_updated

        ##
        # Convert this RefInfo to a hash suitable for JSON output
        #
        # @return [Hash]
        #
        def to_h
          result = {
            "ref" => ref,
            "sha" => sha,
          }
          result["last_accessed"] = last_accessed.to_i if last_accessed
          result["last_updated"] = last_updated.to_i if last_updated
          result
        end

        ##
        # Comparison function
        #
        # @param other [RefInfo]
        # @return [Integer]
        #
        def <=>(other)
          ref <=> other.ref
        end

        ##
        # @private
        #
        def initialize(ref, ref_data)
          @ref = ref
          @sha = ref_data["sha"]
          @last_accessed = ref_data["accessed"]
          @last_accessed = ::Time.at(@last_accessed).utc if @last_accessed
          @last_updated = ref_data["updated"]
          @last_updated = ::Time.at(@last_updated).utc if @last_updated
        end
      end

      ##
      # Information about shared source files provided from the cache.
      #
      class SourceInfo
        include ::Comparable

        ##
        # The git sha the source comes from
        #
        # @return [String]
        #
        attr_reader :sha

        ##
        # The path within the git repo
        #
        # @return [String]
        #
        attr_reader :git_path

        ##
        # The path to the source file or directory
        #
        # @return [String]
        #
        attr_reader :source

        ##
        # The timestamp when this ref was last accessed
        #
        # @return [Time]
        #
        attr_reader :last_accessed

        ##
        # Convert this SourceInfo to a hash suitable for JSON output
        #
        # @return [Hash]
        #
        def to_h
          result = {
            "sha" => sha,
            "git_path" => git_path,
            "source" => source,
          }
          result["last_accessed"] = last_accessed.to_i if last_accessed
          result
        end

        ##
        # Comparison function
        #
        # @param other [SourceInfo]
        # @return [Integer]
        #
        def <=>(other)
          result = sha <=> other.sha
          result.zero? ? git_path <=> other.git_path : result
        end

        ##
        # @private
        #
        def initialize(base_dir, sha, git_path, path_data)
          @sha = sha
          @git_path = git_path
          root_dir = ::File.join(base_dir, sha)
          @source = git_path == "." ? root_dir : ::File.join(root_dir, git_path)
          @last_accessed = path_data["accessed"]
          @last_accessed = @last_accessed ? ::Time.at(@last_accessed).utc : nil
        end
      end

      ##
      # Access a git cache.
      #
      # @param cache_dir [String] The path to the cache directory. Defaults to
      #     a specific directory in the user's XDG cache.
      #
      def initialize(cache_dir: nil)
        require "digest"
        require "fileutils"
        require "json"
        require "toys/compat"
        require "toys/utils/exec"
        @cache_dir = ::File.expand_path(cache_dir || default_cache_dir)
        @exec = Utils::Exec.new(out: :capture, err: :capture)
      end

      ##
      # The cache directory.
      #
      # @return [String]
      #
      attr_reader :cache_dir

      ##
      # Get the given git-based files from the git cache, loading from the
      # remote repo if necessary.
      #
      # The resulting files are either copied into a directory you provide in
      # the `:into` parameter, or populated into a _shared_ source directory if
      # you omit the `:info` parameter. In the latter case, it is important
      # that you do not modify the returned files or directories, nor add or
      # remove any files from the directories returned, to avoid confusing
      # callers that could be given the same directory. If you need to make any
      # modifications to the returned files, use `:into` to provide your own
      # private directory.
      #
      # @param remote [String] The URL of the git repo. Required.
      # @param path [String] The path to the file or directory within the repo.
      #     Optional. Defaults to the entire repo.
      # @param commit [String] The commit reference, which may be a SHA or any
      #     git ref such as a branch or tag. Optional. Defaults to `HEAD`.
      # @param into [String] If provided, copies the specified files into the
      #     given directory path. If omitted or `nil`, populates and returns a
      #     shared source file or directory.
      # @param update [Boolean,Integer] Whether to update non-SHA commit
      #     references if they were previously loaded. This is useful, for
      #     example, if the commit is `HEAD` or a branch name. Pass `true` or
      #     `false` to specify whether to update, or an integer to update if
      #     last update was done at least that many seconds ago. Default is
      #     `false`.
      #
      # @return [String] The full path to the cached files. The returned path
      #     will correspod to the path given. For example, if you provide the
      #     path `Gemfile` representing a single file in the repository, the
      #     returned path will point directly to the cached copy of that file.
      #
      def get(remote, path: nil, commit: nil, into: nil, update: false, timestamp: nil)
        path = GitCache.normalize_path(path)
        commit ||= "HEAD"
        timestamp ||= ::Time.now.to_i
        dir = ensure_repo_base_dir(remote)
        lock_repo(dir, remote, timestamp) do |repo_lock|
          ensure_repo(dir, remote)
          sha = ensure_commit(dir, commit, repo_lock, update)
          if into
            copy_files(dir, sha, path, repo_lock, into)
          else
            ensure_source(dir, sha, path, repo_lock)
          end
        end
      end
      alias find get

      ##
      # Returns an array of the known remote names.
      #
      # @return [Array<String>]
      #
      def remotes
        result = []
        return result unless ::File.directory?(cache_dir)
        ::Dir.entries(cache_dir).each do |child|
          next if child.start_with?(".")
          dir = ::File.join(cache_dir, child)
          if ::File.file?(::File.join(dir, LOCK_FILE_NAME))
            remote = lock_repo(dir, &:remote)
            result << remote if remote
          end
        end
        result.sort
      end

      ##
      # Returns a {RepoInfo} describing the cache for the given remote, or
      # `nil` if the given remote has never been cached.
      #
      # @param remote [String] Remote name for a repo
      # @return [RepoInfo,nil]
      #
      def repo_info(remote)
        dir = repo_base_dir_for(remote)
        return nil unless ::File.directory?(dir)
        lock_repo(dir, remote) do |repo_lock|
          RepoInfo.new(dir, repo_lock.data)
        end
      end

      ##
      # Removes caches for the given repos, or all repos if specified.
      #
      # Removes all cache information for the specified repositories, including
      # local clones and shared source directories. The next time these
      # repositories are requested, they will be reloaded from the remote
      # repository from scratch.
      #
      # Be careful not to remove repos that are currently in use by other
      # GitCache clients.
      #
      # @param remotes [Array<String>,:all] The remotes to remove.
      # @return [Array<String>] The remotes actually removed.
      #
      def remove_repos(remotes)
        remotes = self.remotes if remotes.nil? || remotes == :all
        Array(remotes).map do |remote|
          dir = repo_base_dir_for(remote)
          if ::File.directory?(dir)
            ::FileUtils.chmod_R("u+w", dir, force: true)
            ::FileUtils.rm_rf(dir)
            remote
          end
        end.compact.sort
      end

      ##
      # Remove records of the given refs (i.e. branches, tags, or `HEAD`) from
      # the given repository's cache. The next time those refs are requested,
      # they will be pulled from the remote repo.
      #
      # If you provide the `refs:` argument, only those refs are removed.
      # Otherwise, all refs are removed.
      #
      # @param remote [String] The repository
      # @param refs [Array<String>] The refs to remove. Optional.
      # @return [Array<RefInfo>,nil] The refs actually forgotten, or `nil` if
      #     the given repo is not in the cache.
      #
      def remove_refs(remote, refs: nil)
        dir = repo_base_dir_for(remote)
        return nil unless ::File.directory?(dir)
        results = []
        lock_repo(dir, remote) do |repo_lock|
          refs = repo_lock.refs if refs.nil? || refs == :all
          Array(refs).each do |ref|
            ref_data = repo_lock.delete_ref!(ref)
            results << RefInfo.new(ref, ref_data) if ref_data
          end
        end
        results.sort
      end

      ##
      # Removes shared sources for the given cache. The next time a client
      # requests them, the removed sources will be recopied from the repo.
      #
      # If you provide the `commits:` argument, only sources associated with
      # those commits are removed. Otherwise, all sources are removed.
      #
      # Be careful not to remove sources that are currently in use by other
      # GitCache clients.
      #
      # @param remote [String] The repository
      # @param commits [Array<String>] Remove only the sources for the given
      #     commits. Optional.
      # @return [Array<SourceInfo>,nil] The sources actually removed, or `nil`
      #     if the given repo is not in the cache.
      #
      def remove_sources(remote, commits: nil)
        dir = repo_base_dir_for(remote)
        return nil unless ::File.directory?(dir)
        results = []
        lock_repo(dir, remote) do |repo_lock|
          commits = nil if commits == :all
          shas = Array(commits).map { |ref| repo_lock.lookup_ref(ref) }.compact.uniq if commits
          repo_lock.find_sources(shas: shas).each do |(sha, path)|
            data = repo_lock.delete_source!(sha, path)
            results << SourceInfo.new(dir, sha, path, data)
          end
          results.map(&:sha).uniq.each do |sha|
            unless repo_lock.source_exists?(sha)
              sha_dir = ::File.join(dir, sha)
              ::FileUtils.chmod_R("u+w", sha_dir, force: true)
              ::FileUtils.rm_rf(sha_dir)
            end
          end
        end
        results.sort
      end

      private

      REPO_DIR_NAME = "repo"
      LOCK_FILE_NAME = "repo.lock"
      private_constant :REPO_DIR_NAME, :LOCK_FILE_NAME

      def repo_base_dir_for(remote)
        ::File.join(@cache_dir, GitCache.remote_dir_name(remote))
      end

      def default_cache_dir
        require "toys/utils/xdg"
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

      def ensure_repo_base_dir(remote)
        dir = repo_base_dir_for(remote)
        ::FileUtils.mkdir_p(dir)
        dir
      end

      def lock_repo(dir, remote = nil, timestamp = nil)
        lock_path = ::File.join(dir, LOCK_FILE_NAME)
        ::File.open(lock_path, ::File::RDWR | ::File::CREAT) do |file|
          file.flock(::File::LOCK_EX)
          file.rewind
          repo_lock = RepoLock.new(file, remote, timestamp)
          begin
            yield repo_lock
          ensure
            if repo_lock.modified?
              file.rewind
              file.truncate(0)
              repo_lock.dump(file)
            end
          end
        end
      end

      def ensure_repo(dir, remote)
        repo_dir = ::File.join(dir, REPO_DIR_NAME)
        ::FileUtils.mkdir_p(repo_dir)
        result = git(repo_dir, ["remote", "get-url", "origin"])
        unless result.success? && result.captured_out.strip == remote
          ::FileUtils.chmod_R("u+w", repo_dir, force: true)
          ::FileUtils.rm_rf(repo_dir)
          ::FileUtils.mkdir_p(repo_dir)
          git(repo_dir, ["init"],
              error_message: "Unable to initialize git repository")
          git(repo_dir, ["remote", "add", "origin", remote],
              error_message: "Unable to add git remote: #{remote}")
        end
      end

      def ensure_commit(dir, commit, repo_lock, update = false)
        local_commit = "toys-git-cache/#{commit}"
        repo_dir = ::File.join(dir, REPO_DIR_NAME)
        is_sha = commit =~ /^[0-9a-f]{40}$/
        update = repo_lock.ref_stale?(commit, update) unless is_sha
        if (update && !is_sha) || !commit_exists?(repo_dir, local_commit)
          git(repo_dir, ["fetch", "--depth=1", "--force", "origin", "#{commit}:#{local_commit}"],
              error_message: "Unable to fetch commit: #{commit}")
          repo_lock.update_ref!(commit)
        end
        result = git(repo_dir, ["rev-parse", local_commit],
                     error_message: "Unable to retrieve commit: #{local_commit}")
        sha = result.captured_out.strip
        repo_lock.access_ref!(commit, sha)
        sha
      end

      def commit_exists?(repo_dir, commit)
        result = git(repo_dir, ["cat-file", "-t", commit])
        result.success? && result.captured_out.strip == "commit"
      end

      def ensure_source(dir, sha, path, repo_lock)
        repo_path = ::File.join(dir, REPO_DIR_NAME)
        source_path = ::File.join(dir, sha)
        unless repo_lock.source_exists?(sha, path)
          ::FileUtils.mkdir_p(source_path)
          ::FileUtils.chmod_R("u+w", source_path, force: true)
          copy_from_repo(repo_path, source_path, sha, path)
          ::FileUtils.chmod_R("a-w", source_path, force: true)
        end
        repo_lock.access_source!(sha, path)
        path == "." ? source_path : ::File.join(source_path, path)
      end

      def copy_files(dir, sha, path, repo_lock, into)
        repo_path = ::File.join(dir, REPO_DIR_NAME)
        ::FileUtils.mkdir_p(into)
        ::FileUtils.chmod_R("u+w", into, force: true)
        ::Dir.children(into).each { |child| ::FileUtils.rm_rf(::File.join(into, child)) }
        result = copy_from_repo(repo_path, into, sha, path)
        repo_lock.access_repo!
        result
      end

      def copy_from_repo(repo_dir, into, sha, path)
        git(repo_dir, ["checkout", sha])
        if path == "."
          ::Dir.children(repo_dir).each do |entry|
            next if entry == ".git"
            to_path = ::File.join(into, entry)
            unless ::File.exist?(to_path)
              from_path = ::File.join(repo_dir, entry)
              ::FileUtils.copy_entry(from_path, to_path)
            end
          end
          into
        else
          to_path = ::File.join(into, path)
          unless ::File.exist?(to_path)
            from_path = ::File.join(repo_dir, path)
            ::FileUtils.mkdir_p(::File.dirname(to_path))
            ::FileUtils.copy_entry(from_path, to_path)
          end
          to_path
        end
      end

      ##
      # An object that manages the lock data
      #
      # @private
      #
      class RepoLock
        ##
        # @private
        #
        def initialize(io, remote, timestamp)
          @data = ::JSON.parse(io.read) rescue {} # rubocop:disable Style/RescueModifier
          @data["remote"] ||= remote
          @data["refs"] ||= {}
          @data["sources"] ||= {}
          @modified = false
          @timestamp = timestamp || ::Time.now.to_i
        end

        ##
        # @private
        #
        attr_reader :data

        ##
        # @private
        #
        def modified?
          @modified
        end

        ##
        # @private
        #
        def dump(io)
          ::JSON.dump(@data, io)
        end

        ##
        # @private
        #
        def remote
          @data["remote"]
        end

        ##
        # @private
        #
        def refs
          @data["refs"].keys
        end

        ##
        # @private
        #
        def lookup_ref(ref)
          return ref if ref =~ /^[0-9a-f]{40}$/
          @data["refs"][ref]&.fetch("sha", nil)
        end

        ##
        # @private
        #
        def ref_data(ref)
          @data["refs"][ref]
        end

        ##
        # @private
        #
        def ref_stale?(ref, age)
          ref_info = @data["refs"][ref]
          last_updated = ref_info ? ref_info.fetch("updated", 0) : 0
          return true if last_updated.zero?
          return age unless age.is_a?(::Numeric)
          @timestamp >= last_updated + age
        end

        ##
        # @private
        #
        def update_ref!(ref)
          ref_info = @data["refs"][ref] ||= {}
          is_first = !ref_info.key?("updated")
          ref_info["updated"] = @timestamp
          @modified = true
          is_first
        end

        ##
        # @private
        #
        def delete_ref!(ref)
          ref_data = @data["refs"].delete(ref)
          @modified = true if ref_data
          ref_data
        end

        ##
        # @private
        #
        def delete_source!(sha, path)
          sha_data = @data["sources"][sha]
          return nil if sha_data.nil?
          source_data = sha_data.delete(path)
          if source_data
            @modified = true
            @data["sources"].delete(sha) if sha_data.empty?
          end
          source_data
        end

        ##
        # @private
        #
        def access_ref!(ref, sha)
          ref_info = @data["refs"][ref] ||= {}
          ref_info["sha"] = sha
          is_first = !ref_info.key?("accessed")
          ref_info["accessed"] = @timestamp
          @modified = true
          is_first
        end

        ##
        # @private
        #
        def source_exists?(sha, path = nil)
          sha_info = @data["sources"][sha]
          path ? sha_info&.fetch(path, nil)&.key?("accessed") : !sha_info.nil?
        end

        ##
        # @private
        #
        def source_data(sha, path)
          @data["sources"][sha]&.fetch(path, nil)
        end

        ##
        # @private
        #
        def find_sources(paths: nil, shas: nil)
          results = []
          @data["sources"].each do |sha, sha_data|
            next unless shas.nil? || shas.include?(sha)
            sha_data.each_key do |path|
              next unless paths.nil? || paths.include?(path)
              results << [sha, path]
            end
          end
          results
        end

        ##
        # @private
        #
        def access_source!(sha, path)
          @data["accessed"] = @timestamp
          source_info = @data["sources"][sha] ||= {}
          path_info = source_info[path] ||= {}
          is_first = !path_info.key?("accessed")
          path_info["accessed"] = @timestamp
          @modified = true
          is_first
        end

        ##
        # @private
        #
        def access_repo!
          is_first = !@data.key?("accessed")
          @data["accessed"] = @timestamp
          @modified = true
          is_first
        end
      end

      class << self
        ##
        # @private
        #
        def remote_dir_name(remote)
          ::Digest::MD5.hexdigest(remote)
        end

        ##
        # @private
        #
        def normalize_path(orig_path)
          segs = []
          orig_segs = orig_path.to_s.sub(%r{^/+}, "").split(%r{/+})
          raise ::ArgumentError, "Path #{orig_path.inspect} reads .git directory" if orig_segs.first == ".git"
          orig_segs.each do |seg|
            if seg == ".."
              raise ::ArgumentError, "Path #{orig_path.inspect} references its parent" if segs.empty?
              segs.pop
            elsif seg != "."
              segs.push(seg)
            end
          end
          segs.empty? ? "." : segs.join("/")
        end
      end
    end
  end
end
