describe "toys system bash-completion" do
  include Toys::Testing

  toys_custom_paths(File.dirname(File.dirname(__dir__)))
  toys_include_builtins(false)

  before do
    skip unless Toys::Compat.allow_fork?
  end

  it "prints the description" do
    result = toys_exec_tool(["system", "bash-completion"])
    output_lines = result.captured_out.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys system bash-completion - Bash tab completion for Toys", output_lines[1])
  end

  describe "install" do
    it "sources the completion script file" do
      result = toys_exec_tool(["system", "bash-completion", "install"])
      assert_match(%r{^source .*/share/bash-completion\.sh toys$}, result.captured_out)
    end

    it "sources the completion script file with an alias name" do
      result = toys_exec_tool(["system", "bash-completion", "install", "myalias"])
      assert_match(%r{^source .*/share/bash-completion\.sh myalias$}, result.captured_out)
    end
  end

  describe "remove" do
    it "sources the completion script file" do
      result = toys_exec_tool(["system", "bash-completion", "remove"])
      assert_match(%r{^source .*/share/bash-completion-remove\.sh toys$}, result.captured_out)
    end

    it "sources the completion script file with an alias name" do
      result = toys_exec_tool(["system", "bash-completion", "remove", "myalias"])
      assert_match(%r{^source .*/share/bash-completion-remove\.sh myalias$}, result.captured_out)
    end
  end

  describe "eval" do
    def capture_completion(line)
      env = { "COMP_LINE" => line, "COMP_POINT" => "-1", "TOYS_DEV" => "true" }
      result = toys_exec_tool(["system", "bash-completion", "eval"], env: env)
      result.captured_out.split("\n")
    end

    it "completes 'toys '" do
      completions = capture_completion("toys ")
      assert_includes(completions, "system ")
      assert_includes(completions, "--help ")
      assert_includes(completions, "-v ")
    end

    it "completes 'toys system ver'" do
      completions = capture_completion("toys system ver")
      assert_equal(["version "], completions)
    end

    it "completes 'toys --ver'" do
      completions = capture_completion("toys --ver")
      assert_equal(["--verbose ", "--version "], completions)
    end

    it "completes 'toys do system --help , system bash'" do
      completions = capture_completion("toys do system --help , system bash")
      assert_equal(["bash-completion "], completions)
    end

    it "completes 'toys do '" do
      completions = capture_completion("toys do ")
      assert_includes(completions, "system ")
      assert_includes(completions, "do ")
      assert_includes(completions, "--help ")
      assert_includes(completions, "-v ")
      assert_includes(completions, "--delim ")
      refute_includes(completions, "--recursive ")
    end

    it "completes 'toys do do '" do
      completions = capture_completion("toys do do ")
      assert_includes(completions, "system ")
      assert_includes(completions, "do ")
      assert_includes(completions, "--help ")
      assert_includes(completions, "-v ")
      assert_includes(completions, "--delim ")
      refute_includes(completions, "--recursive ")
    end
  end
end
