require "psych"
require "toys/utils/exec"
require "toys/utils/git_cache"

describe "toys system git-cache" do
  include Toys::Testing

  toys_custom_paths(File.dirname(File.dirname(__dir__)))
  toys_include_builtins(false)

  let(:cache_dir) { File.join(Dir.tmpdir, "toys_git_cache_test") }
  let(:git_cache) { Toys::Utils::GitCache.new(cache_dir: cache_dir) }
  let(:git_repo_dir) { File.join(Dir.tmpdir, "toys_git_cache_test2") }
  let(:exec_util) { Toys::Utils::Exec.new }
  let(:local_remote) { File.join(git_repo_dir, ".git") }
  let(:timestamp1) { 123456789 }
  let(:timestamp2) { 123456798 }

  def exec_git(*args)
    result = exec_util.exec(["git"] + args, out: :capture, err: :null)
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

  def capture_git_cache_output(cmd, format: nil)
    cmd = ["system", "git-cache"] + cmd + ["--cache-dir", cache_dir]
    cmd += ["--format", format] if format
    out = toys_exec_tool(cmd).captured_out
    case format
    when nil, "yaml"
      assert_match(/^---/, out)
      ::Psych.load(out)
    when "json"
      assert_match(/^\{\n/, out)
      ::JSON.parse(out)
    when "json-compact"
      assert_match(/^\{\S/, out)
      ::JSON.parse(out)
    else
      flunk("Unrecognized format: #{format}")
    end
  end

  def capture_assert_git_cache_error(cmd)
    cmd = ["system", "git-cache"] + cmd + ["--cache-dir", cache_dir]
    result = toys_exec_tool(cmd)
    refute(result.success?)
    result.captured_err
  end

  before do
    skip unless Toys::Compat.allow_fork?
    FileUtils.chmod_R("u+w", cache_dir, force: true)
    FileUtils.rm_rf(cache_dir)
    FileUtils.rm_rf(git_repo_dir)
    FileUtils.mkdir_p(git_repo_dir)
    Dir.chdir(git_repo_dir) do
      exec_git("init")
    end
  end

  describe "list" do
    it "lists an empty cache" do
      output = capture_git_cache_output(["list"])
      expected = {
        "cache_dir" => cache_dir,
        "remotes" => []
      }
      assert_equal(expected, output)
    end

    it "lists an empty cache with json output" do
      output = capture_git_cache_output(["list"], format: "json")
      expected = {
        "cache_dir" => cache_dir,
        "remotes" => []
      }
      assert_equal(expected, output)
    end

    it "lists an empty cache with json-compact output" do
      output = capture_git_cache_output(["list"], format: "json-compact")
      expected = {
        "cache_dir" => cache_dir,
        "remotes" => []
      }
      assert_equal(expected, output)
    end

    it "lists cache with a single remote" do
      file_name = "file1.txt"
      commit_file(file_name)
      git_cache.get(local_remote, path: file_name)

      output = capture_git_cache_output(["list"])
      expected = {
        "cache_dir" => cache_dir,
        "remotes" => [local_remote]
      }
      assert_equal(expected, output)
    end
  end

  describe "show" do
    it "displays an error when asked for an unknown remote" do
      output = capture_assert_git_cache_error(["show", local_remote])
      assert_includes(output, "Unknown remote: #{local_remote}")
    end

    it "displays info for a local remote" do
      file_name = "file1.txt"
      commit_file(file_name)
      found_path = git_cache.get(local_remote, path: file_name, timestamp: timestamp1)
      output = capture_git_cache_output(["show", local_remote])

      assert(File.directory?(File.join(output["base_dir"], "repo")))
      assert(File.file?(File.join(output["base_dir"], "repo.lock")))
      assert_equal(local_remote, output["remote"])
      assert_equal(timestamp1, output["last_accessed"])

      assert_equal(1, output["refs"].size)
      ref_output = output["refs"].first
      assert_equal("HEAD", ref_output["ref"])
      assert_equal(timestamp1, ref_output["last_accessed"])
      assert_equal(timestamp1, ref_output["last_updated"])

      assert_equal(1, output["sources"].size)
      source_output = output["sources"].first
      assert_equal(ref_output["sha"], source_output["sha"])
      assert_equal(file_name, source_output["git_path"])
      assert_equal(found_path, source_output["source"])
      assert_equal(timestamp1, source_output["last_accessed"])
    end
  end

  describe "get" do
    it "gets repo content" do
      file_name = "file1.txt"
      content = "Hello, world!"
      commit_file(file_name, content: content)
      cmd = ["system", "git-cache", "get",
             "--cache-dir", cache_dir,
             "--path", file_name,
             local_remote]
      found_path = toys_exec_tool(cmd).captured_out.strip
      assert_equal(content, File.read(found_path).strip)
    end

    it "displays an error for an unknown remote" do
      output = capture_assert_git_cache_error(["get", "/unknown/remote"])
      assert_includes(output, "Unable to fetch commit: HEAD")
    end
  end

  describe "delete" do
    it "deletes named repos" do
      file_name = "file1.txt"
      commit_file(file_name)
      git_cache.get(local_remote)
      repo_dir = git_cache.repo_info(local_remote).base_dir
      assert(File.directory?(repo_dir))
      output = capture_git_cache_output(["remove", "/unknown/remote", local_remote])
      expected = {
        "removed" => [local_remote]
      }
      assert_equal(expected, output)
      refute(File.directory?(repo_dir))
    end

    it "deletes all repos" do
      file_name = "file1.txt"
      commit_file(file_name)
      git_cache.get(local_remote)
      repo_dir = git_cache.repo_info(local_remote).base_dir
      assert(File.directory?(repo_dir))
      output = capture_git_cache_output(["remove", "--all"])
      expected = {
        "removed" => [local_remote]
      }
      assert_equal(expected, output)
      refute(File.directory?(repo_dir))
    end
  end

  describe "remove-refs" do
    it "removes specific refs" do
      file_name = "file1.txt"
      updated_content = "updated"
      commit_file(file_name)
      found_path = git_cache.get(local_remote, path: file_name)
      assert_equal(file_name, File.read(found_path).strip)

      commit_file(file_name, content: updated_content)
      found_path1 = git_cache.get(local_remote, path: file_name)
      assert_equal(found_path, found_path1)
      assert_equal(file_name, File.read(found_path1).strip)

      output = capture_git_cache_output(
        ["remove-refs", local_remote, "--ref", "mybranch", "--ref", "HEAD"]
      )
      assert_equal(1, output["removed_refs"].size)
      assert_equal("HEAD", output["removed_refs"].first["ref"])

      found_path2 = git_cache.get(local_remote, path: file_name)
      refute_equal(found_path, found_path2)
      assert_equal(updated_content, File.read(found_path2).strip)
    end

    it "removes all refs" do
      file_name = "file1.txt"
      updated_content = "updated"
      commit_file(file_name)
      found_path = git_cache.get(local_remote, path: file_name)
      assert_equal(file_name, File.read(found_path).strip)

      commit_file(file_name, content: updated_content)
      found_path1 = git_cache.get(local_remote, path: file_name)
      assert_equal(found_path, found_path1)
      assert_equal(file_name, File.read(found_path1).strip)

      output = capture_git_cache_output(["remove-refs", local_remote, "--all"])
      assert_equal(1, output["removed_refs"].size)
      assert_equal("HEAD", output["removed_refs"].first["ref"])

      found_path2 = git_cache.get(local_remote, path: file_name)
      refute_equal(found_path, found_path2)
      assert_equal(updated_content, File.read(found_path2).strip)
    end
  end

  describe "remove-sources" do
    it "removes sources for given commits" do
      file_name = "file1.txt"
      commit_file(file_name)
      git_cache.get(local_remote)
      found_path = git_cache.get(local_remote, path: file_name)
      assert(File.file?(found_path))

      output = capture_git_cache_output([
        "remove-sources", local_remote, "--commit", "HEAD", "--commit", "mybranch"]
      )
      assert_equal(2, output["removed_sources"].size)
      assert_equal(".", output["removed_sources"].first["git_path"])
      assert_equal(file_name, output["removed_sources"].last["git_path"])
      refute(File.file?(found_path))
    end

    it "removes sources for all commits" do
      file_name = "file1.txt"
      commit_file(file_name)
      git_cache.get(local_remote)
      found_path = git_cache.get(local_remote, path: file_name)
      assert(File.file?(found_path))

      output = capture_git_cache_output([
        "remove-sources", local_remote, "--all"]
      )
      assert_equal(2, output["removed_sources"].size)
      assert_equal(".", output["removed_sources"].first["git_path"])
      assert_equal(file_name, output["removed_sources"].last["git_path"])
      refute(File.file?(found_path))
    end
  end
end
