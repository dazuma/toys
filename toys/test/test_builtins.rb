# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

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
