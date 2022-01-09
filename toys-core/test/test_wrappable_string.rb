# frozen_string_literal: true

require "helper"
require "toys/utils/terminal"

describe Toys::WrappableString do
  describe "wrap string" do
    it "handles nil" do
      result = Toys::WrappableString.new(nil).wrap(10)
      assert_equal([], result)
    end

    it "handles empty string" do
      result = Toys::WrappableString.new("").wrap(10)
      assert_equal([], result)
    end

    it "handles whitespace string" do
      skip("https://github.com/oracle/truffleruby/issues/2565") if Toys::Compat.truffleruby?
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
      str = Toys::Utils::Terminal.new(styled: true).apply_styles("a b", :bold)
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

  describe "make" do
    it "handles a WrappableString" do
      ws = Toys::WrappableString.new("hello")
      result = Toys::WrappableString.make(ws)
      assert_same(ws, result)
    end

    it "handles a string" do
      expected = Toys::WrappableString.new("hello")
      result = Toys::WrappableString.make("hello")
      assert_equal(expected, result)
    end
  end

  describe "make_array" do
    it "handles nil" do
      result = Toys::WrappableString.make_array(nil)
      assert_equal([], result)
    end

    it "handles a string" do
      expected = [Toys::WrappableString.new("hello")]
      result = Toys::WrappableString.make_array("hello")
      assert_equal(expected, result)
    end

    it "handles a string array" do
      expected = [Toys::WrappableString.new("hello"), Toys::WrappableString.new("world")]
      result = Toys::WrappableString.make_array(["hello", "world"])
      assert_equal(expected, result)
    end
  end

  describe "wrap_lines" do
    it "handles an empty array" do
      result = Toys::WrappableString.wrap_lines(nil, 10, 5)
      assert_equal([], result)
    end

    it "handles a single string wrapped through multiple lines" do
      result = Toys::WrappableString.wrap_lines("hello one two three", 10, 5)
      assert_equal(["hello one", "two", "three"], result)
    end

    it "handles multiple strings wrapped through multiple lines" do
      result = Toys::WrappableString.wrap_lines(["hello", "one two three"], 10, 5)
      assert_equal(["hello", "one", "two", "three"], result)
    end

    it "handles an infinite line" do
      result = Toys::WrappableString.wrap_lines("hello one two three", nil)
      assert_equal(["hello one two three"], result)
    end

    it "handles subsequent lines the same as the first" do
      result = Toys::WrappableString.wrap_lines(["hello", "one two three"], 10)
      assert_equal(["hello", "one two", "three"], result)
    end
  end
end
