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

describe Toys::Flag::Syntax do
  describe "creation" do
    it "recognizes single dash flag with no value" do
      fs = Toys::Flag::Syntax.new("-a")
      assert_equal("-a", fs.original_str)
      assert_equal(["-a"], fs.flags)
      assert_equal("-a", fs.positive_flag)
      assert_nil(fs.negative_flag)
      assert_equal("-a", fs.str_without_value)
      assert_equal(:short, fs.flag_style)
      assert_nil(fs.flag_type)
      assert_nil(fs.value_type)
      assert_nil(fs.value_delim)
      assert_nil(fs.value_label)
      assert_equal("-a", fs.canonical_str)
      assert_equal("a", fs.sort_str)
    end

    it "recognizes single dash flag with required value and no whitespace" do
      fs = Toys::Flag::Syntax.new("-aFOO")
      assert_equal("-aFOO", fs.original_str)
      assert_equal(["-a"], fs.flags)
      assert_equal("-a", fs.str_without_value)
      assert_equal(:short, fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:required, fs.value_type)
      assert_equal("", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("-aFOO", fs.canonical_str)
      assert_equal("a", fs.sort_str)
    end

    it "recognizes single dash flag with optional value and no whitespace" do
      fs = Toys::Flag::Syntax.new("-a[FOO]")
      assert_equal("-a[FOO]", fs.original_str)
      assert_equal(["-a"], fs.flags)
      assert_equal("-a", fs.str_without_value)
      assert_equal(:short, fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal("", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("-a[FOO]", fs.canonical_str)
      assert_equal("a", fs.sort_str)
    end

    it "recognizes single dash flag with required value and whitespace" do
      fs = Toys::Flag::Syntax.new("-a FOO")
      assert_equal("-a FOO", fs.original_str)
      assert_equal(["-a"], fs.flags)
      assert_equal("-a", fs.str_without_value)
      assert_equal(:short, fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:required, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("-a FOO", fs.canonical_str)
      assert_equal("a", fs.sort_str)
    end

    it "recognizes single dash flag with optional value and whitespace" do
      fs = Toys::Flag::Syntax.new("-a [FOO]")
      assert_equal("-a [FOO]", fs.original_str)
      assert_equal(["-a"], fs.flags)
      assert_equal("-a", fs.str_without_value)
      assert_equal(:short, fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("-a [FOO]", fs.canonical_str)
      assert_equal("a", fs.sort_str)
    end

    it "recognizes single dash flag with optional value and whitespace within brackets" do
      fs = Toys::Flag::Syntax.new("-a[ FOO]")
      assert_equal("-a[ FOO]", fs.original_str)
      assert_equal(["-a"], fs.flags)
      assert_equal("-a", fs.str_without_value)
      assert_equal(:short, fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("-a[ FOO]", fs.canonical_str)
      assert_equal("a", fs.sort_str)
    end

    it "recognizes double dash flag with no value" do
      fs = Toys::Flag::Syntax.new("--abc")
      assert_equal("--abc", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal(:long, fs.flag_style)
      assert_nil(fs.flag_type)
      assert_nil(fs.value_type)
      assert_nil(fs.value_delim)
      assert_nil(fs.value_label)
      assert_equal("--abc", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes double dash flag with required value delimited by =" do
      fs = Toys::Flag::Syntax.new("--abc=FOO")
      assert_equal("--abc=FOO", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal(:long, fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:required, fs.value_type)
      assert_equal("=", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc=FOO", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes single dash flag with optional value delimited by = outside brackets" do
      fs = Toys::Flag::Syntax.new("--abc=[FOO]")
      assert_equal("--abc=[FOO]", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal(:long, fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal("=", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc=[FOO]", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes single dash flag with optional value delimited by = within brackets" do
      fs = Toys::Flag::Syntax.new("--abc[=FOO]")
      assert_equal("--abc[=FOO]", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal(:long, fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal("=", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc[=FOO]", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes single dash flag with required value delimited by whitespace" do
      fs = Toys::Flag::Syntax.new("--abc FOO")
      assert_equal("--abc FOO", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal(:long, fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:required, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc FOO", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes single dash flag with optional value delimited by whitespace outside brackets" do
      fs = Toys::Flag::Syntax.new("--abc [FOO]")
      assert_equal("--abc [FOO]", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal(:long, fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc [FOO]", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes single dash flag with optional value delimited by whitespace within brackets" do
      fs = Toys::Flag::Syntax.new("--abc[ FOO]")
      assert_equal("--abc[ FOO]", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal(:long, fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc[ FOO]", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes double dash flag with negation" do
      fs = Toys::Flag::Syntax.new("--[no-]abc")
      assert_equal("--[no-]abc", fs.original_str)
      assert_equal(["--abc", "--no-abc"], fs.flags)
      assert_equal("--abc", fs.positive_flag)
      assert_equal("--no-abc", fs.negative_flag)
      assert_equal("--[no-]abc", fs.str_without_value)
      assert_equal(:long, fs.flag_style)
      assert_equal(:boolean, fs.flag_type)
      assert_nil(fs.value_type)
      assert_nil(fs.value_delim)
      assert_nil(fs.value_label)
      assert_equal("--[no-]abc", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end
  end

  describe "configure_canonical" do
    it "does not change flags that already have a type" do
      fs = Toys::Flag::Syntax.new("--[no-]abc")
      fs.configure_canonical(:value, :optional, "VAL", "=")
      assert_equal(:boolean, fs.flag_type)
    end

    it "updates a flag to boolean type" do
      fs = Toys::Flag::Syntax.new("--abc")
      fs.configure_canonical(:boolean, nil, nil, " ")
      assert_equal(:boolean, fs.flag_type)
      assert_nil(fs.value_type)
    end

    it "updates a flag to value type" do
      fs = Toys::Flag::Syntax.new("--abc")
      fs.configure_canonical(:value, :optional, "FOO", " ")
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc [FOO]", fs.canonical_str)
    end

    it "updates long flag with short flag delimiter" do
      fs = Toys::Flag::Syntax.new("--abc")
      fs.configure_canonical(:value, :optional, "FOO", "")
      assert_equal("=", fs.value_delim)
    end

    it "updates short flag with long flag delimiter" do
      fs = Toys::Flag::Syntax.new("-a")
      fs.configure_canonical(:value, :optional, "FOO", "=")
      assert_equal("", fs.value_delim)
    end
  end
end

describe Toys::Flag do
  it "defaults to a boolean switch with a long name" do
    flag = Toys::Flag.new(:abc, [], [], true, nil, nil, nil, nil, nil, nil, nil)
    assert_equal(1, flag.flag_syntax.size)
    assert_equal("--abc", flag.flag_syntax.first.canonical_str)
    assert_equal(:boolean, flag.flag_syntax.first.flag_type)
    assert_equal(:boolean, flag.flag_type)
  end

  it "defaults to a boolean switch with a short name" do
    flag = Toys::Flag.new(:a, [], [], true, nil, nil, nil, nil, nil, nil, nil)
    assert_equal(1, flag.flag_syntax.size)
    assert_equal("-a", flag.flag_syntax.first.canonical_str)
    assert_equal(:boolean, flag.flag_syntax.first.flag_type)
    assert_equal(:boolean, flag.flag_type)
  end

  it "defaults to a value switch with a string default" do
    flag = Toys::Flag.new(:abc, [], [], true, nil, nil, "hello", nil, nil, nil, nil)
    assert_equal(1, flag.flag_syntax.size)
    assert_equal("--abc VALUE", flag.flag_syntax.first.canonical_str)
    assert_equal(:value, flag.flag_syntax.first.flag_type)
    assert_equal(:required, flag.flag_syntax.first.value_type)
    assert_equal(" ", flag.flag_syntax.first.value_delim)
    assert_equal("VALUE", flag.flag_syntax.first.value_label)
    assert_equal(:value, flag.flag_type)
    assert_equal(:required, flag.value_type)
    assert_equal(" ", flag.value_delim)
    assert_equal("VALUE", flag.value_label)
    assert_equal("hello", flag.default)
    assert_nil(flag.acceptor)
  end

  it "defaults to a value switch with an integer acceptor" do
    acceptor = Toys::Acceptor.resolve_default(Integer)
    flag = Toys::Flag.new(:abc, [], [], true, acceptor, nil, nil, nil, nil, nil, nil)
    assert_equal(1, flag.flag_syntax.size)
    assert_equal("--abc VALUE", flag.flag_syntax.first.canonical_str)
    assert_equal(:value, flag.flag_syntax.first.flag_type)
    assert_equal(:required, flag.flag_syntax.first.value_type)
    assert_equal(" ", flag.flag_syntax.first.value_delim)
    assert_equal("VALUE", flag.flag_syntax.first.value_label)
    assert_equal(:value, flag.flag_type)
    assert_equal(:required, flag.value_type)
    assert_equal(" ", flag.value_delim)
    assert_equal("VALUE", flag.value_label)
    assert_nil(flag.default)
    assert_equal(acceptor, flag.acceptor)
  end

  it "defaults to a value switch with a short name" do
    flag = Toys::Flag.new(:a, [], [], true, nil, nil, "hello", nil, nil, nil, nil)
    assert_equal(1, flag.flag_syntax.size)
    assert_equal("-a VALUE", flag.flag_syntax.first.canonical_str)
    assert_equal(:value, flag.flag_syntax.first.flag_type)
    assert_equal(:required, flag.flag_syntax.first.value_type)
    assert_equal(" ", flag.flag_syntax.first.value_delim)
    assert_equal("VALUE", flag.flag_syntax.first.value_label)
    assert_equal(:value, flag.flag_type)
    assert_equal(:required, flag.value_type)
    assert_equal(" ", flag.value_delim)
    assert_equal("VALUE", flag.value_label)
    assert_equal("hello", flag.default)
    assert_nil(flag.acceptor)
  end

  it "chooses the first long flag's value label and delim as canonical" do
    flag = Toys::Flag.new(:abc, ["--bb=VAL", "--aa LAV", "-aFOO"], [],
                          true, nil, nil, nil, nil, nil, nil, nil)
    assert_equal(3, flag.flag_syntax.size)
    assert_equal(:value, flag.flag_type)
    assert_equal(:required, flag.value_type)
    assert_equal("VAL", flag.value_label)
    assert_equal("=", flag.value_delim)
    assert_equal("--bb=VAL", flag.display_name)
    assert_equal("bb", flag.sort_str)
  end

  it "chooses the first short flag's value label and delim as canonical" do
    flag = Toys::Flag.new(:abc, ["-aFOO", "-b BAR"], [],
                          true, nil, nil, nil, nil, nil, nil, nil)
    assert_equal(2, flag.flag_syntax.size)
    assert_equal(:value, flag.flag_type)
    assert_equal(:required, flag.value_type)
    assert_equal("FOO", flag.value_label)
    assert_equal("", flag.value_delim)
    assert_equal("-aFOO", flag.display_name)
    assert_equal("a", flag.sort_str)
  end

  it "canonicalizes to required value flags" do
    flag = Toys::Flag.new(:abc, ["--aa VAL", "--bb", "-a"], [],
                          true, nil, nil, nil, nil, nil, nil, nil)
    assert_equal(3, flag.flag_syntax.size)
    assert_equal(:value, flag.flag_type)
    assert_equal(:required, flag.value_type)
    assert_equal("VAL", flag.value_label)
    assert_equal(" ", flag.value_delim)
    assert_equal("--bb VAL", flag.flag_syntax[1].canonical_str)
    assert_equal("-a VAL", flag.flag_syntax[2].canonical_str)
    assert_equal("--aa VAL", flag.display_name)
    assert_equal("aa", flag.sort_str)
  end

  it "canonicalizes to optional value flags" do
    flag = Toys::Flag.new(:abc, ["--aa", "--cc [VAL]", "--bb", "-a"], [],
                          true, nil, nil, nil, nil, nil, nil, nil)
    assert_equal(4, flag.flag_syntax.size)
    assert_equal(:value, flag.flag_type)
    assert_equal(:optional, flag.value_type)
    assert_equal("VAL", flag.value_label)
    assert_equal(" ", flag.value_delim)
    assert_equal("--bb [VAL]", flag.flag_syntax[2].canonical_str)
    assert_equal("-a [VAL]", flag.flag_syntax[3].canonical_str)
    assert_equal("--aa [VAL]", flag.display_name)
    assert_equal("aa", flag.sort_str)
  end

  it "canonicalizes to boolean flags" do
    flag = Toys::Flag.new(:abc, ["--[no-]aa", "--bb", "-a"], [],
                          true, nil, nil, nil, nil, nil, nil, nil)
    assert_equal(3, flag.flag_syntax.size)
    assert_equal(:boolean, flag.flag_type)
    assert_equal(:boolean, flag.flag_syntax[1].flag_type)
    assert_equal(:boolean, flag.flag_syntax[2].flag_type)
    assert_equal("--[no-]aa", flag.display_name)
    assert_equal("aa", flag.sort_str)
  end

  it "honors provided display name" do
    flag = Toys::Flag.new(:abc, ["--aa VAL", "--bb", "-a"], [],
                          true, nil, nil, nil, nil, nil, "aa flag", nil)
    assert_equal("aa flag", flag.display_name)
  end

  it "prevents value and boolean collisions" do
    assert_raises(Toys::ToolDefinitionError) do
      Toys::Flag.new(:abc, ["--[no-]aa", "--bb=VAL"], [],
                     true, nil, nil, nil, nil, nil, nil, nil)
    end
  end

  it "prevents required and optional collisions" do
    assert_raises(Toys::ToolDefinitionError) do
      Toys::Flag.new(:abc, ["--aa=VAL", "--bb=[VAL]"], [],
                     true, nil, nil, nil, nil, nil, nil, nil)
    end
  end

  it "updates used flags" do
    used_flags = []
    Toys::Flag.new(:abc, ["--[no-]aa", "--bb", "-a"], used_flags,
                   true, nil, nil, nil, nil, nil, nil, nil)
    assert_equal(["--aa", "--no-aa", "--bb", "-a"], used_flags)
  end

  it "reports collisions with used flags" do
    assert_raises(Toys::ToolDefinitionError) do
      Toys::Flag.new(:abc, ["--[no-]aa", "--bb", "-a"], ["--aa"],
                     true, nil, nil, nil, nil, nil, nil, nil)
    end
  end

  it "defaults to the set handler" do
    flag = Toys::Flag.new(:abc, [], [], true, nil, nil, nil, nil, nil, nil, nil)
    assert_equal(Toys::Flag::SET_HANDLER, flag.handler)
    assert_equal(1, flag.handler.call(1, 2))
  end

  it "recognizes the set handler" do
    flag = Toys::Flag.new(:abc, [], [], true, nil, :set, nil, nil, nil, nil, nil)
    assert_equal(Toys::Flag::SET_HANDLER, flag.handler)
    assert_equal(1, flag.handler.call(1, 2))
  end

  it "recognizes the push handler" do
    flag = Toys::Flag.new(:abc, [], [], true, nil, :push, [], nil, nil, nil, nil)
    assert_equal(Toys::Flag::PUSH_HANDLER, flag.handler)
    assert_equal([1, 2], flag.handler.call(2, [1]))
  end

  describe "#resolve" do
    def create_flag(*flags)
      Toys::Flag.new(:abc, flags, [], true, nil, nil, nil, nil, nil, nil, nil)
    end

    it "finds a simple flag" do
      flag = create_flag("-a")
      resolution = flag.resolve("-a")
      assert_equal("-a", resolution.string)
      assert_equal(true, resolution.found_exact?)
      assert_equal(1, resolution.count)
      assert_equal(true, resolution.found_unique?)
      assert_equal(false, resolution.not_found?)
      assert_equal(false, resolution.found_multiple?)
      assert_equal(flag, resolution.unique_flag)
      assert_equal(flag.flag_syntax.first, resolution.unique_flag_syntax)
      assert_equal(false, resolution.unique_flag_negative?)
    end

    it "reports not found" do
      flag = create_flag("-a")
      resolution = flag.resolve("-b")
      assert_equal("-b", resolution.string)
      assert_equal(false, resolution.found_exact?)
      assert_equal(0, resolution.count)
      assert_equal(false, resolution.found_unique?)
      assert_equal(true, resolution.not_found?)
      assert_equal(false, resolution.found_multiple?)
      assert_nil(resolution.unique_flag)
      assert_nil(resolution.unique_flag_syntax)
      assert_nil(resolution.unique_flag_negative?)
    end

    it "reports ambiguous resolution" do
      flag = create_flag("--abc", "--abd")
      resolution = flag.resolve("--ab")
      assert_equal("--ab", resolution.string)
      assert_equal(false, resolution.found_exact?)
      assert_equal(2, resolution.count)
      assert_equal(false, resolution.found_unique?)
      assert_equal(false, resolution.not_found?)
      assert_equal(true, resolution.found_multiple?)
      assert_nil(resolution.unique_flag)
      assert_nil(resolution.unique_flag_syntax)
      assert_nil(resolution.unique_flag_negative?)
    end

    it "finds a substring" do
      flag = create_flag("--abc")
      resolution = flag.resolve("--ab")
      assert_equal("--ab", resolution.string)
      assert_equal(false, resolution.found_exact?)
      assert_equal(flag.flag_syntax.first, resolution.unique_flag_syntax)
    end

    it "does not treat single hyphen flags as substrings" do
      flag = create_flag("--abc")
      resolution = flag.resolve("-a")
      assert_equal(true, resolution.not_found?)
    end

    it "prefers exact matches over substrings when the exact match appears first" do
      flag = create_flag("--ab", "--abc")
      resolution = flag.resolve("--ab")
      assert_equal(true, resolution.found_exact?)
      assert_equal(flag.flag_syntax.first, resolution.unique_flag_syntax)
    end

    it "prefers exact matches over substrings when the exact match appears last" do
      flag = create_flag("--abc", "--ab")
      resolution = flag.resolve("--ab")
      assert_equal(true, resolution.found_exact?)
      assert_equal(flag.flag_syntax.last, resolution.unique_flag_syntax)
    end

    it "detects the negative case" do
      flag = create_flag("--[no-]abc")
      resolution = flag.resolve("--no-abc")
      assert_equal("--no-abc", resolution.string)
      assert_equal(true, resolution.found_exact?)
      assert_equal(flag.flag_syntax.first, resolution.unique_flag_syntax)
      assert_equal(true, resolution.unique_flag_negative?)
    end

    it "detects the negative case in a substring" do
      flag = create_flag("--[no-]abc")
      resolution = flag.resolve("--no-a")
      assert_equal("--no-a", resolution.string)
      assert_equal(false, resolution.found_exact?)
      assert_equal(flag.flag_syntax.first, resolution.unique_flag_syntax)
      assert_equal(true, resolution.unique_flag_negative?)
    end
  end
end
