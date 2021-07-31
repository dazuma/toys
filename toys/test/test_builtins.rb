# frozen_string_literal: true

require "helper"

describe "toys" do
  it "prints general help" do
    output = Toys::TestHelper.capture_toys.split("\n")
    assert_equal("NAME", output[0])
    assert_equal("    toys - Your personal command line tool", output[1])
  end

  it "prints toys version when passed --version flag" do
    output = Toys::TestHelper.capture_toys("--version")
    assert_equal(Toys::VERSION, output.strip)
  end

  it "supports arguments to --help" do
    output = Toys::TestHelper.capture_toys("--help", "system", "version").split("\n")
    assert_equal("NAME", output[0])
    assert_equal("    toys system version - Print the current Toys version", output[1])
  end

  it "displays alternative suggestions for misspelled tool" do
    skip unless Toys::Compat.supports_suggestions?
    output = Toys::TestHelper.capture_toys("system", "versiom", stream: :err).split("\n")
    assert_equal('Tool not found: "system versiom"', output[0])
    assert_equal("Did you mean...  version", output[1])
  end

  it "displays alternative suggestions for misspelled flag" do
    skip unless Toys::Compat.supports_suggestions?
    output = Toys::TestHelper.capture_toys("--helf", stream: :err).split("\n")
    assert_equal('Flag "--helf" is not recognized.', output[0])
    assert_equal("Did you mean...  --help", output[1])
  end

  describe "system" do
    it "prints help" do
      output = Toys::TestHelper.capture_toys("system").split("\n")
      assert_equal("NAME", output[0])
      assert_equal("    toys system - A set of system commands for Toys", output[1])
    end

    describe "version" do
      it "prints the system version" do
        output = Toys::TestHelper.capture_toys("system", "version")
        assert_equal(Toys::VERSION, output.strip)
      end

      it "prints the system version using period as delimiter" do
        output = Toys::TestHelper.capture_toys("system.version")
        assert_equal(Toys::VERSION, output.strip)
      end

      it "prints the system version using colon as delimiter" do
        output = Toys::TestHelper.capture_toys("system:version")
        assert_equal(Toys::VERSION, output.strip)
      end

      it "prints help when passed --help flag" do
        output = Toys::TestHelper.capture_toys("system", "version", "--help").split("\n")
        assert_equal("NAME", output[0])
        assert_equal("    toys system version - Print the current Toys version", output[1])
      end
    end

    describe "bash-completion" do
      describe "install" do
        it "sources the completion script file" do
          output = Toys::TestHelper.capture_toys("system", "bash-completion", "install")
          assert_match(%r{^source .*/share/bash-completion\.sh toys$}, output)
        end

        it "sources the completion script file with an alias name" do
          output = Toys::TestHelper.capture_toys("system", "bash-completion", "install", "myalias")
          assert_match(%r{^source .*/share/bash-completion\.sh myalias$}, output)
        end
      end

      describe "remove" do
        it "sources the completion script file" do
          output = Toys::TestHelper.capture_toys("system", "bash-completion", "remove")
          assert_match(%r{^source .*/share/bash-completion-remove\.sh toys$}, output)
        end

        it "sources the completion script file with an alias name" do
          output = Toys::TestHelper.capture_toys("system", "bash-completion", "remove", "myalias")
          assert_match(%r{^source .*/share/bash-completion-remove\.sh myalias$}, output)
        end
      end

      describe "eval" do
        it "completes toys " do
          completions = Toys::TestHelper.capture_completion("toys ")
          assert_includes(completions, "system ")
          assert_includes(completions, "--help ")
          assert_includes(completions, "-v ")
        end

        it "completes toys system ver" do
          completions = Toys::TestHelper.capture_completion("toys system ver")
          assert_equal(["version "], completions)
        end

        it "completes toys --ver" do
          completions = Toys::TestHelper.capture_completion("toys --ver")
          assert_equal(["--verbose ", "--version "], completions)
        end

        it "completes toys do system --help , system bash" do
          completions = Toys::TestHelper.capture_completion("toys do system --help , system bash")
          assert_equal(["bash-completion "], completions)
        end

        it "completes toys do " do
          completions = Toys::TestHelper.capture_completion("toys do ")
          assert_includes(completions, "system ")
          assert_includes(completions, "do ")
          assert_includes(completions, "--help ")
          assert_includes(completions, "-v ")
          assert_includes(completions, "--delim ")
          refute_includes(completions, "--recursive ")
        end

        it "completes toys do do " do
          completions = Toys::TestHelper.capture_completion("toys do do ")
          assert_includes(completions, "system ")
          assert_includes(completions, "do ")
          assert_includes(completions, "--help ")
          assert_includes(completions, "-v ")
          assert_includes(completions, "--delim ")
          refute_includes(completions, "--recursive ")
        end
      end
    end

    describe "test" do
      let(:builtins_dir) { File.join(File.dirname(__dir__), "builtins") }

      it "runs for the given tool path" do
        output = Toys::TestHelper.capture_toys("system", "test",
                                               "-d", builtins_dir,
                                               "--no-recursive",
                                               "-t", "system")
        assert_match(/0 failures, 0 errors, 0 skips/, output)
      end

      it "runs recursively" do
        output = Toys::TestHelper.capture_toys("system", "test",
                                               "-d", builtins_dir)
        assert_match(/0 failures, 0 errors, 0 skips/, output)
      end

      it "honors --no-recursive" do
        output = Toys::TestHelper.capture_toys("system", "test",
                                               "-d", builtins_dir,
                                               "--no-recursive",
                                               stream: :err)
        assert_match(/No test files found/, output)
      end

      it "reports that the given tool has no tests" do
        output = Toys::TestHelper.capture_toys("system", "test",
                                               "-d", builtins_dir,
                                               "--no-recursive",
                                               "-t", "do",
                                               stream: :err)
        assert_match(/No such directory/, output)
      end
    end
  end

  describe "do" do
    it "prints help when passed --help flag" do
      output = Toys::TestHelper.capture_toys("do", "--help").split("\n")
      assert_equal("NAME", output[0])
      assert_equal("    toys do - Run multiple tools in order", output[1])
    end

    it "passes flags to the running tool" do
      output = Toys::TestHelper.capture_toys("do", "system", "version", "--help").split("\n")
      assert_equal("NAME", output[0])
      assert_equal("    toys system version - Print the current Toys version", output[1])
    end

    it "does nothing when passed no arguments" do
      output = Toys::TestHelper.capture_toys("do")
      assert_equal("", output)
    end

    it "executes multiple tools" do
      output = Toys::TestHelper.capture_toys("do", "system", "version", ",", "system").split("\n")
      assert_equal(Toys::VERSION, output[0])
      assert_equal("NAME", output[1])
      assert_equal("    toys system - A set of system commands for Toys", output[2])
    end
  end
end
