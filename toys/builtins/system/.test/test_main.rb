describe "toys system" do
  include Toys::Testing

  it "prints the description" do
    output = capture_tool(["system"])
    assert_includes(output, "A set of system commands for Toys")
  end

  describe "version" do
    it "prints the current version" do
      output = capture_tool(["system", "version"])
      assert_includes(output, Toys::VERSION)
    end
  end
end
