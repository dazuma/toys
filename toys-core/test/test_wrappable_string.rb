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

describe Toys::WrappableString do
  describe "wrap string" do
    it "handles empty string" do
      result = Toys::WrappableString.new("").wrap(10)
      assert_equal([], result)
    end

    it "handles whitespace string" do
      result = Toys::WrappableString.new(" \n ").wrap(10)
      assert_equal([], result)
    end

    it "handles single line" do
      result = Toys::WrappableString.new("a bcd e").wrap(10)
      assert_equal(["a bcd e"], result)
    end

    it "handles leading and trailing spaces" do
      result = Toys::WrappableString.new("  a bcd e\n").wrap(10)
      assert_equal(["a bcd e"], result)
    end

    it "splits lines" do
      result = Toys::WrappableString.new("a b cd efg\n").wrap(5)
      assert_equal(["a b", "cd", "efg"], result)
    end

    it "allows a long word" do
      result = Toys::WrappableString.new("a b cdefghij kl\n").wrap(5)
      assert_equal(["a b", "cdefghij", "kl"], result)
    end

    it "honors the width exactly" do
      result = Toys::WrappableString.new("a bcd ef ghi j").wrap(5)
      assert_equal(["a bcd", "ef", "ghi j"], result)
    end

    it "honors different width2" do
      result = Toys::WrappableString.new("a b cd ef\n").wrap(3, 5)
      assert_equal(["a b", "cd ef"], result)
    end

    it "doesn't get confused by ansi style codes" do
      str = Toys::Terminal.new(styled: true).apply_styles("a b", :bold)
      result = Toys::WrappableString.new(str).wrap(3)
      assert_equal([str], result)
      result2 = Toys::WrappableString.new(str).wrap(2)
      assert_equal(2, result2.size)
    end
  end

  describe "wrap fragments" do
    it "handles empty fragments" do
      result = Toys::WrappableString.new([]).wrap(10)
      assert_equal([], result)
    end

    it "does not split fragments" do
      result = Toys::WrappableString.new(["ab cd", "ef gh", "ij kl"]).wrap(10)
      assert_equal(["ab cd", "ef gh", "ij kl"], result)
    end

    it "combines fragments" do
      result = Toys::WrappableString.new(["ab cd", "ef gh", "ij kl"]).wrap(13)
      assert_equal(["ab cd ef gh", "ij kl"], result)
    end

    it "preserves spaces in fragments" do
      result = Toys::WrappableString.new([" ab cd\n", "\nef gh ", "ij   kl"]).wrap(15)
      assert_equal([" ab cd\n \nef gh ", "ij   kl"], result)
    end
  end
end
