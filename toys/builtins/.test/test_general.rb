describe "toys" do
  include Toys::Testing

  it "prints general help" do
    output = capture_tool([], fallback_to_separate: true)
    output_lines = output.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys - Your personal command line tool", output_lines[1])
  end

  it "prints toys version when passed --version flag" do
    output = capture_tool(["--version"], fallback_to_separate: true)
    assert_equal(Toys::VERSION, output.strip)
  end

  it "supports arguments to --help" do
    output = capture_tool(["--help", "system", "version"], fallback_to_separate: true)
    output_lines = output.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys system version - Print the current Toys version", output_lines[1])
  end

  it "displays alternative suggestions for misspelled tool" do
    skip unless Toys::Compat.supports_suggestions?
    output = capture_tool(["system", "versiom"], fallback_to_separate: true, stream: :err)
    output_lines = output.split("\n")
    assert_equal('Tool not found: "system versiom"', output_lines[0])
    assert_equal("Did you mean...  version", output_lines[1])
  end

  it "displays alternative suggestions for misspelled flag" do
    skip unless Toys::Compat.supports_suggestions?
    output = capture_tool(["--helf"], fallback_to_separate: true, stream: :err)
    output_lines = output.split("\n")
    assert_equal('Flag "--helf" is not recognized.', output_lines[0])
    assert_equal("Did you mean...  --help", output_lines[1])
  end
end
