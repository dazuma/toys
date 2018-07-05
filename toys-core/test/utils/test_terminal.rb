# frozen_string_literal: true

# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

require "helper"

describe Toys::Utils::Terminal do
  let(:input) { ::StringIO.new }
  let(:output) { ::StringIO.new }
  let(:terminal) { Toys::Utils::Terminal.new(input: input, output: output, styled: true) }

  describe "remove_style_escapes" do
    it "removes clear code" do
      str = Toys::Utils::Terminal.remove_style_escapes(Toys::Utils::Terminal::CLEAR_CODE)
      assert_equal("", str)
    end

    it "removes multiple sequences" do
      str = "\e[12;34mhi\e[9m"
      str = Toys::Utils::Terminal.remove_style_escapes(str)
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
    let(:terminal) { Toys::Utils::Terminal.new(input: input, output: output, styled: false) }

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

  describe "confirm" do
    it "Displays a default prompt" do
      input = StringIO.new "y\n"
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal(true, terminal.confirm)
      assert_equal("Proceed? (y/n) ", output.string)
    end

    it "Displays a custom prompt" do
      input = StringIO.new "n\n"
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal(false, terminal.confirm("ok?"))
      assert_equal("ok? (y/n) ", output.string)
    end

    it "Displays a prompt with default of yes" do
      input = StringIO.new
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal(true, terminal.confirm("ok?", default: true))
      assert_equal("ok? (Y/n) ", output.string)
    end

    it "Displays a prompt with default of no" do
      input = StringIO.new
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal(false, terminal.confirm("ok?", default: false))
      assert_equal("ok? (y/N) ", output.string)
    end
  end
end
