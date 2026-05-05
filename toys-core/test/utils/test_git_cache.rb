# frozen_string_literal: true

require "helper"
require "toys/utils/exec"
require "toys/utils/git_cache"
require "digest"
require "fileutils"

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
    let(:git_repo_dir) { File.join(Dir.tmpdir, "toys_git_cache_test3") }
    let(:local_remote) { File.join(git_repo_dir, ".git") }
    let(:cache_dir) { File.join(Dir.tmpdir, "toys_git_cache_test") }
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
      FileUtils.chmod_R("u+w", cache_dir, force: true)
      FileUtils.rm_rf(cache_dir)
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
