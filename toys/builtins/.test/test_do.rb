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
