# frozen_string_literal: true

require "helper"
require "toys/utils/exec"
require "toys/utils/git_cache"
require "digest"
require "fileutils"
require "net/http"
require "uri"

describe Toys::Utils::GitCache do
  let(:cache_dir) { File.join(Dir.tmpdir, "toys_git_cache_test") }
  let(:git_cache) { Toys::Utils::GitCache.new(cache_dir: cache_dir) }
  let(:sample_remote) { "https://github.com/dazuma/toys.git" }
  let(:target_dir) { File.join(Dir.tmpdir, "toys_git_cache_test2") }

  before do
    FileUtils.chmod_R("u+w", cache_dir, force: true)
    FileUtils.rm_rf(cache_dir)
    FileUtils.chmod_R("u+w", target_dir, force: true)
    FileUtils.rm_rf(target_dir)
  end

  it "uses the default cache dir" do
    git_cache = Toys::Utils::GitCache.new
    expected_cache_dir = File.join(Dir.home, ".cache", "toys", "git")
    assert_equal(expected_cache_dir, git_cache.cache_dir)
    expected_remote_dir = Digest::MD5.hexdigest(sample_remote)
    assert_equal(expected_remote_dir, Toys::Utils::GitCache.remote_dir_name(sample_remote))
  end

  describe "normalize_path" do
    def normalize(path)
      Toys::Utils::GitCache.normalize_path(path)
    end

    it "normalizes nil to dot" do
      assert_equal(".", normalize(nil))
    end

    it "normalizes empty string to dot" do
      assert_equal(".", normalize(""))
    end

    it "normalizes dot to dot" do
      assert_equal(".", normalize("."))
    end

    it "normalizes a simple path" do
      assert_equal("foo/bar", normalize("foo/bar"))
    end

    it "strips a leading slash" do
      assert_equal("foo/bar", normalize("/foo/bar"))
    end

    it "strips multiple leading slashes" do
      assert_equal("foo/bar", normalize("///foo/bar"))
    end

    it "collapses multiple slashes" do
      assert_equal("foo/bar", normalize("foo//bar"))
    end

    it "resolves a dot segment" do
      assert_equal("foo/bar", normalize("foo/./bar"))
    end

    it "resolves a dotdot segment" do
      assert_equal("foo", normalize("foo/bar/.."))
    end

    it "resolves dotdot to the root" do
      assert_equal(".", normalize("foo/bar/../.."))
    end

    it "resolves dotdot back up correctly" do
      assert_equal("baz", normalize("foo/bar/../../baz"))
    end

    it "raises on dotdot past the root" do
      assert_raises(::ArgumentError) { normalize("foo/../..") }
    end

    it "raises on a leading dotdot" do
      assert_raises(::ArgumentError) { normalize("../foo") }
    end

    it "raises when path reads .git directory" do
      assert_raises(::ArgumentError) { normalize(".git/config") }
    end

    it "raises when dotdot traversal resolves to .git directory" do
      assert_raises(::ArgumentError) { normalize("foo/../.git/config") }
    end

    it "does not raise on .git in non-leading position" do
      assert_equal("foo/.git/config", normalize("foo/.git/config"))
    end
  end

  it "prevents concurrent use of the repo" do
    git_cache
    FileUtils.mkdir_p(cache_dir)
    start1 = finish1 = start2 = finish2 = nil
    timestamp = ::Time.now.to_i
    thread1 = Thread.new do
      git_cache.send(:lock_repo, cache_dir, "foo", timestamp) do
        start1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        sleep(0.5)
        finish1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
    thread2 = Thread.new do
      git_cache.send(:lock_repo, cache_dir, "bar", timestamp) do
        start2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        sleep(0.5)
        finish2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
    thread1.join
    thread2.join
    assert(start1 >= finish2 || start2 >= finish1)
  end

  describe "valid_sha?" do
    def valid_sha?(ref)
      Toys::Utils::GitCache.valid_sha?(ref)
    end

    it "accepts a 40-character lowercase hex string" do
      assert(valid_sha?("a" * 40))
      assert(valid_sha?("0123456789abcdef0123456789abcdef01234567"))
    end

    it "accepts a 64-character lowercase hex string" do
      assert(valid_sha?("b" * 64))
    end

    it "rejects a 39-character hex string" do
      refute(valid_sha?("a" * 39))
    end

    it "rejects a 41-character hex string" do
      refute(valid_sha?("a" * 41))
    end

    it "rejects a 63-character hex string" do
      refute(valid_sha?("a" * 63))
    end

    it "rejects a 65-character hex string" do
      refute(valid_sha?("a" * 65))
    end

    it "rejects uppercase hex characters" do
      refute(valid_sha?("A" * 40))
    end

    it "rejects non-hex characters" do
      refute(valid_sha?("g" * 40))
    end

    it "rejects a branch name" do
      refute(valid_sha?("main"))
    end

    it "rejects an empty string" do
      refute(valid_sha?(""))
    end
  end

  describe "with local git" do
    let(:exec_tool) { Toys::Utils::Exec.new }
    let(:git_repo_dir) { File.join(Dir.tmpdir, "toys_git_cache_test3") }
    let(:local_remote) { File.join(git_repo_dir, ".git") }

    def exec_git(*args)
      result = exec_tool.exec(["git"] + args, out: :capture, err: :null)
      assert(result.success?, "Git failed: #{args}")
      result.captured_out
    end

    def commit_file(name, content: nil)
      Dir.chdir(git_repo_dir) do
        dir = File.dirname(name)
        FileUtils.mkdir_p(dir) unless dir == "."
        File.open(name, "w") { |file| file.puts(content || name) }
        exec_git("add", name)
        exec_git("commit", "-m", "Add file #{name}")
      end
    end

    def create_branch(name)
      Dir.chdir(git_repo_dir) do
        exec_git("branch", name)
      end
    end

    before do
      FileUtils.rm_rf(git_repo_dir)
      FileUtils.mkdir_p(git_repo_dir)
      Dir.chdir(git_repo_dir) do
        exec_git("init")
      end
    end

    it "gets local repo content from HEAD" do
      file_name = "file1.txt"
      commit_file(file_name)
      dir = git_cache.get(local_remote)
      content = File.read(File.join(dir, file_name))
      assert_equal(file_name, content.strip)
    end

    it "gets single local file from HEAD" do
      file_name = "file1.txt"
      commit_file(file_name)
      found_path = git_cache.get(local_remote, path: file_name)
      assert_equal(file_name, File.basename(found_path))
      content = File.read(found_path)
      assert_equal(file_name, content.strip)
    end

    it "is resilient against broken symlinks" do
      file_name = "broken.txt"
      bad_target = "nonexistent.txt"
      Dir.chdir(git_repo_dir) do
        FileUtils.ln_s(bad_target, file_name)
        exec_git("add", file_name)
        exec_git("commit", "-m", "Add broken symlink")
      end
      dir = git_cache.get(local_remote)
      content = File.readlink(File.join(dir, file_name))
      assert_equal(bad_target, content)
    end

    it "makes source files read-only by default" do
      file_name = "file1.txt"
      commit_file(file_name)
      found_path = git_cache.get(local_remote, path: file_name)
      assert_raises(Errno::EACCES) do
        File.write(found_path, "changed")
      end
    end

    it "makes source files writable if the environment variable is set" do
      file_name = "file1.txt"
      commit_file(file_name)
      begin
        ::ENV["TOYS_GIT_CACHE_WRITABLE"] = "true"
        found_path = git_cache.get(local_remote, path: file_name)
        File.write(found_path, "changed")
      ensure
        ::ENV["TOYS_GIT_CACHE_WRITABLE"] = nil
      end
    end

    it "allows updating of an existing source" do
      file1_name = "dir/file1.txt"
      file2_name = "dir/file2.txt"
      commit_file(file1_name)
      commit_file(file2_name)
      git_cache.get(local_remote, path: file1_name)
      found2_path = git_cache.get(local_remote, path: file2_name)
      content = File.read(found2_path)
      assert_equal(file2_name, content.strip)
    end

    it "loads a directory source after some content was previously loaded" do
      dir_name = "dir"
      file1_path = File.join("dir", "file1.txt")
      file2_path = File.join("dir", "file2.txt")
      commit_file(file1_path)
      commit_file(file2_path)
      git_cache.get(local_remote, path: file1_path)
      source_dir_path = git_cache.get(local_remote, path: dir_name)
      assert(File.file?(File.join(source_dir_path, "file2.txt")))
    end

    it "gets a file into a specified directory" do
      file_name = "foo/bar/file1.txt"
      commit_file(file_name)
      found_path = git_cache.get(local_remote, path: file_name, into: target_dir)
      assert_equal(File.join(target_dir, file_name), found_path)
      content = File.read(found_path)
      assert_equal(file_name, content.strip)
    end

    it "preserves existing files in the into directory that are not in the repo" do
      file_name = "file1.txt"
      commit_file(file_name)
      extra_file = File.join(target_dir, "extra.txt")
      FileUtils.mkdir_p(target_dir)
      File.write(extra_file, "extra")
      git_cache.get(local_remote, path: file_name, into: target_dir)
      assert(File.file?(extra_file))
      assert_equal("extra", File.read(extra_file))
    end

    it "gets with update" do
      file1_name = "file1.txt"
      file2_name = "file2.txt"
      commit_file(file1_name)
      dir1 = git_cache.get(local_remote, update: true)
      refute(File.file?(File.join(dir1, file2_name)))
      dir2 = git_cache.get(local_remote, update: true)
      assert_equal(dir1, dir2)
      commit_file(file2_name)
      dir3 = git_cache.get(local_remote, update: true)
      refute_equal(dir1, dir3)
      assert(File.file?(File.join(dir3, file2_name)))
      content = File.read(File.join(dir3, file2_name))
      assert_equal(file2_name, content.strip)
    end

    it "updates based on cache age" do
      file1_name = "file1.txt"
      file2_name = "file2.txt"
      commit_file(file1_name)
      dir1 = git_cache.get(local_remote, timestamp: 1000)
      refute(File.file?(File.join(dir1, file2_name)))
      commit_file(file2_name)
      dir2 = git_cache.get(local_remote, timestamp: 1001, update: 10)
      refute(File.file?(File.join(dir2, file2_name)))
      dir3 = git_cache.get(local_remote, timestamp: 1010, update: 10)
      assert(File.file?(File.join(dir3, file2_name)))
    end

    it "does not re-fetch a SHA commit when update is true" do
      commit_file("file1.txt")
      git_cache.get(local_remote, timestamp: 1000)
      sha = git_cache.repo_info(local_remote).refs(ref: "HEAD").first.sha
      git_cache.get(local_remote, commit: sha, timestamp: 2000)
      assert_equal(Time.at(2000).utc,
                   git_cache.repo_info(local_remote).refs(ref: sha).first.last_updated)
      git_cache.get(local_remote, commit: sha, update: true, timestamp: 3000)
      ref_info = git_cache.repo_info(local_remote).refs(ref: sha).first
      assert_equal(Time.at(2000).utc, ref_info.last_updated)
      assert_equal(Time.at(3000).utc, ref_info.last_accessed)
    end

    it "reuses a git clone for the same remote" do
      branch1 = "b1"
      branch2 = "b2"
      file1_name = "file1.txt"
      file2_name = "file2.txt"
      commit_file(file1_name)
      create_branch(branch1)
      commit_file(file2_name)
      create_branch(branch2)

      git_cache.get(local_remote, commit: branch1)
      repo_path = File.join(git_cache.cache_dir,
                            Toys::Utils::GitCache.remote_dir_name(local_remote), "repo")
      file_path = File.join(repo_path, "tmp.txt")
      File.open(file_path, "w") do |file|
        file.puts("hello")
      end
      sha1 = Dir.chdir(repo_path) { `git rev-parse HEAD` }
      git_cache.get(local_remote, commit: branch2)
      assert_equal("hello\n", File.read(file_path))
      sha2 = Dir.chdir(repo_path) { `git rev-parse HEAD` }
      refute_equal(sha1, sha2)
    end

    it "reuses a source for the same sha" do
      dir_name = "foo"
      file_name = File.join(dir_name, "bar.txt")
      commit_file(file_name)
      found_file_path = git_cache.get(local_remote, path: file_name)
      found_dir_path = git_cache.get(local_remote, path: dir_name)
      assert_equal(found_dir_path, File.dirname(found_file_path))
    end

    it "does not reread the repo when a source can be reused" do
      file_name = "file1.txt"
      commit_file(file_name)
      found_path = git_cache.get(local_remote, path: file_name)
      FileUtils.chmod("u+w", found_path)
      File.write(found_path, "modified")
      found_path2 = git_cache.get(local_remote, path: file_name)
      assert_equal(found_path, found_path2)
      assert_equal("modified", File.read(found_path2).strip)
    end

    it "does not reread the repo when requesting a sub-path of a cached directory" do
      dir_name = "dir"
      file_name = File.join(dir_name, "file1.txt")
      commit_file(file_name)
      found_dir_path = git_cache.get(local_remote, path: dir_name)
      cached_file = File.join(found_dir_path, "file1.txt")
      FileUtils.chmod("u+w", cached_file)
      File.write(cached_file, "modified")
      found_file_path = git_cache.get(local_remote, path: file_name)
      assert_equal(File.join(found_dir_path, "file1.txt"), found_file_path)
      assert_equal("modified", File.read(found_file_path).strip)
    end

    it "does not reread the repo when requesting any path after the whole repo is cached" do
      file_name = "file1.txt"
      commit_file(file_name)
      root_dir = git_cache.get(local_remote)
      cached_file = File.join(root_dir, file_name)
      FileUtils.chmod("u+w", cached_file)
      File.write(cached_file, "modified")
      found_file_path = git_cache.get(local_remote, path: file_name)
      assert_equal("modified", File.read(found_file_path).strip)
    end

    it "gets empty remote names list" do
      assert_empty(git_cache.remotes)
    end

    it "gets remote name for a local remote" do
      file_name = "file1.txt"
      commit_file(file_name)
      git_cache.get(local_remote, path: file_name)
      assert_equal([local_remote], git_cache.remotes)
    end

    it "returns nil when asked for repo info for a nonexistent remote" do
      assert_nil(git_cache.repo_info(local_remote))
    end

    it "gets repo info for a local remote" do
      file_name = "file1.txt"
      commit_file(file_name)

      time1 = Time.at(Time.now.to_i)
      found_path = git_cache.get(local_remote, path: file_name)
      time2 = Time.at(Time.now.to_i)

      repo_info = git_cache.repo_info(local_remote)

      assert(File.directory?(File.join(repo_info.base_dir, "repo")))
      assert(File.file?(File.join(repo_info.base_dir, "repo.lock")))
      assert_equal(local_remote, repo_info.remote)
      assert(repo_info.last_accessed.between?(time1, time2))

      assert_equal(1, repo_info.refs.size)
      ref_info = repo_info.refs.first
      assert_equal("HEAD", ref_info.ref)
      assert(ref_info.last_accessed.between?(time1, time2))
      assert(ref_info.last_updated.between?(time1, time2))

      assert_equal(1, repo_info.sources.size)
      source_info = repo_info.sources.first
      assert_equal(ref_info.sha, source_info.sha)
      assert_equal(file_name, source_info.git_path)
      assert_equal(found_path, source_info.source)
      assert(source_info.last_accessed.between?(time1, time2))
    end

    it "gets source info for multiple accesses" do
      file_name = "file1.txt"
      commit_file(file_name)

      time1 = Time.at(Time.now.to_i)
      found_path2 = git_cache.get(local_remote, path: file_name)
      found_path1 = git_cache.get(local_remote)
      time2 = Time.at(Time.now.to_i)

      repo_info = git_cache.repo_info(local_remote)

      assert_equal(2, repo_info.sources.size)
      source_info1, source_info2 = repo_info.sources
      assert_equal(repo_info.refs.first.sha, source_info1.sha)
      assert_equal(".", source_info1.git_path)
      assert_equal(found_path1, source_info1.source)
      assert(source_info1.last_accessed.between?(time1, time2))
      assert_equal(repo_info.refs.first.sha, source_info2.sha)
      assert_equal(file_name, source_info2.git_path)
      assert_equal(found_path2, source_info2.source)
      assert(source_info2.last_accessed.between?(time1, time2))
    end

    it "gets ref info for multiple accesses" do
      branch1 = "b1"
      branch2 = "b2"
      file1_name = "file1.txt"
      file2_name = "file2.txt"
      commit_file(file1_name)
      create_branch(branch1)
      commit_file(file2_name)
      create_branch(branch2)

      time1 = Time.at(Time.now.to_i)
      found_path1 = git_cache.get(local_remote, commit: branch1)
      found_path2 = git_cache.get(local_remote, commit: branch2)
      time2 = Time.at(Time.now.to_i)

      repo_info = git_cache.repo_info(local_remote)

      assert_equal(2, repo_info.refs.size)
      ref_info1, ref_info2 = repo_info.refs
      assert_equal(branch1, ref_info1.ref)
      assert(ref_info1.last_accessed.between?(time1, time2))
      assert(ref_info1.last_updated.between?(time1, time2))
      assert_includes(found_path1, ref_info1.sha)
      assert_equal(branch2, ref_info2.ref)
      assert(ref_info2.last_accessed.between?(time1, time2))
      assert(ref_info2.last_updated.between?(time1, time2))
      assert_includes(found_path2, ref_info2.sha)
    end

    it "removes a repo" do
      file_name = "file1.txt"
      commit_file(file_name)
      git_cache.get(local_remote)
      repo_dir = git_cache.repo_info(local_remote).base_dir
      assert(File.directory?(repo_dir))
      git_cache.remove_repos(local_remote)
      assert_nil(git_cache.repo_info(local_remote))
      refute(File.directory?(repo_dir))
    end

    it "removes a ref" do
      file_name = "file1.txt"
      updated_content = "updated"
      commit_file(file_name)
      found_path = git_cache.get(local_remote, path: file_name)
      assert_equal(file_name, File.read(found_path).strip)

      commit_file(file_name, content: updated_content)
      found_path1 = git_cache.get(local_remote, path: file_name)
      assert_equal(found_path, found_path1)
      assert_equal(file_name, File.read(found_path1).strip)

      refs = git_cache.remove_refs(local_remote, refs: "HEAD")
      assert_equal(1, refs.size)
      assert_equal("HEAD", refs.first.ref)
      found_path2 = git_cache.get(local_remote, path: file_name)
      refute_equal(found_path, found_path2)
      assert_equal(updated_content, File.read(found_path2).strip)
    end

    it "removes a source by commit" do
      file_name = "file1.txt"
      commit_file(file_name)
      git_cache.get(local_remote)
      found_path = git_cache.get(local_remote, path: file_name)
      assert(File.file?(found_path))
      sources = git_cache.remove_sources(local_remote, commits: "HEAD")
      assert_equal(2, sources.size)
      assert_equal(".", sources.first.git_path)
      assert_equal(file_name, sources.last.git_path)
      refute(File.file?(found_path))
    end

    it "removes all sources when commits is omitted" do
      file_name = "file1.txt"
      commit_file(file_name)
      git_cache.get(local_remote)
      found_path = git_cache.get(local_remote, path: file_name)
      assert(File.file?(found_path))
      sources = git_cache.remove_sources(local_remote)
      assert_equal(2, sources.size)
      assert_equal(".", sources.first.git_path)
      assert_equal(file_name, sources.last.git_path)
      refute(File.file?(found_path))
    end

    it "removes all refs when refs is omitted" do
      branch1 = "b1"
      branch2 = "b2"
      commit_file("file1.txt")
      create_branch(branch1)
      commit_file("file2.txt")
      create_branch(branch2)
      git_cache.get(local_remote, commit: branch1)
      git_cache.get(local_remote, commit: branch2)
      assert_equal(2, git_cache.repo_info(local_remote).refs.size)
      refs = git_cache.remove_refs(local_remote)
      assert_equal(2, refs.size)
      assert_equal([branch1, branch2], refs.map(&:ref))
      assert_empty(git_cache.repo_info(local_remote).refs)
    end

    it "remove_refs returns nil for an unknown remote" do
      assert_nil(git_cache.remove_refs("/no/such/remote"))
    end

    it "remove_sources returns nil for an unknown remote" do
      assert_nil(git_cache.remove_sources("/no/such/remote"))
    end
  end

  describe "with two local git repos" do
    let(:exec_tool) { Toys::Utils::Exec.new }
    let(:git_repo_dir1) { File.join(Dir.tmpdir, "toys_git_cache_test3") }
    let(:git_repo_dir2) { File.join(Dir.tmpdir, "toys_git_cache_test4") }
    let(:local_remote1) { File.join(git_repo_dir1, ".git") }
    let(:local_remote2) { File.join(git_repo_dir2, ".git") }

    def init_repo(dir)
      FileUtils.rm_rf(dir)
      FileUtils.mkdir_p(dir)
      Dir.chdir(dir) do
        exec_tool.exec(["git", "init"], out: :null, err: :null)
        File.open("file.txt", "w") { |f| f.puts("file.txt") }
        exec_tool.exec(["git", "add", "file.txt"], out: :null, err: :null)
        exec_tool.exec(["git", "commit", "-m", "init"], out: :null, err: :null)
      end
    end

    before do
      init_repo(git_repo_dir1)
      init_repo(git_repo_dir2)
    end

    after do
      FileUtils.rm_rf(git_repo_dir1)
      FileUtils.rm_rf(git_repo_dir2)
    end

    it "lists both remotes sorted alphabetically" do
      git_cache.get(local_remote1)
      git_cache.get(local_remote2)
      remotes = git_cache.remotes
      assert_equal(2, remotes.size)
      assert_includes(remotes, local_remote1)
      assert_includes(remotes, local_remote2)
      assert_equal(remotes.sort, remotes)
    end

    it "removes all repos with :all" do
      git_cache.get(local_remote1)
      git_cache.get(local_remote2)
      assert_equal(2, git_cache.remotes.size)
      removed = git_cache.remove_repos(:all)
      assert_equal(0, git_cache.remotes.size)
      assert_equal(2, removed.size)
      assert_includes(removed, local_remote1)
      assert_includes(removed, local_remote2)
      assert_equal(removed.sort, removed)
    end
  end

  describe "RepoInfo" do
    let(:base_dir) { "/cache/myrepo" }
    let(:sha1) { "a" * 40 }
    let(:sha2) { "b" * 40 }

    def make_repo_info(data)
      Toys::Utils::GitCache::RepoInfo.new(base_dir, data)
    end

    def minimal_data
      { "remote" => "https://example.com/repo.git", "refs" => {}, "sources" => {} }
    end

    it "exposes base_dir and remote" do
      info = make_repo_info(minimal_data)
      assert_equal(base_dir, info.base_dir)
      assert_equal("https://example.com/repo.git", info.remote)
    end

    it "returns nil last_accessed when accessed key is absent" do
      info = make_repo_info(minimal_data)
      assert_nil(info.last_accessed)
    end

    it "converts last_accessed integer to UTC Time" do
      info = make_repo_info(minimal_data.merge("accessed" => 1_000_000))
      assert_equal(Time.at(1_000_000).utc, info.last_accessed)
      assert_equal("UTC", info.last_accessed.zone)
    end

    it "returns empty refs list when there are no refs" do
      info = make_repo_info(minimal_data)
      assert_empty(info.refs)
    end

    it "returns all refs when called without keyword" do
      data = minimal_data.merge(
        "refs" => {
          "main" => { "sha" => sha1, "accessed" => 100, "updated" => 100 },
          "HEAD" => { "sha" => sha2, "accessed" => 200, "updated" => 200 },
        }
      )
      info = make_repo_info(data)
      assert_equal(2, info.refs.size)
    end

    it "returns refs sorted alphabetically by name" do
      data = minimal_data.merge(
        "refs" => {
          "zzz" => { "sha" => sha1 },
          "aaa" => { "sha" => sha2 },
          "mmm" => { "sha" => sha1 },
        }
      )
      info = make_repo_info(data)
      assert_equal(["aaa", "mmm", "zzz"], info.refs.map(&:ref))
    end

    it "filters refs by name with ref: keyword" do
      data = minimal_data.merge(
        "refs" => {
          "main" => { "sha" => sha1 },
          "HEAD" => { "sha" => sha2 },
        }
      )
      info = make_repo_info(data)
      result = info.refs(ref: "main")
      assert_equal(1, result.size)
      assert_equal("main", result.first.ref)
    end

    it "returns empty array when named ref does not exist" do
      info = make_repo_info(minimal_data)
      assert_empty(info.refs(ref: "nonexistent"))
    end

    it "returns a dup from refs so mutation does not affect internal state" do
      data = minimal_data.merge("refs" => { "HEAD" => { "sha" => sha1 } })
      info = make_repo_info(data)
      info.refs.clear
      assert_equal(1, info.refs.size)
    end

    it "returns empty sources list when there are no sources" do
      info = make_repo_info(minimal_data)
      assert_empty(info.sources)
    end

    it "returns all sources when called without keywords" do
      data = minimal_data.merge(
        "sources" => {
          sha1 => { "." => { "accessed" => 100 }, "foo" => { "accessed" => 200 } },
          sha2 => { "bar" => { "accessed" => 300 } },
        }
      )
      info = make_repo_info(data)
      assert_equal(3, info.sources.size)
    end

    it "returns sources sorted by sha then git_path" do
      data = minimal_data.merge(
        "sources" => {
          sha2 => { "b" => { "accessed" => 1 }, "a" => { "accessed" => 2 } },
          sha1 => { "c" => { "accessed" => 3 } },
        }
      )
      info = make_repo_info(data)
      assert_equal([[sha1, "c"], [sha2, "a"], [sha2, "b"]],
                   info.sources.map { |s| [s.sha, s.git_path] })
    end

    it "filters sources by sha" do
      data = minimal_data.merge(
        "sources" => {
          sha1 => { "foo" => { "accessed" => 100 } },
          sha2 => { "bar" => { "accessed" => 200 } },
        }
      )
      info = make_repo_info(data)
      result = info.sources(sha: sha1)
      assert_equal(1, result.size)
      assert_equal(sha1, result.first.sha)
    end

    it "filters sources by git_path" do
      data = minimal_data.merge(
        "sources" => {
          sha1 => { "foo" => { "accessed" => 100 }, "bar" => { "accessed" => 200 } },
        }
      )
      info = make_repo_info(data)
      result = info.sources(git_path: "foo")
      assert_equal(1, result.size)
      assert_equal("foo", result.first.git_path)
    end

    it "filters sources by sha and git_path together" do
      data = minimal_data.merge(
        "sources" => {
          sha1 => { "foo" => { "accessed" => 100 }, "bar" => { "accessed" => 200 } },
          sha2 => { "foo" => { "accessed" => 300 } },
        }
      )
      info = make_repo_info(data)
      result = info.sources(sha: sha1, git_path: "foo")
      assert_equal(1, result.size)
      assert_equal(sha1, result.first.sha)
      assert_equal("foo", result.first.git_path)
    end

    it "returns empty array when no sources match the filter" do
      data = minimal_data.merge("sources" => { sha1 => { "foo" => { "accessed" => 100 } } })
      info = make_repo_info(data)
      assert_empty(info.sources(sha: sha2))
    end

    it "returns a dup from sources so mutation does not affect internal state" do
      data = minimal_data.merge("sources" => { sha1 => { "foo" => { "accessed" => 100 } } })
      info = make_repo_info(data)
      info.sources.clear
      assert_equal(1, info.sources.size)
    end

    it "serializes to_h without last_accessed" do
      info = make_repo_info(minimal_data)
      h = info.to_h
      assert_equal("https://example.com/repo.git", h["remote"])
      assert_equal(base_dir, h["base_dir"])
      refute(h.key?("last_accessed"))
      assert_equal([], h["refs"])
      assert_equal([], h["sources"])
    end

    it "serializes to_h with last_accessed as integer" do
      info = make_repo_info(minimal_data.merge("accessed" => 1_000_000))
      assert_equal(1_000_000, info.to_h["last_accessed"])
    end

    it "serializes refs and sources as arrays of hashes" do
      data = minimal_data.merge(
        "refs" => { "HEAD" => { "sha" => sha1, "accessed" => 100, "updated" => 200 } },
        "sources" => { sha1 => { "." => { "accessed" => 100 } } }
      )
      info = make_repo_info(data)
      h = info.to_h
      assert_equal(1, h["refs"].size)
      assert_kind_of(Hash, h["refs"].first)
      assert_equal(1, h["sources"].size)
      assert_kind_of(Hash, h["sources"].first)
    end

    it "compares by remote" do
      info_a = make_repo_info(minimal_data.merge("remote" => "aaa"))
      info_b = make_repo_info(minimal_data.merge("remote" => "bbb"))
      assert(info_a < info_b)
      assert(info_b > info_a)
    end

    it "sorts an array of RepoInfo by remote" do
      info_c = make_repo_info(minimal_data.merge("remote" => "ccc"))
      info_a = make_repo_info(minimal_data.merge("remote" => "aaa"))
      info_b = make_repo_info(minimal_data.merge("remote" => "bbb"))
      assert_equal(["aaa", "bbb", "ccc"], [info_c, info_a, info_b].sort.map(&:remote))
    end
  end

  describe "RefInfo" do
    let(:sha) { "a" * 40 }

    def make_ref_info(ref, data)
      Toys::Utils::GitCache::RefInfo.new(ref, data)
    end

    it "exposes ref and sha" do
      info = make_ref_info("HEAD", { "sha" => sha })
      assert_equal("HEAD", info.ref)
      assert_equal(sha, info.sha)
    end

    it "returns nil last_accessed when absent" do
      info = make_ref_info("HEAD", { "sha" => sha })
      assert_nil(info.last_accessed)
    end

    it "returns nil last_updated when absent" do
      info = make_ref_info("HEAD", { "sha" => sha })
      assert_nil(info.last_updated)
    end

    it "converts last_accessed integer to UTC Time" do
      info = make_ref_info("HEAD", { "sha" => sha, "accessed" => 1_000_000 })
      assert_equal(Time.at(1_000_000).utc, info.last_accessed)
      assert_equal("UTC", info.last_accessed.zone)
    end

    it "converts last_updated integer to UTC Time" do
      info = make_ref_info("HEAD", { "sha" => sha, "updated" => 2_000_000 })
      assert_equal(Time.at(2_000_000).utc, info.last_updated)
      assert_equal("UTC", info.last_updated.zone)
    end

    it "serializes to_h without optional timestamps" do
      info = make_ref_info("HEAD", { "sha" => sha })
      h = info.to_h
      assert_equal("HEAD", h["ref"])
      assert_equal(sha, h["sha"])
      refute(h.key?("last_accessed"))
      refute(h.key?("last_updated"))
    end

    it "serializes to_h with timestamps as integers" do
      info = make_ref_info("HEAD", { "sha" => sha, "accessed" => 100, "updated" => 200 })
      h = info.to_h
      assert_equal(100, h["last_accessed"])
      assert_equal(200, h["last_updated"])
    end

    it "compares by ref name" do
      info_a = make_ref_info("aaa", { "sha" => sha })
      info_b = make_ref_info("bbb", { "sha" => sha })
      assert(info_a < info_b)
      assert(info_b > info_a)
    end

    it "sorts an array of RefInfo alphabetically by ref" do
      info_c = make_ref_info("ccc", { "sha" => sha })
      info_a = make_ref_info("aaa", { "sha" => sha })
      info_b = make_ref_info("bbb", { "sha" => sha })
      assert_equal(["aaa", "bbb", "ccc"], [info_c, info_a, info_b].sort.map(&:ref))
    end
  end

  describe "SourceInfo" do
    let(:base_dir) { "/cache/myrepo" }
    let(:sha) { "a" * 40 }

    def make_source_info(git_path, data = {})
      Toys::Utils::GitCache::SourceInfo.new(base_dir, sha, git_path, data)
    end

    it "exposes sha and git_path" do
      info = make_source_info("foo/bar.txt")
      assert_equal(sha, info.sha)
      assert_equal("foo/bar.txt", info.git_path)
    end

    it "computes source as base_dir/sha for path dot" do
      info = make_source_info(".")
      assert_equal(File.join(base_dir, sha), info.source)
    end

    it "computes source as base_dir/sha/git_path for a simple filename" do
      info = make_source_info("file.txt")
      assert_equal(File.join(base_dir, sha, "file.txt"), info.source)
    end

    it "computes source as base_dir/sha/git_path for a nested path" do
      info = make_source_info("foo/bar/baz.txt")
      assert_equal(File.join(base_dir, sha, "foo/bar/baz.txt"), info.source)
    end

    it "returns nil last_accessed when absent" do
      info = make_source_info(".")
      assert_nil(info.last_accessed)
    end

    it "converts last_accessed integer to UTC Time" do
      info = make_source_info(".", { "accessed" => 1_000_000 })
      assert_equal(Time.at(1_000_000).utc, info.last_accessed)
      assert_equal("UTC", info.last_accessed.zone)
    end

    it "serializes to_h without last_accessed" do
      info = make_source_info("foo/bar.txt")
      h = info.to_h
      assert_equal(sha, h["sha"])
      assert_equal("foo/bar.txt", h["git_path"])
      assert_equal(File.join(base_dir, sha, "foo/bar.txt"), h["source"])
      refute(h.key?("last_accessed"))
    end

    it "serializes to_h with last_accessed as integer" do
      info = make_source_info(".", { "accessed" => 1_000_000 })
      assert_equal(1_000_000, info.to_h["last_accessed"])
    end

    it "compares first by sha then by git_path" do
      sha1 = "a" * 40
      sha2 = "b" * 40
      info_a1 = Toys::Utils::GitCache::SourceInfo.new(base_dir, sha1, "aaa", {})
      info_a2 = Toys::Utils::GitCache::SourceInfo.new(base_dir, sha1, "bbb", {})
      info_b1 = Toys::Utils::GitCache::SourceInfo.new(base_dir, sha2, "aaa", {})
      assert(info_a1 < info_a2)
      assert(info_a2 < info_b1)
      assert(info_a1 < info_b1)
    end

    it "sorts an array of SourceInfo by sha then git_path" do
      sha1 = "a" * 40
      sha2 = "b" * 40
      info_a2 = Toys::Utils::GitCache::SourceInfo.new(base_dir, sha1, "bbb", {})
      info_b1 = Toys::Utils::GitCache::SourceInfo.new(base_dir, sha2, "aaa", {})
      info_a1 = Toys::Utils::GitCache::SourceInfo.new(base_dir, sha1, "aaa", {})
      sorted = [info_a2, info_b1, info_a1].sort
      assert_equal([[sha1, "aaa"], [sha1, "bbb"], [sha2, "aaa"]],
                   sorted.map { |s| [s.sha, s.git_path] })
    end
  end

  describe "with github_integration" do
    let(:toys_repo) { "dazuma/toys" }
    let(:toys_remote) { "https://github.com/#{toys_repo}.git" }
    let(:toys_core_examples_path) { "toys-core/examples" }

    before do
      skip "Skipped integration test" unless ENV["TOYS_TEST_INTEGRATION"]
    end

    it "gets toys-core examples from a branch" do
      branch = "main"
      dir = git_cache.get(toys_remote, path: toys_core_examples_path, commit: branch)
      readme_content = File.read(File.join(dir, "simple-gem", "README.md"))
      expected_url = URI("https://raw.githubusercontent.com/#{toys_repo}/#{branch}/#{toys_core_examples_path}/simple-gem/README.md")
      expected_content = Net::HTTP.get(expected_url)
      assert_equal(expected_content, readme_content)
    end

    it "gets toys-core examples from a sha" do
      sha = "590d7cc51beb4d905e93a10eb1a25c221877f81a"
      dir = git_cache.get(toys_remote, path: toys_core_examples_path, commit: sha)
      readme_content = File.read(File.join(dir, "simple-gem", "README.md"))
      expected_url = URI("https://raw.githubusercontent.com/#{toys_repo}/#{sha}/#{toys_core_examples_path}/simple-gem/README.md")
      expected_content = Net::HTTP.get(expected_url)
      assert_equal(expected_content, readme_content)
    end

    it "gets toys-core examples from a tag" do
      tag = "toys-core/v0.11.5"
      dir = git_cache.get(toys_remote, path: toys_core_examples_path, commit: tag)
      readme_content = File.read(File.join(dir, "simple-gem", "README.md"))
      expected_url = URI("https://raw.githubusercontent.com/#{toys_repo}/#{tag}/#{toys_core_examples_path}/simple-gem/README.md")
      expected_content = Net::HTTP.get(expected_url)
      assert_equal(expected_content, readme_content)
    end

    it "gets toys-core examples from HEAD" do
      dir = git_cache.get(toys_remote, path: toys_core_examples_path)
      readme_content = File.read(File.join(dir, "simple-gem", "README.md"))
      expected_url = URI("https://raw.githubusercontent.com/#{toys_repo}/HEAD/#{toys_core_examples_path}/simple-gem/README.md")
      expected_content = Net::HTTP.get(expected_url)
      assert_equal(expected_content, readme_content)
    end
  end
end
