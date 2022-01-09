describe "toys system test" do
  include Toys::Testing

  let(:tools_dir) { File.join(__dir__, "tool-testing") }

  it "runs for the given tool path" do
    tool = ["system", "test", "-d", tools_dir, "-t", "foo"]
    output = capture_tool(tool, fallback_to_separate: true)
    assert_match(/1 runs, 1 assertions, 0 failures, 0 errors, 0 skips/, output)
  end

  it "runs recursively" do
    tool = ["system", "test", "-d", tools_dir]
    output = capture_tool(tool, fallback_to_separate: true)
    assert_match(/2 runs, 2 assertions, 0 failures, 0 errors, 0 skips/, output)
  end

  it "honors --no-recursive" do
    tool = ["system", "test", "-d", tools_dir, "--no-recursive"]
    output = capture_tool(tool, fallback_to_separate: true)
    assert_match(/1 runs, 1 assertions, 0 failures, 0 errors, 0 skips/, output)
  end

  it "reports no test files found" do
    tool = ["system", "test", "-d", tools_dir, "-t", "bar"]
    output = capture_tool(tool, fallback_to_separate: true, stream: :err)
    assert_match(/No test files found/, output)
  end

  it "reports that the given tool directory couldn't be found" do
    tool = ["system", "test", "-d", tools_dir, "-t", "baz"]
    output = capture_tool(tool, fallback_to_separate: true, stream: :err)
    assert_match(/No such directory/, output)
  end
end
