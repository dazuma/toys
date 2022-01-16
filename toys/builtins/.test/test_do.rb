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
