# frozen_string_literal: true

describe "toys system zsh-completion" do
  include Toys::Testing

  toys_custom_paths(File.dirname(File.dirname(__dir__)))
  toys_include_builtins(false)

  before do
    skip "Skipped test because fork is not available" unless Toys::Compat.allow_fork?
  end

  it "prints the description" do
    result = toys_exec_tool(["system", "zsh-completion"])
    output_lines = result.captured_out.split("\n")
    assert_equal("NAME", output_lines[0])
    assert_equal("    toys system zsh-completion - Zsh tab completion for Toys", output_lines[1])
  end

  describe "install" do
    it "sources the completion script file" do
      result = toys_exec_tool(["system", "zsh-completion", "install"])
      assert_match(%r{^source .*/share/zsh-completion\.sh toys$}, result.captured_out)
    end

    it "sources the completion script file with an alias name" do
      result = toys_exec_tool(["system", "zsh-completion", "install", "myalias"])
      assert_match(%r{^source .*/share/zsh-completion\.sh myalias$}, result.captured_out)
    end
  end

  describe "remove" do
    it "sources the completion script file" do
      result = toys_exec_tool(["system", "zsh-completion", "remove"])
      assert_match(%r{^source .*/share/zsh-completion-remove\.sh toys$}, result.captured_out)
    end

    it "sources the completion script file with an alias name" do
      result = toys_exec_tool(["system", "zsh-completion", "remove", "myalias"])
      assert_match(%r{^source .*/share/zsh-completion-remove\.sh myalias$}, result.captured_out)
    end
  end

  describe "eval" do
    def capture_completion(line)
      env = { "COMP_LINE" => line, "COMP_POINT" => "-1", "TOYS_DEV" => "true" }
      result = toys_exec_tool(["system", "zsh-completion", "eval"], env: env)
      result.captured_out.chomp.split("\n", -1)
    end

    def finals(lines)
      sep = lines.index("")
      refute_nil(sep, "Expected a blank separator line in output: #{lines.inspect}")
      lines[0, sep]
    end

    it "completes 'toys '" do
      f = finals(capture_completion("toys "))
      assert_includes(f, "system")
      assert_includes(f, "--help")
      assert_includes(f, "-v")
    end

    it "completes 'toys system ver'" do
      f = finals(capture_completion("toys system ver"))
      assert_equal(["version"], f)
    end

    it "completes 'toys --ver'" do
      f = finals(capture_completion("toys --ver"))
      assert_equal(["--verbose", "--version"], f)
    end

    it "completes 'toys do system --help , system bash'" do
      f = finals(capture_completion("toys do system --help , system bash"))
      assert_equal(["bash-completion"], f)
    end

    it "completes 'toys do '" do
      f = finals(capture_completion("toys do "))
      assert_includes(f, "system")
      assert_includes(f, "do")
      assert_includes(f, "--help")
      assert_includes(f, "-v")
      assert_includes(f, "--delim")
      refute_includes(f, "--recursive")
    end
  end
end
