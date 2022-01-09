describe "toys do" do
  include Toys::Testing

  it "prints help when passed --help flag" do
    output = capture_tool(["do", "--help"], fallback_to_separate: true)
    output_lines = output.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys do - Run multiple tools in order", output_lines[1])
  end

  it "passes flags to the running tool" do
    output = capture_tool(["do", "system", "version", "--help"], fallback_to_separate: true)
    output_lines = output.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys system version - Print the current Toys version", output_lines[1])
  end

  it "does nothing when passed no arguments" do
    output = capture_tool(["do"], fallback_to_separate: true)
    assert_equal("", output)
  end

  it "executes multiple tools" do
    output = capture_tool(["do", "system", "version", ",", "system"], fallback_to_separate: true)
    output_lines = output.split("\n")
    assert_equal(Toys::VERSION, output_lines[0])
    assert_equal("NAME", output_lines[1])
    assert_equal("    toys system - A set of system commands for Toys", output_lines[2])
  end
end
