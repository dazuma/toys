describe "toys system" do
  include Toys::Testing

  def universal_capture(cmd)
    if Toys::Compat.allow_fork?
      capture_tool(cmd)
    else
      capture_separate_tool(cmd)
    end
  end

  it "prints the description" do
    output = universal_capture(["system"])
    assert_includes(output, "A set of system commands for Toys")
  end

  describe "version" do
    it "prints the current version" do
      output = universal_capture(["system", "version"])
      assert_includes(output, Toys::VERSION)
    end
  end
end
