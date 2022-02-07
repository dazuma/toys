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

    it "makes source files read-only" do
      file_name = "file1.txt"
      commit_file(file_name)
      found_path = git_cache.get(local_remote, path: file_name)
      assert_raises(Errno::EACCES) do
        File.open(found_path, "w") { |file| file.puts "whoops" }
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

    it "gets a file into a specified directory" do
      file_name = "foo/bar/file1.txt"
      commit_file(file_name)
      found_path = git_cache.get(local_remote, path: file_name, into: target_dir)
      assert_equal(File.join(target_dir, file_name), found_path)
      content = File.read(found_path)
      assert_equal(file_name, content.strip)
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
      found_file_path = git_cache.get(local_remote, path: file_name)
      FileUtils.rm_rf(File.join(git_cache.repo_info(local_remote).base_dir, "repo"))
      found_file_path2 = git_cache.get(local_remote, path: file_name)
      assert_equal(found_file_path, found_file_path2)
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
      assert(repo_info.last_accessed >= time1 && repo_info.last_accessed <= time2)

      assert_equal(1, repo_info.refs.size)
      ref_info = repo_info.refs.first
      assert_equal("HEAD", ref_info.ref)
      assert(ref_info.last_accessed >= time1 && ref_info.last_accessed <= time2)
      assert(ref_info.last_updated >= time1 && ref_info.last_updated <= time2)

      assert_equal(1, repo_info.sources.size)
      source_info = repo_info.sources.first
      assert_equal(ref_info.sha, source_info.sha)
      assert_equal(file_name, source_info.git_path)
      assert_equal(found_path, source_info.source)
      assert(source_info.last_accessed >= time1 && source_info.last_accessed <= time2)
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
      assert(source_info1.last_accessed >= time1 && source_info1.last_accessed <= time2)
      assert_equal(repo_info.refs.first.sha, source_info2.sha)
      assert_equal(file_name, source_info2.git_path)
      assert_equal(found_path2, source_info2.source)
      assert(source_info2.last_accessed >= time1 && source_info2.last_accessed <= time2)
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
      assert(ref_info1.last_accessed >= time1 && ref_info1.last_accessed <= time2)
      assert(ref_info1.last_updated >= time1 && ref_info1.last_updated <= time2)
      assert_includes(found_path1, ref_info1.sha)
      assert_equal(branch2, ref_info2.ref)
      assert(ref_info2.last_accessed >= time1 && ref_info2.last_accessed <= time2)
      assert(ref_info2.last_updated >= time1 && ref_info2.last_updated <= time2)
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
