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

describe Toys::Terminal do
  let(:input) { ::StringIO.new }
  let(:output) { ::StringIO.new }
  let(:terminal) { Toys::Terminal.new(input: input, output: output, styled: true) }

  describe "remove_style_escapes" do
    it "removes clear code" do
      str = Toys::Terminal.remove_style_escapes(Toys::Terminal::CLEAR_CODE)
      assert_equal("", str)
    end

    it "removes multiple sequences" do
      str = "\e[12;34mhi\e[9m"
      str = Toys::Terminal.remove_style_escapes(str)
      assert_equal("hi", str)
    end
  end

  describe "style interpretation" do
    it "interprets symbolic colors" do
      str = terminal.apply_styles("hello", :yellow)
      assert_equal("\e[33mhello\e[0m", str)
    end

    it "interprets 8*3-bit rgb colors" do
      str = terminal.apply_styles("hello", "fe126a")
      assert_equal("\e[38;2;254;18;106mhello\e[0m", str)
    end

    it "interprets 4*3-bit rgb colors" do
      str = terminal.apply_styles("hello", "05f")
      assert_equal("\e[38;2;0;85;255mhello\e[0m", str)
    end
  end

  describe "styled output" do
    it "writes and clears styles" do
      terminal.write("hello", :bold)
      assert_equal("\e[1mhello\e[0m", output.string)
    end

    it "preserves existing styles" do
      terminal.write("hel\e[3mlo", :bold)
      assert_equal("\e[1mhel\e[3mlo\e[0m", output.string)
    end

    it "does not clear when no style is present" do
      terminal.write("hello")
      assert_equal("hello", output.string)
    end

    it "defines named styles" do
      terminal.define_style(:bold_red, :bold, :red)
      terminal.write("hello", :bold_red)
      assert_equal("\e[1;31mhello\e[0m", output.string)
    end
  end

  describe "unstyled output" do
    let(:terminal) { Toys::Terminal.new(input: input, output: output, styled: false) }

    it "does not include styles" do
      terminal.write("hello", :bold)
      assert_equal("hello", output.string)
    end

    it "indeed removes existing styles" do
      terminal.write("\e[1mhello\e[0m")
      assert_equal("hello", output.string)
    end

    it "adds a newline with puts" do
      terminal.puts("hello")
      assert_equal("hello\n", output.string)
    end

    it "does not add an extra newline with puts" do
      terminal.puts("hello\n")
      assert_equal("hello\n", output.string)
    end
  end

  describe "ask" do
    it "Displays a prompt and gets a result" do
      input = StringIO.new "hello\n"
      terminal = Toys::Terminal.new(input: input, output: output)
      assert_equal("hello", terminal.ask("What? "))
      assert_equal("What? ", output.string)
    end

    it "Displays a prompt with default and gets a default result" do
      input = StringIO.new "\n"
      terminal = Toys::Terminal.new(input: input, output: output)
      assert_equal("hi", terminal.ask("What?  ", default: "hi"))
      assert_equal("What? [hi]  ", output.string)
    end
  end

  describe "confirm" do
    it "Displays a default prompt" do
      input = StringIO.new "y\n"
      terminal = Toys::Terminal.new(input: input, output: output)
      assert_equal(true, terminal.confirm)
      assert_equal("Proceed? (y/n) ", output.string)
    end

    it "Displays a custom prompt" do
      input = StringIO.new "n\n"
      terminal = Toys::Terminal.new(input: input, output: output)
      assert_equal(false, terminal.confirm("ok? "))
      assert_equal("ok? (y/n) ", output.string)
    end

    it "Displays a prompt with default of yes" do
      input = StringIO.new "\n"
      terminal = Toys::Terminal.new(input: input, output: output)
      assert_equal(true, terminal.confirm("ok? ", default: true))
      assert_equal("ok? (Y/n) ", output.string)
    end

    it "Displays a prompt with default of no" do
      input = StringIO.new "\n"
      terminal = Toys::Terminal.new(input: input, output: output)
      assert_equal(false, terminal.confirm("ok? ", default: false))
      assert_equal("ok? (y/N) ", output.string)
    end

    it "Handles input EOF" do
      input = StringIO.new
      terminal = Toys::Terminal.new(input: input, output: output)
      assert_equal(true, terminal.confirm(default: true))
      assert_equal("Proceed? (Y/n) ", output.string)
    end
  end
end
