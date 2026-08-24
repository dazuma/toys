# frozen_string_literal: true

require "helper"
require "toys/utils/exec"
require "toys/utils/git_cache"
require "fileutils"
require "tmpdir"

describe Toys::StandardCLI do
  describe "custom resolvers" do
    let(:exec_tool) { Toys::Utils::Exec.new }
    # Each test gets its own temp directory, so no test can see cache or repo
    # state left behind by another, whether in this suite or elsewhere.
    let(:tmp_dir) { Dir.mktmpdir("toys_standard_cli_test") }
    let(:git_repo_dir) { File.join(tmp_dir, "repo") }
    let(:local_remote) { File.join(git_repo_dir, ".git") }
    let(:cache_dir) { File.join(tmp_dir, "cache") }
    let(:custom_path) { File.join(tmp_dir, "custom") }
    let(:xdg_cache_home) { File.join(tmp_dir, "xdg-cache") }
    let(:default_cache_dir) { File.join(xdg_cache_home, "git-cache", "v1") }

    def exec_git(*args)
      result = exec_tool.exec(["git"] + args, out: :capture, err: :null)
      assert(result.success?, "Git failed: #{args}")
      result.captured_out
    end

    def commit_file(name, content)
      Dir.chdir(git_repo_dir) do
        File.open(name, "w") { |file| file.puts(content) }
        exec_git("add", name)
        exec_git("commit", "-m", "Add file #{name}")
      end
    end

    before do
      FileUtils.mkdir_p(git_repo_dir)
      FileUtils.mkdir_p(custom_path)
      Dir.chdir(git_repo_dir) do
        exec_git("init")
      end
      commit_file("greet.rb", "def run\n  puts 'Hello from git'\nend\n")
      @old_xdg_cache_home = ENV["XDG_CACHE_HOME"]
      ENV["XDG_CACHE_HOME"] = xdg_cache_home
    end

    after do
      ENV["XDG_CACHE_HOME"] = @old_xdg_cache_home
      # Cached sources are made read-only, so restore write access before
      # removing the temp directory. The retry loop guards against git auto
      # maintenance, which spawns detached after a fetch and then writes into a
      # tree that rm_rf has already walked, defeating the removal silently. The
      # git cache stopped triggering that as of git_cache 0.1.2, which disables
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

    it "resolves git sources using a custom git cache" do
      git_cache = Toys::Utils::GitCache.new(cache_dir: cache_dir)
      cli = Toys::StandardCLI.new(custom_paths: custom_path,
                                  include_builtins: false,
                                  git_cache: git_cache)
      cli.add_source(Toys::SourceSpec.git(local_remote))
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("greet"))
      end
      assert_includes(out, "Hello from git")
      refute_empty(Dir.children(cache_dir))
      refute(File.exist?(default_cache_dir))
    end
  end
end
