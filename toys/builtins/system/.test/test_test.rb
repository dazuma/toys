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
    assert_includes(out, "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips")
    assert_match(%r{Running tests under \S+/tool-testing/basic/foo/.test}, out)
  end

  it "runs recursively" do
    tool = ["system", "test", "-d", tools_dir, "-t", "basic", "-v"]
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_match(%r{Running tests under \S+/tool-testing/basic/.test}, out)
    assert_match(%r{Running tests under \S+/tool-testing/basic/foo/.test}, out)
  end

  it "honors --no-recursive" do
    tool = ["system", "test", "-d", tools_dir, "-t", "basic", "-v", "--no-recursive"]
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_match(%r{Running tests under \S+/tool-testing/basic/.test}, out)
    refute_match(%r{Running tests under \S+/tool-testing/basic/foo/.test}, out)
  end

  it "reports no test files found" do
    tool = ["system", "test", "-d", tools_dir, "-t", "basic/bar"]
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_includes(out, "No test files found")
  end

  it "reports that the given tool directory couldn't be found" do
    tool = ["system", "test", "-d", tools_dir, "-t", "baz"]
    _out, err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_includes(err, "No such directory")
  end

  it "reports failures" do
    tool = ["system", "test", "-d", tools_dir, "-t", "failing"]
    out, _err = capture_subprocess_io do
      assert_equal(1, toys_run_tool(tool))
    end
    assert_includes(out, "1 runs, 1 assertions, 1 failures, 0 errors, 0 skips")
  end

  it "supports --minitest-focus" do
    tool = ["system", "test", "--minitest-focus", "-d", tools_dir, "-t", "focus"]
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_includes(out, "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips")
  end

  it "supports --minitest-focus including version" do
    tool = ["system", "test", "--minitest-focus= > 1.4.0", "-d", tools_dir, "-t", "focus"]
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_includes(out, "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips")
  end

  it "supports --use-gem with just gem name" do
    tool = ["system", "test", "--use-gem", "minitest-focus", "-d", tools_dir, "-t", "focus"]
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_includes(out, "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips")
  end

  it "supports --use-gem including version" do
    tool = ["system", "test", "--use-gem", "minitest-focus, > 1.4.0", "-d", tools_dir, "-t", "focus"]
    out, _err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_includes(out, "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips")
  end

  it "runs specific tests" do
    test_file = File.join(tools_dir, "basic/foo/.test/test_foo.rb")
    tool = ["system", "test", "-v", "-d", tools_dir, test_file]
    out, err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_includes(out, "Running specified tests")
    refute_match(%r{Running tests under \S+/tool-testing/basic/foo/.test}, out)
    assert_includes(out, "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips")
    assert_match(%r{Reading test: \S+tool-testing/basic/foo/.test/test_foo.rb}, err)
    refute_match(%r{Reading test: \S+tool-testing/basic/.test/test_root.rb}, err)
  end

  it "runs multiple specific tests" do
    test_file1 = File.join(tools_dir, "basic/foo/.test/test_foo.rb")
    test_file2 = File.join(tools_dir, "basic/.test/test_root.rb")
    tool = ["system", "test", "-v", "-d", tools_dir, test_file1, test_file2]
    out, err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_includes(out, "Running specified tests")
    refute_match(%r{Running tests under \S+/tool-testing/basic/foo/.test}, out)
    refute_match(%r{Running tests under \S+/tool-testing/basic/.test}, out)
    assert_includes(out, "2 runs, 2 assertions, 0 failures, 0 errors, 0 skips")
    assert_match(%r{Reading test: \S+tool-testing/basic/foo/.test/test_foo.rb}, err)
    assert_match(%r{Reading test: \S+tool-testing/basic/.test/test_root.rb}, err)
  end

  it "loads bundles" do
    tool = ["system", "test", "-d", tools_dir, "-t", "bundled", "-v"]
    _out, err = capture_subprocess_io do
      # Tests would fail if the bundle wasn't loaded
      assert_equal(0, toys_run_tool(tool))
    end
    assert_match(%r{Reading test: \S+tool-testing/bundled/.test/test_focus.rb}, err)
    assert_match(%r{Reading test: \S+tool-testing/bundled/foo/.test/test_rack.rb}, err)
    assert_match(%r{Reading test: \S+tool-testing/bundled/bar/.test/test_bar.rb}, err)
  end

  it "finds tests with both *_test.rb and test_*.rb patterns" do
    tool = ["system", "test", "-d", tools_dir, "-t", "patterns", "-v"]
    _out, err = capture_subprocess_io do
      assert_equal(0, toys_run_tool(tool))
    end
    assert_match(%r{Reading test: \S+tool-testing/patterns/.test/test_foo.rb}, err)
    assert_match(%r{Reading test: \S+tool-testing/patterns/.test/bar_test.rb}, err)
    assert_equal(1, err.scan(%r{Reading test: \S+tool-testing/patterns/.test/test_hello_test.rb}).size)
  end
end
