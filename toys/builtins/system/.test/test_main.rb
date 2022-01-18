describe "toys system" do
  include Toys::Testing

  toys_custom_paths(File.dirname(File.dirname(__dir__)))
  toys_include_builtins(false)

  it "prints the description" do
    out, _err = capture_subprocess_io do
      toys_run_tool(["system"])
    end
    output_lines = out.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys system - A set of system commands for Toys", output_lines[1])
  end

  describe "version" do
    it "prints the current version" do
      out, _err = capture_subprocess_io do
        toys_run_tool(["system", "version"])
      end
      assert_equal(Toys::VERSION, out.strip)
    end

    it "prints the system version using period as delimiter" do
      out, _err = capture_subprocess_io do
        toys_run_tool(["system.version"])
      end
      assert_equal(Toys::VERSION, out.strip)
    end

    it "prints the system version using colon as delimiter" do
      out, _err = capture_subprocess_io do
        toys_run_tool(["system:version"])
      end
      assert_equal(Toys::VERSION, out.strip)
    end

    it "prints help when passed --help flag" do
      out, _err = capture_subprocess_io do
        toys_run_tool(["system", "version", "--help"])
      end
      output_lines = out.split("\n")
      assert_equal("NAME", output_lines[0])
      assert_equal("    toys system version - Print the current Toys version", output_lines[1])
    end
  end
end
