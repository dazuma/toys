# frozen_string_literal: true

require "toys/utils/exec"
require "toys/utils/git_cache"
require "fileutils"
require "tmpdir"

describe "toys do" do
  include Toys::Testing

  toys_custom_paths(File.dirname(__dir__))
  toys_include_builtins(false)

  it "prints help when passed --help flag" do
    out, _err = capture_subprocess_io do
      toys_run_tool(["do", "--help"])
    end
    output_lines = out.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys do - Run multiple tools in order", output_lines[1])
  end

  it "passes flags to the running tool" do
    out, _err = capture_subprocess_io do
      toys_run_tool(["do", "system", "version", "--help"])
    end
    output_lines = out.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys system version - Print the current Toys version", output_lines[1])
  end

  it "does nothing when passed no arguments" do
    out, _err = capture_subprocess_io do
      toys_run_tool(["do"])
    end
    assert_equal("", out)
  end

  it "executes multiple tools" do
    out, _err = capture_subprocess_io do
      toys_run_tool(["do", "system", "version", ",", "system"])
    end
    output_lines = out.split("\n")
    assert_equal(Toys::VERSION, output_lines[0])
    assert_equal("NAME", output_lines[1])
    assert_equal("    toys system - A set of system commands for Toys", output_lines[2])
  end
end

describe "toys do --gem" do
  include Toys::Testing

  # The base source provides "base-tool" and "shared-tool", alongside the
  # builtin tools.
  toys_custom_paths([File.dirname(__dir__),
                     File.expand_path("../../test-data/source-cases/base", __dir__)])
  toys_include_builtins(false)

  # None of the gems available to these tests carry a toys directory, so we
  # point rubygems at the fixtures under test-data/source-cases/gem-home.
  # That directory is laid out the way rubygems expects a gem home to look, so
  # adding it to the gem path is enough for rubygems to discover the gemspecs
  # under "specifications" and resolve each gem directory under "gems", where
  # the tools are found in the default "toys" subdirectory.
  # The "fake-tools-one" gem is present at two versions, which carry the same
  # tools except for "version-tool", so that version requirements can be tested
  # by observing which version gets selected. The "fake-no-tools" gem
  # deliberately has no toys directory at all.
  let(:gem_home_dir) {
    File.expand_path("../../test-data/source-cases/gem-home", __dir__)
  }
  let(:fake_gem_names) {
    ["fake-tools-one", "fake-tools-two", "fake-no-tools"]
  }

  before do
    # Changing the gem path resets the rubygems spec cache, so each test sees
    # fresh spec objects and a gem activated by an earlier test does not
    # conflict with a version requested by a later one.
    @original_gem_home = Gem.dir
    @original_gem_path = Gem.path.dup
    Gem.use_paths(@original_gem_home, @original_gem_path + [gem_home_dir])
  end

  after do
    Gem.use_paths(@original_gem_home, @original_gem_path)
    fake_gem_names.each { |gem_name| Gem.loaded_specs.delete(gem_name) }
  end

  it "runs a tool from the given gem" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--gem=fake-tools-one", "one-tool"]))
    end
    assert_equal(["fake-tools-one one-tool"], out.split("\n"))
  end

  it "still runs tools from the original sources" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--gem=fake-tools-one", "one-tool", ",", "base-tool",
                                     ",", "system", "version"]))
    end
    assert_equal(["fake-tools-one one-tool", "base base-tool", Toys::VERSION], out.split("\n"))
  end

  it "gives the gem priority over the original sources" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "shared-tool"]))
      assert_equal(0, toys_run_tool(["do", "--gem=fake-tools-one", "shared-tool"]))
    end
    assert_equal(["base shared-tool", "fake-tools-one shared-tool"], out.split("\n"))
  end

  it "runs tools from multiple gems" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--gem=fake-tools-one", "--gem=fake-tools-two",
                                     "one-tool", ",", "two-tool"]))
    end
    assert_equal(["fake-tools-one one-tool", "fake-tools-two two-tool"], out.split("\n"))
  end

  it "gives an earlier gem priority over a later gem" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--gem=fake-tools-one", "--gem=fake-tools-two",
                                     "shared-tool"]))
      assert_equal(0, toys_run_tool(["do", "--gem=fake-tools-two", "--gem=fake-tools-one",
                                     "shared-tool"]))
    end
    assert_equal(["fake-tools-one shared-tool", "fake-tools-two shared-tool"], out.split("\n"))
  end

  it "stops on a nonzero exit code" do
    out, _err = capture_subprocess_io do
      refute_equal(0, toys_run_tool(["do", "--gem=fake-tools-one", "one-tool",
                                     ",", "nonexistent-tool", ",", "base-tool"]))
    end
    assert_equal(["fake-tools-one one-tool"], out.split("\n"))
  end

  it "selects the newest version when no version requirement is given" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--gem=fake-tools-one", "version-tool"]))
    end
    assert_equal(["fake-tools-one 2.0.0"], out.split("\n"))
  end

  it "honors a version requirement" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--gem=fake-tools-one,~> 1.0", "version-tool"]))
    end
    assert_equal(["fake-tools-one 1.0.0"], out.split("\n"))
  end

  it "honors multiple version requirements" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--gem=fake-tools-one,>= 1.0,< 2.0", "version-tool"]))
    end
    assert_equal(["fake-tools-one 1.0.0"], out.split("\n"))
  end

  it "ignores whitespace around the gem name and version requirements" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--gem=  fake-tools-one , ~> 1.0 ", "version-tool"]))
    end
    assert_equal(["fake-tools-one 1.0.0"], out.split("\n"))
  end

  it "accepts version requirements without whitespace after the operator" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--gem=fake-tools-one,~>1.0", "version-tool"]))
    end
    assert_equal(["fake-tools-one 1.0.0"], out.split("\n"))
  end

  it "reports an invalid version requirement without a stack trace" do
    out, err = capture_subprocess_io do
      refute_equal(0, toys_run_tool(["do", "--gem=fake-tools-one,nonsense", "version-tool"]))
    end
    assert_equal("", out)
    assert_match(/Invalid version requirement for gem "fake-tools-one"/, err)
    refute_match(/toys-core\/lib/, err)
  end

  it "rejects an empty version requirement" do
    _out, err = capture_subprocess_io do
      refute_equal(0, toys_run_tool(["do", "--gem=fake-tools-one,", "version-tool"]))
    end
    assert_match(/Invalid --gem value/, err)
  end

  it "rejects an empty gem name" do
    _out, err = capture_subprocess_io do
      refute_equal(0, toys_run_tool(["do", "--gem=,>= 1.0", "version-tool"]))
    end
    assert_match(/Invalid --gem value/, err)
  end

  it "reports a gem with no toys directory without a stack trace" do
    out, err = capture_subprocess_io do
      refute_equal(0, toys_run_tool(["do", "--gem=fake-no-tools", "base-tool"]))
    end
    assert_equal("", out)
    assert_match(/Cannot load tools from gem "fake-no-tools"/, err)
    refute_match(/toys-core\/lib/, err)
  end

  it "reports an invalid version requirement for the first offending gem" do
    _out, err = capture_subprocess_io do
      refute_equal(0, toys_run_tool(["do", "--gem=fake-tools-one,nonsense",
                                     "--gem=fake-tools-two,alsononsense", "version-tool"]))
    end
    assert_match(/Invalid version requirement for gem "fake-tools-one"/, err)
    refute_match(/fake-tools-two/, err)
  end

  it "does not activate later gems when an earlier gem is invalid" do
    capture_subprocess_io do
      refute_equal(0, toys_run_tool(["do", "--gem=fake-tools-one,nonsense",
                                     "--gem=fake-tools-two", "version-tool"]))
    end
    refute(Gem.loaded_specs.key?("fake-tools-two"))
  end

  it "does not activate gems when a later path is invalid" do
    missing_path = File.expand_path("../../test-data/source-cases/nonexistent", __dir__)
    _out, err = capture_subprocess_io do
      refute_equal(0, toys_run_tool(["do", "--gem=fake-tools-two", "--path=#{missing_path}",
                                     "base-tool"]))
    end
    assert_match(/Cannot load tools from path/, err)
    refute(Gem.loaded_specs.key?("fake-tools-two"))
  end

  it "reuses the original cli when no gem is requested" do
    toys_load_tool(["do"]) do |context|
      assert_same(context.cli, context.build_cli)
    end
  end

  it "builds a new cli when a gem is requested" do
    toys_load_tool(["do", "--gem=fake-tools-one"]) do |context|
      refute_same(context.cli, context.build_cli)
    end
  end
end

describe "toys do --path" do
  include Toys::Testing

  # The base source provides "base-tool" and "shared-tool", alongside the
  # builtin tools.
  toys_custom_paths([File.dirname(__dir__),
                     File.expand_path("../../test-data/source-cases/base", __dir__)])
  toys_include_builtins(false)

  # The path-tools fixture directory provides "path-tool" and "shared-tool",
  # and standalone.rb is a single file defining "standalone-tool", so that
  # both forms accepted by --path can be exercised.
  let(:path_tools_dir) {
    File.expand_path("../../test-data/source-cases/path-tools", __dir__)
  }
  let(:standalone_file) {
    File.expand_path("../../test-data/source-cases/standalone.rb", __dir__)
  }
  let(:not_ruby_file) {
    File.expand_path("../../test-data/source-cases/not-ruby.txt", __dir__)
  }
  let(:missing_path) {
    File.expand_path("../../test-data/source-cases/nonexistent", __dir__)
  }

  it "runs a tool from the given directory" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--path=#{path_tools_dir}", "path-tool"]))
    end
    assert_equal(["path-tools path-tool"], out.split("\n"))
  end

  it "runs a tool from a given ruby file" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--path=#{standalone_file}", "standalone-tool"]))
    end
    assert_equal(["standalone standalone-tool"], out.split("\n"))
  end

  it "still runs tools from the original sources" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--path=#{path_tools_dir}", "path-tool",
                                     ",", "base-tool"]))
    end
    assert_equal(["path-tools path-tool", "base base-tool"], out.split("\n"))
  end

  it "gives the path priority over the original sources" do
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(["do", "--path=#{path_tools_dir}", "shared-tool"]))
    end
    assert_equal(["path-tools shared-tool"], out.split("\n"))
  end

  it "rejects an empty path" do
    _out, err = capture_subprocess_io do
      refute_equal(0, toys_run_tool(["do", "--path=", "base-tool"]))
    end
    assert_match(/Invalid --path value: ""/, err)
  end

  it "rejects a whitespace-only path" do
    _out, err = capture_subprocess_io do
      refute_equal(0, toys_run_tool(["do", "--path=   ", "base-tool"]))
    end
    assert_match(/Invalid --path value/, err)
  end

  it "reports a nonexistent path without a stack trace" do
    out, err = capture_subprocess_io do
      refute_equal(0, toys_run_tool(["do", "--path=#{missing_path}", "base-tool"]))
    end
    assert_equal("", out)
    assert_match(/Cannot load tools from path "#{Regexp.escape(missing_path)}": Cannot read:/, err)
    refute_match(/toys-core\/lib/, err)
  end

  it "reports a file that is not a ruby file without a stack trace" do
    out, err = capture_subprocess_io do
      refute_equal(0, toys_run_tool(["do", "--path=#{not_ruby_file}", "base-tool"]))
    end
    assert_equal("", out)
    assert_match(/Cannot load tools from path .*: File is not a ruby file:/, err)
    refute_match(/toys-core\/lib/, err)
  end

  it "builds a new cli when a path is requested" do
    toys_load_tool(["do", "--path=#{path_tools_dir}"]) do |context|
      refute_same(context.cli, context.build_cli)
    end
  end
end

describe "toys do --git" do
  include Toys::Testing

  # The base source provides "base-tool" and "shared-tool", alongside the
  # builtin tools. Every test in this block passes its own CLI explicitly, so
  # these paths matter only as a fallback.
  toys_custom_paths([File.dirname(__dir__),
                     File.expand_path("../../test-data/source-cases/base", __dir__)])
  toys_include_builtins(false)

  let(:exec_tool) { Toys::Utils::Exec.new }
  # Each test gets its own temp directory, so no test can see cache or repo
  # state left behind by another, whether in this suite or elsewhere.
  let(:tmp_dir) { Dir.mktmpdir("toys_do_git_test") }
  let(:git_repo_dir) { File.join(tmp_dir, "repo") }
  let(:local_remote) { File.join(git_repo_dir, ".git") }
  let(:cache_dir) { File.join(tmp_dir, "cache") }
  let(:xdg_cache_home) { File.join(tmp_dir, "xdg-cache") }
  let(:base_dir) { File.expand_path("../../test-data/source-cases/base", __dir__) }

  # A CLI carrying a git cache rooted in this test's temp directory, so that
  # the git sources these tests add never touch the user's real cache. The
  # child CLI that "do" builds inherits the cache along with the source list.
  let(:custom_cli) {
    git_cache = Toys::Utils::GitCache.new(cache_dir: cache_dir)
    source_list = Toys::SourceList.new(git_cache: git_cache)
    Toys::StandardCLI.new(custom_paths: [File.dirname(__dir__), base_dir],
                          include_builtins: false,
                          source_list: source_list)
  }

  def exec_git(*args)
    result = exec_tool.exec(["git"] + args, out: :capture, err: :null)
    assert(result.success?, "Git failed: #{args}")
    result.captured_out
  end

  def commit_file(name, content)
    Dir.chdir(git_repo_dir) do
      dir = File.dirname(name)
      FileUtils.mkdir_p(dir) unless dir == "."
      File.open(name, "w") { |file| file.puts(content) }
      exec_git("add", name)
      exec_git("commit", "-m", "Write file #{name}")
    end
  end

  def tool_file(text)
    "# frozen_string_literal: true\n\ndef run\n  puts \"#{text}\"\nend\n"
  end

  def run_do(*args, cli: nil)
    toys_run_tool(["do"] + args, cli: cli || custom_cli)
  end

  before do
    FileUtils.mkdir_p(git_repo_dir)
    Dir.chdir(git_repo_dir) do
      exec_git("init")
    end
    commit_file("git-tool.rb", tool_file("git git-tool"))
    commit_file("shared-tool.rb", tool_file("git shared-tool"))
    commit_file("subdir/sub-tool.rb", tool_file("git sub-tool"))
    commit_file("standalone.rb",
                "# frozen_string_literal: true\n\n" \
                "tool \"git-standalone-tool\" do\n" \
                "  def run\n    puts \"git standalone-tool\"\n  end\nend\n")
    commit_file("version-tool.rb", tool_file("git version 1"))
    Dir.chdir(git_repo_dir) do
      exec_git("tag", "vone")
      @first_sha = exec_git("rev-parse", "HEAD").strip
      @branch = exec_git("rev-parse", "--abbrev-ref", "HEAD").strip
    end
    commit_file("version-tool.rb", tool_file("git version 2"))
    # Belt and braces: if a source were ever resolved without the custom cache,
    # the default cache would land here rather than in the user's home.
    @old_xdg_cache_home = ENV["XDG_CACHE_HOME"]
    ENV["XDG_CACHE_HOME"] = xdg_cache_home
  end

  after do
    ENV["XDG_CACHE_HOME"] = @old_xdg_cache_home
    # Cached sources are made read-only, so restore write access before
    # removing the temp directory. Removal also races with the maintenance
    # process that git spawns detached after a fetch, in two ways. It can
    # write new pack files into a directory that rm_rf has already emptied,
    # which leaves the tree in place without raising anything. It can also
    # delete an objects directory between the moment chmod_R lists it and
    # the moment it descends into it, which raises out of the traversal
    # because `force` covers only the chmod of each entry, not the walk. So
    # swallow the walk errors, and retry until the tree is really gone.
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

  it "runs a tool from the given git remote" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}", "git-tool"))
    end
    assert_equal(["git git-tool"], out.split("\n"))
  end

  it "still runs tools from the original sources" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}", "git-tool", ",", "base-tool"))
    end
    assert_equal(["git git-tool", "base base-tool"], out.split("\n"))
  end

  it "gives the git remote priority over the original sources" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}", "shared-tool"))
    end
    assert_equal(["git shared-tool"], out.split("\n"))
  end

  it "loads a subdirectory of the repo" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}, path=subdir", "sub-tool"))
    end
    assert_equal(["git sub-tool"], out.split("\n"))
  end

  it "loads a single file of the repo" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}, path=standalone.rb", "git-standalone-tool"))
    end
    assert_equal(["git standalone-tool"], out.split("\n"))
  end

  it "ignores whitespace around the elements and the equals signs" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=  #{local_remote} ,  path =  subdir  ", "sub-tool"))
    end
    assert_equal(["git sub-tool"], out.split("\n"))
  end

  it "selects a commit by tag" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}, commit=vone", "version-tool"))
    end
    assert_equal(["git version 1"], out.split("\n"))
  end

  it "selects a commit by sha" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}, commit=#{@first_sha}", "version-tool"))
    end
    assert_equal(["git version 1"], out.split("\n"))
  end

  it "selects a commit by branch" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}, commit=#{@branch}", "version-tool"))
    end
    assert_equal(["git version 2"], out.split("\n"))
  end

  it "defaults to the head of the repo" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}", "version-tool"))
    end
    assert_equal(["git version 2"], out.split("\n"))
  end

  it "serves the cached commit when no update is requested" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}, commit=#{@branch}", "version-tool"))
      commit_file("version-tool.rb", tool_file("git version 3"))
      assert_equal(0, run_do("--git=#{local_remote}, commit=#{@branch}", "version-tool"))
    end
    assert_equal(["git version 2", "git version 2"], out.split("\n"))
  end

  it "refetches when update is true" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}, commit=#{@branch}", "version-tool"))
      commit_file("version-tool.rb", tool_file("git version 3"))
      assert_equal(0, run_do("--git=#{local_remote}, commit=#{@branch}, update=true",
                             "version-tool"))
    end
    assert_equal(["git version 2", "git version 3"], out.split("\n"))
  end

  it "serves the cached commit when update is false" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}, commit=#{@branch}", "version-tool"))
      commit_file("version-tool.rb", tool_file("git version 3"))
      assert_equal(0, run_do("--git=#{local_remote}, commit=#{@branch}, update=false",
                             "version-tool"))
    end
    assert_equal(["git version 2", "git version 2"], out.split("\n"))
  end

  it "refetches when update is zero seconds" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}, commit=#{@branch}", "version-tool"))
      commit_file("version-tool.rb", tool_file("git version 3"))
      assert_equal(0, run_do("--git=#{local_remote}, commit=#{@branch}, update=0", "version-tool"))
    end
    assert_equal(["git version 2", "git version 3"], out.split("\n"))
  end

  it "does not refetch when update is a long interval" do
    out, _err = capture_subprocess_io do
      assert_equal(0, run_do("--git=#{local_remote}, commit=#{@branch}", "version-tool"))
      commit_file("version-tool.rb", tool_file("git version 3"))
      assert_equal(0, run_do("--git=#{local_remote}, commit=#{@branch}, update=1000000",
                             "version-tool"))
    end
    assert_equal(["git version 2", "git version 2"], out.split("\n"))
  end

  it "reports an unreachable git remote without a stack trace" do
    out, err = capture_subprocess_io do
      refute_equal(0, run_do("--git=#{File.join(tmp_dir, 'nonexistent')}", "base-tool"))
    end
    assert_equal("", out)
    assert_match(/Cannot load tools from git remote /, err)
    refute_match(/toys-core\/lib/, err)
  end

  # A path naming a file that is not a ruby file stands in for the general
  # case of a repo path that carries no tools. (A path that is not in the repo
  # at all would be the more obvious case, but as of this writing it trips an
  # unrelated bug in the vendored git cache library, which raises its own error
  # class with too few arguments.)
  it "reports a repo path with no tools without a stack trace" do
    commit_file("notes.txt", "Not a ruby file")
    out, err = capture_subprocess_io do
      refute_equal(0, run_do("--git=#{local_remote}, path=notes.txt", "base-tool"))
    end
    assert_equal("", out)
    assert_match(/Cannot load tools from git remote "#{Regexp.escape(local_remote)}"/, err)
    refute_match(/toys-core\/lib/, err)
  end

  it "rejects an empty git value" do
    _out, err = capture_subprocess_io do
      refute_equal(0, run_do("--git=", "base-tool"))
    end
    assert_match(/Invalid --git value: ""/, err)
  end

  it "rejects an element that is not a key-value pair" do
    _out, err = capture_subprocess_io do
      refute_equal(0, run_do("--git=#{local_remote}, subdir", "base-tool"))
    end
    assert_match(/Invalid --git value/, err)
    assert_match(/"subdir"/, err)
  end

  it "rejects an unrecognized key" do
    _out, err = capture_subprocess_io do
      refute_equal(0, run_do("--git=#{local_remote}, ref=vone", "base-tool"))
    end
    assert_match(/Invalid --git value/, err)
    assert_match(/"ref"/, err)
  end

  it "rejects a duplicate key" do
    _out, err = capture_subprocess_io do
      refute_equal(0, run_do("--git=#{local_remote}, path=subdir, path=subdir", "base-tool"))
    end
    assert_match(/Invalid --git value/, err)
    assert_match(/"path"/, err)
  end

  it "rejects an empty value for a key" do
    _out, err = capture_subprocess_io do
      refute_equal(0, run_do("--git=#{local_remote}, path=", "base-tool"))
    end
    assert_match(/Invalid --git value/, err)
    assert_match(/"path"/, err)
  end

  it "rejects an update value that is not a boolean or a number" do
    _out, err = capture_subprocess_io do
      refute_equal(0, run_do("--git=#{local_remote}, update=sometimes", "base-tool"))
    end
    assert_match(/Invalid --git value/, err)
    assert_match(/"sometimes"/, err)
  end

  it "rejects a negative update value" do
    _out, err = capture_subprocess_io do
      refute_equal(0, run_do("--git=#{local_remote}, update=-1", "base-tool"))
    end
    assert_match(/Invalid --git value/, err)
  end

  it "builds a new cli when a git source is requested" do
    toys_load_tool(["do", "--git=#{local_remote}"], cli: custom_cli) do |context|
      refute_same(context.cli, context.build_cli)
    end
  end
end
