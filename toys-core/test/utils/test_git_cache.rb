# frozen_string_literal: true

require "helper"
require "toys/utils/git_cache"
require "fileutils"
require "net/http"
require "uri"

describe Toys::Utils::GitCache do
  let(:cache_dir) { File.join(Dir.tmpdir, "toys_git_cache_test") }
  let(:git_cache) { Toys::Utils::GitCache.new(cache_dir: cache_dir) }
  let(:toys_repo) { "dazuma/toys" }
  let(:toys_remote) { "https://github.com/#{toys_repo}.git" }
  let(:toys_core_examples_path) { "toys-core/examples" }

  before do
    skip unless ENV["TOYS_TEST_INTEGRATION"]
    FileUtils.rm_rf(cache_dir)
  end

  it "uses the default cache dir" do
    git_cache = Toys::Utils::GitCache.new
    expected_cache_dir = File.join(Dir.home, ".cache", "toys", "git")
    assert_equal(expected_cache_dir, git_cache.cache_dir)
    dir = git_cache.repo_dir_for(toys_remote)
    digest = Digest::MD5.hexdigest(toys_remote)
    assert_equal(File.join(expected_cache_dir, digest, "repo"), dir)
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

  it "reuses a git clone for the same remote" do
    branch = "main"
    tag = "toys-core/v0.11.5"
    git_cache.find(toys_remote, path: toys_core_examples_path, commit: branch)
    repo_path = git_cache.repo_dir_for(toys_remote)
    file_path = File.join(repo_path, "tmp.txt")
    File.open(file_path, "w") do |file|
      file.puts("hello")
    end
    sha1 = Dir.chdir(repo_path) { `git rev-parse HEAD` }
    git_cache.find(toys_remote, path: toys_core_examples_path, commit: tag)
    assert_equal("hello\n", File.read(file_path))
    sha2 = Dir.chdir(repo_path) { `git rev-parse HEAD` }
    refute_equal(sha1, sha2)
  end

  it "prevents concurrent use of the repo" do
    git_cache
    FileUtils.mkdir_p(cache_dir)
    start1 = finish1 = start2 = finish2 = nil
    thread1 = Thread.new do
      git_cache.send(:lock_repo, cache_dir) do
        start1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        sleep(0.5)
        finish1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
    thread2 = Thread.new do
      git_cache.send(:lock_repo, cache_dir) do
        start2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        sleep(0.5)
        finish2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
    thread1.join
    thread2.join
    assert(start1 >= finish2 || start2 >= finish1)
  end
end
