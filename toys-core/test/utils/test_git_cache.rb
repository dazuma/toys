# frozen_string_literal: true

require "helper"
require "toys/utils/exec"
require "toys/utils/git_cache"
require "fileutils"
require "net/http"
require "uri"

describe Toys::Utils::GitCache do
  let(:cache_dir) { File.join(Dir.tmpdir, "toys_git_cache_test") }
  let(:git_cache) { Toys::Utils::GitCache.new(cache_dir: cache_dir) }
  let(:sample_remote) { "https://github.com/dazuma/toys.git" }

  before do
    FileUtils.rm_rf(cache_dir)
  end

  it "uses the default cache dir" do
    git_cache = Toys::Utils::GitCache.new
    expected_cache_dir = File.join(Dir.home, ".cache", "toys", "git")
    assert_equal(expected_cache_dir, git_cache.cache_dir)
    dir = git_cache.repo_dir_for(sample_remote)
    digest = Digest::MD5.hexdigest(sample_remote)
    assert_equal(File.join(expected_cache_dir, digest, "repo"), dir)
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

  describe "with local_git" do
    let(:exec_tool) { Toys::Utils::Exec.new }
    let(:git_repo_dir) { File.join(Dir.tmpdir, "toys_git_cache_test2") }
    let(:local_remote) { File.join(git_repo_dir, ".git") }

    def exec_git(*args)
      result = exec_tool.exec(["git"] + args, out: :capture, err: :null)
      assert(result.success?, "Git failed: #{args}")
      result.captured_out
    end

    def commit_file(name)
      Dir.chdir(git_repo_dir) do
        File.open(name, "w") { |file| file.puts(name) }
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

    it "gets local file from HEAD" do
      file_name = "file1.txt"
      commit_file(file_name)
      dir = git_cache.find(local_remote)
      content = File.read(File.join(dir, file_name))
      assert_equal(file_name, content.strip)
    end

    it "gets with update" do
      file1_name = "file1.txt"
      file2_name = "file2.txt"
      commit_file(file1_name)
      dir1 = git_cache.find(local_remote, update: true)
      refute(File.file?(File.join(dir1, file2_name)))
      dir2 = git_cache.find(local_remote, update: true)
      assert_equal(dir1, dir2)
      commit_file(file2_name)
      dir3 = git_cache.find(local_remote, update: true)
      refute_equal(dir1, dir3)
      assert(File.file?(File.join(dir3, file2_name)))
      content = File.read(File.join(dir3, file2_name))
      assert_equal(file2_name, content.strip)
    end

    it "updates based on cache age" do
      file1_name = "file1.txt"
      file2_name = "file2.txt"
      commit_file(file1_name)
      dir1 = git_cache.find(local_remote, timestamp: 1000)
      refute(File.file?(File.join(dir1, file2_name)))
      commit_file(file2_name)
      dir2 = git_cache.find(local_remote, timestamp: 1001, update: 10)
      refute(File.file?(File.join(dir2, file2_name)))
      dir3 = git_cache.find(local_remote, timestamp: 1010, update: 10)
      assert(File.file?(File.join(dir3, file2_name)))
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

      git_cache.find(local_remote, commit: branch1)
      repo_path = git_cache.repo_dir_for(local_remote)
      file_path = File.join(repo_path, "tmp.txt")
      File.open(file_path, "w") do |file|
        file.puts("hello")
      end
      sha1 = Dir.chdir(repo_path) { `git rev-parse HEAD` }
      git_cache.find(local_remote, commit: branch2)
      assert_equal("hello\n", File.read(file_path))
      sha2 = Dir.chdir(repo_path) { `git rev-parse HEAD` }
      refute_equal(sha1, sha2)
    end
  end

  describe "with github_integration" do
    let(:toys_repo) { "dazuma/toys" }
    let(:toys_remote) { "https://github.com/#{toys_repo}.git" }
    let(:toys_core_examples_path) { "toys-core/examples" }

    before do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
    end

    it "gets toys-core examples from a branch" do
      branch = "main"
      dir = git_cache.find(toys_remote, path: toys_core_examples_path, commit: branch)
      readme_content = File.read(File.join(dir, "simple-gem", "README.md"))
      expected_url = URI("https://raw.githubusercontent.com/#{toys_repo}/#{branch}/#{toys_core_examples_path}/simple-gem/README.md")
      expected_content = Net::HTTP.get(expected_url)
      assert_equal(expected_content, readme_content)
    end

    it "gets toys-core examples from a sha" do
      sha = "590d7cc51beb4d905e93a10eb1a25c221877f81a"
      dir = git_cache.find(toys_remote, path: toys_core_examples_path, commit: sha)
      readme_content = File.read(File.join(dir, "simple-gem", "README.md"))
      expected_url = URI("https://raw.githubusercontent.com/#{toys_repo}/#{sha}/#{toys_core_examples_path}/simple-gem/README.md")
      expected_content = Net::HTTP.get(expected_url)
      assert_equal(expected_content, readme_content)
    end

    it "gets toys-core examples from a tag" do
      tag = "toys-core/v0.11.5"
      dir = git_cache.find(toys_remote, path: toys_core_examples_path, commit: tag)
      readme_content = File.read(File.join(dir, "simple-gem", "README.md"))
      expected_url = URI("https://raw.githubusercontent.com/#{toys_repo}/#{tag}/#{toys_core_examples_path}/simple-gem/README.md")
      expected_content = Net::HTTP.get(expected_url)
      assert_equal(expected_content, readme_content)
    end

    it "gets toys-core examples from HEAD" do
      dir = git_cache.find(toys_remote, path: toys_core_examples_path)
      readme_content = File.read(File.join(dir, "simple-gem", "README.md"))
      expected_url = URI("https://raw.githubusercontent.com/#{toys_repo}/HEAD/#{toys_core_examples_path}/simple-gem/README.md")
      expected_content = Net::HTTP.get(expected_url)
      assert_equal(expected_content, readme_content)
    end
  end
end
