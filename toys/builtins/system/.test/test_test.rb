describe "toys system test" do
  include Toys::Testing

  toys_custom_paths(File.dirname(File.dirname(__dir__)))
  toys_include_builtins(false)

  let(:tools_dir) { File.join(__dir__, "tool-testing") }

  it "runs for the given tool path" do
    tool = ["system", "test", "-d", tools_dir, "-t", "basic/foo"]
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_match(/1 runs, 1 assertions, 0 failures, 0 errors, 0 skips/, out)
  end

  it "runs recursively" do
    tool = ["system", "test", "-d", tools_dir, "-t", "basic"]
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_match(/2 runs, 2 assertions, 0 failures, 0 errors, 0 skips/, out)
  end

  it "honors --no-recursive" do
    tool = ["system", "test", "-d", tools_dir, "-t", "basic", "--no-recursive"]
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_match(/1 runs, 1 assertions, 0 failures, 0 errors, 0 skips/, out)
  end

  it "reports no test files found" do
    tool = ["system", "test", "-d", tools_dir, "-t", "basic/bar"]
    _out, err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_match(/No test files found/, err)
  end

  it "reports that the given tool directory couldn't be found" do
    tool = ["system", "test", "-d", tools_dir, "-t", "baz"]
    _out, err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_match(/No such directory/, err)
  end

  it "reports failures" do
    tool = ["system", "test", "-d", tools_dir, "-t", "failing"]
    out, _err = capture_subprocess_io do
      assert_equal(1, toys_run_tool(tool))
    end
    assert_match(/1 runs, 1 assertions, 1 failures, 0 errors, 0 skips/, out)
  end

  it "honors focus" do
    tool = ["system", "test", "--minitest-focus", "-d", tools_dir, "-t", "focus"]
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_match(/1 runs, 1 assertions, 0 failures, 0 errors, 0 skips/, out)
  end
end
