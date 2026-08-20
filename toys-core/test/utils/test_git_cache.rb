# frozen_string_literal: true

require "helper"
require "toys/utils/exec"
require "toys/utils/git_cache"
require "digest"
require "fileutils"
require "tmpdir"

# This is just a token set of smoke tests to ensure the library vendored
# correctly from its source in the git_cache gem. The full test suite is
# present in that gem's source.

describe Toys::Utils::GitCache do
  it "has the expected classes" do
    assert(defined?(::Toys::Utils::GitCache))
    assert(defined?(::Toys::Utils::GitCache::Error))
    assert(defined?(::Toys::Utils::GitCache::RepoInfo))
    assert(defined?(::Toys::Utils::GitCache::RefInfo))
    assert(defined?(::Toys::Utils::GitCache::SourceInfo))
    assert(defined?(::Toys::Utils::GitCache::RepoLock))
  end

  # The vendored library is generated from the git_cache gem, so a constructor
  # signature that drifts between the gem and the vendored copy would surface
  # only when a caller happened to hit it. The library raises this error with a
  # message and no exec result in several places, so pin that arity here.
  it "creates an error with no exec result" do
    error = Toys::Utils::GitCache::Error.new("whoops")
    assert_equal("whoops", error.message)
    assert_nil(error.exec_result)
  end

  it "uses the default cache dir" do
    sample_remote = "https://github.com/dazuma/toys.git"
    git_cache = Toys::Utils::GitCache.new
    expected_cache_dir = File.join(Dir.home, ".cache", "git-cache", "v1")
    assert_equal(expected_cache_dir, git_cache.cache_dir)
    expected_remote_dir = Digest::MD5.hexdigest(sample_remote)
    assert_equal(expected_remote_dir, Toys::Utils::GitCache.remote_dir_name(sample_remote))
  end

  describe "with local git" do
    let(:exec_tool) { Toys::Utils::Exec.new }
    # Each test gets its own temp directory, so no test can see cache or repo
    # state left behind by another, whether in this suite or elsewhere.
    let(:tmp_dir) { Dir.mktmpdir("toys_git_cache_test") }
    let(:git_repo_dir) { File.join(tmp_dir, "repo") }
    let(:local_remote) { File.join(git_repo_dir, ".git") }
    let(:cache_dir) { File.join(tmp_dir, "cache") }
    let(:git_cache) { Toys::Utils::GitCache.new(cache_dir: cache_dir) }

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

    before do
      FileUtils.mkdir_p(git_repo_dir)
      Dir.chdir(git_repo_dir) do
        exec_git("init")
      end
    end

    after do
      # Cached sources are made read-only, so restore write access before
      # removing the temp directory. The retry loop guards against git auto
      # maintenance, which spawns detached after a fetch and then writes into a
      # tree that rm_rf has already walked, defeating the removal silently. The
      # library stopped triggering that as of git_cache 0.1.2, which disables
      # auto maintenance on its own invocations, but the fixture repo here is
      # built with plain git commands that carry no such setting, so the loop
      # stays. Errors from the chmod walk are swallowed as well, because `force`
      # covers only the chmod of each entry, not the traversal that finds them.
      5.times do
        begin
          FileUtils.chmod_R("u+w", tmp_dir, force: true)
        rescue SystemCallError
          # Fall through to the removal attempt, then try again.
        end
        FileUtils.rm_rf(tmp_dir)
        break unless File.exist?(tmp_dir)
        sleep(0.1)
      end
    end

    it "gets local repo content from HEAD" do
      file_name = "file1.txt"
      commit_file(file_name)
      dir = git_cache.get(local_remote)
      content = File.read(File.join(dir, file_name))
      assert_equal(file_name, content.strip)
    end
  end

  describe "RepoInfo" do
    it "exposes base_dir and remote" do
      base_dir = "/cache/myrepo"
      data = { "remote" => "https://example.com/repo.git", "refs" => {}, "sources" => {} }
      info = Toys::Utils::GitCache::RepoInfo.new(base_dir, data)
      assert_equal(base_dir, info.base_dir)
      assert_equal("https://example.com/repo.git", info.remote)
    end
  end
end
