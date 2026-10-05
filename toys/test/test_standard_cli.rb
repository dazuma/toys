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

  # A custom path sets no context directory of its own, so tools loaded from it
  # fall back to the working directory at run time, rather than to the
  # directory the tool files happen to live in.
  describe "custom paths" do
    # Resolve symlinks, because the context directory a tool reports comes from
    # Dir.getwd, which reports the real path.
    let(:tmp_dir) { File.realpath(Dir.mktmpdir("toys_standard_cli_test")) }
    let(:custom_path) { File.join(tmp_dir, "custom") }
    let(:other_dir) { File.join(tmp_dir, "other") }

    before do
      FileUtils.mkdir_p(custom_path)
      FileUtils.mkdir_p(other_dir)
      File.write(File.join(custom_path, "where.rb"), <<~TOOL)
        def run
          puts context_directory
        end
      TOOL
    end

    after do
      FileUtils.rm_rf(tmp_dir)
    end

    it "leaves the context directory of the loaded tools unset" do
      cli = Toys::StandardCLI.new(custom_paths: custom_path, include_builtins: false)
      tool, _remaining = cli.loader.lookup(["where"])
      assert_nil(tool.context_directory)
    end

    it "runs the loaded tools with the working directory as the context directory" do
      cli = Toys::StandardCLI.new(custom_paths: custom_path, include_builtins: false)
      out, _err = capture_subprocess_io do
        Dir.chdir(other_dir) { assert_equal(0, cli.run("where")) }
      end
      assert_equal("#{other_dir}\n", out)
    end
  end

  # The default source search, used when no custom paths are given. Every
  # location the search consults is redirected into a temp directory through
  # the environment, so the real home and config directories never take part.
  describe "default sources" do
    # Resolve symlinks, because the search compares and reports real paths.
    let(:tmp_dir) { File.realpath(Dir.mktmpdir("toys_standard_cli_test")) }
    let(:home_dir) { File.join(tmp_dir, "home") }
    let(:work_dir) { File.join(home_dir, "work") }
    let(:config_home) { File.join(tmp_dir, "config-home") }
    let(:user_dir) { File.join(config_home, "toys") }
    let(:site1_base) { File.join(tmp_dir, "site1") }
    let(:site2_base) { File.join(tmp_dir, "site2") }
    let(:site1_dir) { File.join(site1_base, "toys") }
    let(:site2_dir) { File.join(site2_base, "toys") }
    let(:load_log) { File.join(tmp_dir, "load.log") }
    let(:env_names) do
      [
        "HOME", "XDG_CONFIG_HOME", "XDG_CONFIG_DIRS", "TOYS_GLOBAL_SOURCES",
        "TOYS_PATH", "TOYS_SUPPRESS_WARNINGS"
      ]
    end

    # Writes a tool into a tool directory. The tool's description names the
    # location it came from, and loading its file appends to the load log.
    def write_tool(dir, name, label)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "#{name}.rb"), <<~TOOL)
        File.open(#{load_log.inspect}, "a") { |file| file.puts(#{label.inspect}) }
        desc #{label.inspect}
        def run; end
      TOOL
    end

    def make_cli(cur_dir: work_dir, **opts)
      cli = nil
      _out, err = capture_io do
        cli = Toys::StandardCLI.new(cur_dir: cur_dir, include_builtins: false, **opts)
      end
      @warnings = err
      cli
    end

    def tool_desc(cli, name)
      cli.loader.lookup_specific([name])&.desc.to_s
    end

    def load_count(label)
      return 0 unless File.exist?(load_log)
      File.readlines(load_log, chomp: true).count(label)
    end

    before do
      @old_env = env_names.to_h { |name| [name, ENV[name]] }
      env_names.each { |name| ENV.delete(name) }
      ENV["HOME"] = home_dir
      ENV["XDG_CONFIG_HOME"] = config_home
      ENV["XDG_CONFIG_DIRS"] = [site1_base, site2_base].join(File::PATH_SEPARATOR)
      FileUtils.mkdir_p(work_dir)
      Toys::Warnings.reset_counts
    end

    after do
      @old_env.each { |name, value| ENV[name] = value }
      Toys::Warnings.reset_counts
      FileUtils.rm_rf(tmp_dir)
    end

    describe "search order" do
      before do
        write_tool(File.join(work_dir, ".toys"), "from-walk", "walk")
        write_tool(File.join(home_dir, ".toys"), "from-home", "home")
        write_tool(user_dir, "from-user", "user")
        write_tool(site1_dir, "from-site1", "site1")
        write_tool(site2_dir, "from-site2", "site2")
      end

      it "loads the walk, home, user, and site sources" do
        cli = make_cli
        assert_equal("walk", tool_desc(cli, "from-walk"))
        assert_equal("home", tool_desc(cli, "from-home"))
        assert_equal("user", tool_desc(cli, "from-user"))
        assert_equal("site1", tool_desc(cli, "from-site1"))
        assert_equal("site2", tool_desc(cli, "from-site2"))
      end

      it "gives earlier sources priority" do
        write_tool(File.join(work_dir, ".toys"), "which1", "walk")
        write_tool(File.join(home_dir, ".toys"), "which1", "home")
        write_tool(File.join(home_dir, ".toys"), "which2", "home")
        write_tool(user_dir, "which2", "user")
        write_tool(user_dir, "which3", "user")
        write_tool(site1_dir, "which3", "site1")
        write_tool(site1_dir, "which4", "site1")
        write_tool(site2_dir, "which4", "site2")
        cli = make_cli
        assert_equal("walk", tool_desc(cli, "which1"))
        assert_equal("home", tool_desc(cli, "which2"))
        assert_equal("user", tool_desc(cli, "which3"))
        assert_equal("site1", tool_desc(cli, "which4"))
      end

      it "sets the context directory of walk and home sources but not XDG sources" do
        cli = make_cli
        assert_equal(work_dir, cli.loader.lookup_specific(["from-walk"]).context_directory)
        assert_equal(home_dir, cli.loader.lookup_specific(["from-home"]).context_directory)
        assert_nil(cli.loader.lookup_specific(["from-user"]).context_directory)
        assert_nil(cli.loader.lookup_specific(["from-site1"]).context_directory)
      end

      it "loads $HOME/.toys.rb" do
        File.write(File.join(home_dir, ".toys.rb"), "tool('from-home-file') { desc 'home file'; def run; end }\n")
        cli = make_cli
        assert_equal("home file", tool_desc(cli, "from-home-file"))
      end

      it "defaults the user directory to $HOME/.config/toys" do
        ENV.delete("XDG_CONFIG_HOME")
        write_tool(File.join(home_dir, ".config", "toys"), "from-default-user", "default user")
        cli = make_cli
        assert_equal("default user", tool_desc(cli, "from-default-user"))
        assert_equal("", tool_desc(cli, "from-user"))
      end

      it "skips directories that do not exist" do
        FileUtils.rm_rf(user_dir)
        FileUtils.rm_rf(site1_base)
        cli = make_cli
        assert_equal("home", tool_desc(cli, "from-home"))
        assert_equal("site2", tool_desc(cli, "from-site2"))
      end

      it "stops the upward walk before $HOME" do
        File.write(File.join(tmp_dir, ".toys.rb"), "tool('above-home') { def run; end }\n")
        ENV["TOYS_GLOBAL_SOURCES"] = "none"
        cli = make_cli
        assert_nil(cli.loader.lookup_specific(["above-home"]))
        assert_nil(cli.loader.lookup_specific(["from-home"]))
        assert_equal("walk", tool_desc(cli, "from-walk"))
      end
    end

    describe "TOYS_GLOBAL_SOURCES" do
      before do
        write_tool(File.join(home_dir, ".toys"), "from-home", "home")
        write_tool(user_dir, "from-user", "user")
        write_tool(site1_dir, "from-site1", "site1")
      end

      def loaded_groups(cli)
        ["home", "user", "site1"].select { |label| tool_desc(cli, "from-#{label}") == label }
      end

      it "searches all groups when unset" do
        assert_equal(["home", "user", "site1"], loaded_groups(make_cli))
      end

      it "searches all groups when empty" do
        ENV["TOYS_GLOBAL_SOURCES"] = ""
        assert_equal(["home", "user", "site1"], loaded_groups(make_cli))
      end

      it "searches only the listed groups" do
        ENV["TOYS_GLOBAL_SOURCES"] = "home,site"
        assert_equal(["home", "site1"], loaded_groups(make_cli))
        ENV["TOYS_GLOBAL_SOURCES"] = "user"
        assert_equal(["user"], loaded_groups(make_cli))
      end

      it "searches no groups when none" do
        ENV["TOYS_GLOBAL_SOURCES"] = "none"
        assert_equal([], loaded_groups(make_cli))
      end

      [
        "bogus", "HOME", "home,home", "user,home", "none,home", "home,none",
        "home, user", " home", "home,", ",home", "home,,user", ","
      ].each do |value|
        it "rejects #{value.inspect}" do
          ENV["TOYS_GLOBAL_SOURCES"] = value
          error = assert_raises(Toys::StandardCLI::InvalidGlobalSourcesError) do
            Toys::StandardCLI.new(cur_dir: work_dir, include_builtins: false)
          end
          assert_includes(error.message, value.inspect)
        end
      end

      it "defines the error as a direct subclass of StandardError" do
        assert_equal(StandardError, Toys::StandardCLI::InvalidGlobalSourcesError.superclass)
      end

      it "is not validated when custom paths are given" do
        ENV["TOYS_GLOBAL_SOURCES"] = "bogus"
        Toys::StandardCLI.new(custom_paths: work_dir, include_builtins: false)
      end
    end

    describe "inside a global tool directory" do
      before do
        write_tool(File.join(work_dir, ".toys"), "from-walk", "walk")
        write_tool(user_dir, "from-user", "user")
        write_tool(site1_dir, "from-site1", "site1")
        # Put the XDG directories under the walk, so that a walk from inside
        # them would find the work directory's tools.
        ENV["XDG_CONFIG_HOME"] = File.join(work_dir, "cfg")
        ENV["XDG_CONFIG_DIRS"] = File.join(work_dir, "sitecfg")
        FileUtils.mv(config_home, File.join(work_dir, "cfg"))
        FileUtils.mv(site1_base, File.join(work_dir, "sitecfg"))
      end

      let(:inner_user_dir) { File.join(work_dir, "cfg", "toys") }
      let(:inner_site_dir) { File.join(work_dir, "sitecfg", "toys") }

      it "skips the walk from the user directory" do
        cli = make_cli(cur_dir: inner_user_dir)
        assert_nil(cli.loader.lookup_specific(["from-walk"]))
        assert_equal("user", tool_desc(cli, "from-user"))
      end

      it "skips the walk from inside a site directory" do
        sub_dir = File.join(inner_site_dir, "sub")
        FileUtils.mkdir_p(sub_dir)
        cli = make_cli(cur_dir: sub_dir)
        assert_nil(cli.loader.lookup_specific(["from-walk"]))
        assert_equal("site1", tool_desc(cli, "from-site1"))
      end

      it "skips the walk even when the group is not selected" do
        ENV["TOYS_GLOBAL_SOURCES"] = "home"
        cli = make_cli(cur_dir: inner_user_dir)
        assert_nil(cli.loader.lookup_specific(["from-walk"]))
        assert_nil(cli.loader.lookup_specific(["from-user"]))
      end

      it "compares real paths" do
        skip "Symlinks need privileges on Windows" if Toys::Compat.windows?
        link = File.join(work_dir, "link")
        File.symlink(inner_user_dir, link)
        cli = make_cli(cur_dir: link)
        assert_nil(cli.loader.lookup_specific(["from-walk"]))
      end

      it "compares whole path components" do
        sibling = File.join(work_dir, "cfg", "toys-other")
        FileUtils.mkdir_p(sibling)
        cli = make_cli(cur_dir: sibling)
        assert_equal("walk", tool_desc(cli, "from-walk"))
      end
    end

    describe "deduplication" do
      it "loads a home directory linked to the user directory once" do
        skip "Symlinks need privileges on Windows" if Toys::Compat.windows?
        write_tool(user_dir, "shared", "user")
        File.symlink(user_dir, File.join(home_dir, ".toys"))
        cli = make_cli
        assert_equal(home_dir, cli.loader.lookup_specific(["shared"]).context_directory)
        assert_equal(1, load_count("user"))
      end

      it "does not skip a directory as a duplicate of an unselected group" do
        skip "Symlinks need privileges on Windows" if Toys::Compat.windows?
        write_tool(user_dir, "shared", "user")
        File.symlink(user_dir, File.join(home_dir, ".toys"))
        ENV["TOYS_GLOBAL_SOURCES"] = "user,site"
        cli = make_cli
        assert_nil(cli.loader.lookup_specific(["shared"]).context_directory)
        assert_equal(1, load_count("user"))
      end

      it "loads a user directory that is also a site directory once" do
        write_tool(site1_dir, "shared", "site1")
        ENV["XDG_CONFIG_HOME"] = site1_base
        cli = make_cli
        assert_equal("site1", tool_desc(cli, "shared"))
        assert_equal(1, load_count("site1"))
      end
    end

    describe "startup warnings" do
      it "warns when TOYS_PATH is set" do
        ENV["TOYS_PATH"] = tmp_dir
        make_cli
        assert_includes(@warnings, "TOYS_PATH")
        assert_includes(@warnings, "TOYS_GLOBAL_SOURCES")
      end

      it "warns about TOYS_PATH only once per process" do
        ENV["TOYS_PATH"] = tmp_dir
        make_cli
        make_cli
        assert_empty(@warnings)
      end

      it "does not warn when TOYS_PATH is empty" do
        ENV["TOYS_PATH"] = ""
        make_cli
        refute_includes(@warnings, "TOYS_PATH")
      end

      it "ignores TOYS_PATH" do
        write_tool(File.join(tmp_dir, "old", ".toys"), "from-old", "old")
        ENV["TOYS_PATH"] = File.join(tmp_dir, "old")
        cli = make_cli
        assert_nil(cli.loader.lookup_specific(["from-old"]))
      end

      it "does not warn when custom paths are given" do
        ENV["TOYS_PATH"] = tmp_dir
        _out, err = capture_io do
          Toys::StandardCLI.new(custom_paths: work_dir, include_builtins: false)
        end
        refute_includes(err, "TOYS_PATH")
      end

      # The positive case needs /etc/.toys.rb or /etc/.toys to exist, which a
      # test cannot arrange, so only the absence of a spurious warning is
      # covered here.
      it "does not warn about /etc when it has no toys files" do
        skip if File.exist?("/etc/.toys.rb") || File.exist?("/etc/.toys")
        make_cli
        refute_includes(@warnings, "/etc")
      end
    end
  end
end
