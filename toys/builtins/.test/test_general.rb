describe "toys" do
  include Toys::Testing

  toys_custom_paths(File.dirname(__dir__))
  toys_include_builtins(false)

  it "prints general help" do
    out, _err = capture_subprocess_io do
      toys_run_tool([])
    end
    output_lines = out.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys - Your personal command line tool", output_lines[1])
  end

  it "prints toys version when passed --version flag" do
    out, _err = capture_subprocess_io do
      toys_run_tool(["--version"])
    end
    assert_equal(Toys::VERSION, out.strip)
  end

  it "supports arguments to --help" do
    out, _err = capture_subprocess_io do
      toys_run_tool(["--help", "system", "version"])
    end
    output_lines = out.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys system version - Print the current Toys version", output_lines[1])
  end

  it "displays alternative suggestions for misspelled tool" do
    skip unless Toys::Compat.supports_suggestions?
    _out, err = capture_subprocess_io do
      toys_run_tool(["system", "versiom"])
    end
    output_lines = err.split("\n")
    assert_equal('Tool not found: "system versiom"', output_lines[0])
    assert_equal("Did you mean...  version", output_lines[1])
  end

  it "displays alternative suggestions for misspelled flag" do
    skip unless Toys::Compat.supports_suggestions?
    _out, err = capture_subprocess_io do
      toys_run_tool(["--helf"])
    end
    output_lines = err.split("\n")
    assert_equal('Flag "--helf" is not recognized.', output_lines[0])
    assert_equal("Did you mean...  --help", output_lines[1])
  end
end
