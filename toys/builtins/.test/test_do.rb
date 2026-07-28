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
                     File.expand_path("../../test-data/gem-source-cases/base", __dir__)])
  toys_include_builtins(false)

  # None of the gems available to these tests carry a toys directory, so we
  # register a couple of synthetic gems whose gem directories are the fixtures
  # under test-data/gem-source-cases/gem-home. That directory is laid out the
  # way rubygems expects a gem home to look, so that Gem::Specification#gem_dir
  # resolves to the fixture, and each gem's tools are found in its default
  # "toys" directory.
  GEM_HOME_DIR = File.expand_path("../../test-data/gem-source-cases/gem-home", __dir__)
  FAKE_GEM_NAMES = ["fake-tools-one", "fake-tools-two"].freeze

  before do
    @fake_gem_specs = FAKE_GEM_NAMES.map do |gem_name|
      spec = Gem::Specification.new do |s|
        s.name = gem_name
        s.version = "1.0.0"
        s.summary = "Fake gem providing toys fixtures"
        s.authors = ["nobody"]
        s.require_paths = []
      end
      spec.loaded_from = File.join(GEM_HOME_DIR, "specifications", "#{gem_name}-1.0.0.gemspec")
      Gem::Specification.add_spec(spec)
      spec
    end
  end

  after do
    @fake_gem_specs.each do |spec|
      Gem::Specification.remove_spec(spec)
      Gem.loaded_specs.delete(spec.name)
    end
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
end
