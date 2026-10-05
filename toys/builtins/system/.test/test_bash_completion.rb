require "open3"
require "tmpdir"

describe "toys system bash-completion" do
  include Toys::Testing

  toys_custom_paths(File.dirname(File.dirname(__dir__)))
  toys_include_builtins(false)

  before do
    skip "Skipped test because fork is not available" unless Toys::Compat.allow_fork?
  end

  it "prints the description" do
    result = toys_exec_tool(["system", "bash-completion"])
    output_lines = result.captured_out.split("\n")
    assert_includes(output_lines[0], "NAME")
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

  describe "completion script" do
    let(:script_path) { File.join(File.dirname(File.dirname(File.dirname(__dir__))), "share", "bash-completion.sh") }

    before do
      skip "Skipped test because bash is not available on Windows" if Toys::Compat.windows?
    end

    # Registers completion using the real script, then runs the registered
    # command the way bash does: the -C command string with the command name,
    # current word, and previous word appended. The toys executable is a stub
    # that emits a candidate on stdout and noise on stderr.
    def run_registered_command
      Dir.mktmpdir("toys_bash_completion_test") do |dir|
        stub_path = File.join(dir, "toys")
        File.write(stub_path, "#!/bin/sh\necho \"hello \"\necho \"stderr noise\" >&2\n")
        File.chmod(0o755, stub_path)
        script = <<~BASH
          source "#{script_path}"
          eval "spec=($(complete -p toys))"
          for i in "${!spec[@]}"; do
            [[ "${spec[$i]}" == "-C" ]] && cmd="${spec[$((i + 1))]}"
          done
          eval "${cmd} toys hel toys"
        BASH
        env = { "PATH" => "#{dir}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH', '')}" }
        Open3.capture3(env, "bash", "--norc", "--noprofile", "-c", script)
      end
    end

    it "registers a command that discards stderr" do
      out, err, status = run_registered_command
      assert(status.success?)
      assert_equal("hello \n", out)
      assert_equal("", err)
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
