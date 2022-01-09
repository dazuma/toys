describe "toys system bash-completion" do
  include Toys::Testing

  it "prints the description" do
    output = capture_tool(["system", "bash-completion"], fallback_to_separate: true)
    output_lines = output.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys system bash-completion - Bash tab completion for Toys", output_lines[1])
  end

  describe "install" do
    it "sources the completion script file" do
      output = capture_tool(["system", "bash-completion", "install"], fallback_to_separate: true)
      assert_match(%r{^source .*/share/bash-completion\.sh toys$}, output)
    end

    it "sources the completion script file with an alias name" do
      output = capture_tool(["system", "bash-completion", "install", "myalias"],
                            fallback_to_separate: true)
      assert_match(%r{^source .*/share/bash-completion\.sh myalias$}, output)
    end
  end

  describe "remove" do
    it "sources the completion script file" do
      output = capture_tool(["system", "bash-completion", "remove"], fallback_to_separate: true)
      assert_match(%r{^source .*/share/bash-completion-remove\.sh toys$}, output)
    end

    it "sources the completion script file with an alias name" do
      output = capture_tool(["system", "bash-completion", "remove", "myalias"],
                            fallback_to_separate: true)
      assert_match(%r{^source .*/share/bash-completion-remove\.sh myalias$}, output)
    end
  end

  describe "eval" do
    def capture_completion(line)
      env = { "COMP_LINE" => line, "COMP_POINT" => "-1", "TOYS_DEV" => "true" }
      output = capture_tool(["system", "bash-completion", "eval"],
                            fallback_to_separate: true, env: env)
      output.split("\n")
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
