describe "toys system" do
  include Toys::Testing

  it "prints the description" do
    output = capture_tool(["system"], fallback_to_separate: true)
    output_lines = output.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys system - A set of system commands for Toys", output_lines[1])
  end

  describe "version" do
    it "prints the current version" do
      output = capture_tool(["system", "version"], fallback_to_separate: true)
      assert_equal(Toys::VERSION, output.strip)
    end

    it "prints the system version using period as delimiter" do
      output = capture_tool(["system.version"], fallback_to_separate: true)
      assert_equal(Toys::VERSION, output.strip)
    end

    it "prints the system version using colon as delimiter" do
      output = capture_tool(["system:version"], fallback_to_separate: true)
      assert_equal(Toys::VERSION, output.strip)
    end

    it "prints help when passed --help flag" do
      output = capture_tool(["system", "version", "--help"], fallback_to_separate: true)
      output_lines = output.split("\n")
      assert_equal("NAME", output_lines[0])
      assert_equal("    toys system version - Print the current Toys version", output_lines[1])
    end
  end
end
