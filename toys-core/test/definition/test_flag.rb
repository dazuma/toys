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

describe Toys::Definition::FlagSyntax do
  describe "creation" do
    it "recognizes single dash flag with no value" do
      fs = Toys::Definition::FlagSyntax.new("-a")
      assert_equal("-a", fs.original_str)
      assert_equal(["-a"], fs.flags)
      assert_equal("-a", fs.str_without_value)
      assert_equal("-", fs.flag_style)
      assert_nil(fs.flag_type)
      assert_nil(fs.value_type)
      assert_nil(fs.value_delim)
      assert_nil(fs.value_label)
      assert_equal("-a", fs.canonical_str)
      assert_equal("a", fs.sort_str)
    end

    it "recognizes single dash flag with required value and no whitespace" do
      fs = Toys::Definition::FlagSyntax.new("-aFOO")
      assert_equal("-aFOO", fs.original_str)
      assert_equal(["-a"], fs.flags)
      assert_equal("-a", fs.str_without_value)
      assert_equal("-", fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:required, fs.value_type)
      assert_equal("", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("-aFOO", fs.canonical_str)
      assert_equal("a", fs.sort_str)
    end

    it "recognizes single dash flag with optional value and no whitespace" do
      fs = Toys::Definition::FlagSyntax.new("-a[FOO]")
      assert_equal("-a[FOO]", fs.original_str)
      assert_equal(["-a"], fs.flags)
      assert_equal("-a", fs.str_without_value)
      assert_equal("-", fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal("", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("-a[FOO]", fs.canonical_str)
      assert_equal("a", fs.sort_str)
    end

    it "recognizes single dash flag with required value and whitespace" do
      fs = Toys::Definition::FlagSyntax.new("-a FOO")
      assert_equal("-a FOO", fs.original_str)
      assert_equal(["-a"], fs.flags)
      assert_equal("-a", fs.str_without_value)
      assert_equal("-", fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:required, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("-a FOO", fs.canonical_str)
      assert_equal("a", fs.sort_str)
    end

    it "recognizes single dash flag with optional value and whitespace" do
      fs = Toys::Definition::FlagSyntax.new("-a [FOO]")
      assert_equal("-a [FOO]", fs.original_str)
      assert_equal(["-a"], fs.flags)
      assert_equal("-a", fs.str_without_value)
      assert_equal("-", fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("-a [FOO]", fs.canonical_str)
      assert_equal("a", fs.sort_str)
    end

    it "recognizes single dash flag with optional value and whitespace within brackets" do
      fs = Toys::Definition::FlagSyntax.new("-a[ FOO]")
      assert_equal("-a[ FOO]", fs.original_str)
      assert_equal(["-a"], fs.flags)
      assert_equal("-a", fs.str_without_value)
      assert_equal("-", fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("-a[ FOO]", fs.canonical_str)
      assert_equal("a", fs.sort_str)
    end

    it "recognizes double dash flag with no value" do
      fs = Toys::Definition::FlagSyntax.new("--abc")
      assert_equal("--abc", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal("--", fs.flag_style)
      assert_nil(fs.flag_type)
      assert_nil(fs.value_type)
      assert_nil(fs.value_delim)
      assert_nil(fs.value_label)
      assert_equal("--abc", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes double dash flag with required value delimited by =" do
      fs = Toys::Definition::FlagSyntax.new("--abc=FOO")
      assert_equal("--abc=FOO", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal("--", fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:required, fs.value_type)
      assert_equal("=", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc=FOO", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes single dash flag with optional value delimited by = outside brackets" do
      fs = Toys::Definition::FlagSyntax.new("--abc=[FOO]")
      assert_equal("--abc=[FOO]", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal("--", fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal("=", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc=[FOO]", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes single dash flag with optional value delimited by = within brackets" do
      fs = Toys::Definition::FlagSyntax.new("--abc[=FOO]")
      assert_equal("--abc[=FOO]", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal("--", fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal("=", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc[=FOO]", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes single dash flag with required value delimited by whitespace" do
      fs = Toys::Definition::FlagSyntax.new("--abc FOO")
      assert_equal("--abc FOO", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal("--", fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:required, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc FOO", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes single dash flag with optional value delimited by whitespace outside brackets" do
      fs = Toys::Definition::FlagSyntax.new("--abc [FOO]")
      assert_equal("--abc [FOO]", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal("--", fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc [FOO]", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes single dash flag with optional value delimited by whitespace within brackets" do
      fs = Toys::Definition::FlagSyntax.new("--abc[ FOO]")
      assert_equal("--abc[ FOO]", fs.original_str)
      assert_equal(["--abc"], fs.flags)
      assert_equal("--abc", fs.str_without_value)
      assert_equal("--", fs.flag_style)
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc[ FOO]", fs.canonical_str)
      assert_equal("abc", fs.sort_str)
    end

    it "recognizes double dash flag with negation" do
      fs = Toys::Definition::FlagSyntax.new("--[no-]abc")
      assert_equal("--[no-]abc", fs.original_str)
      assert_equal(["--abc", "--no-abc"], fs.flags)
      assert_equal("--[no-]abc", fs.str_without_value)
      assert_equal("--", fs.flag_style)
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
      fs = Toys::Definition::FlagSyntax.new("--[no-]abc")
      fs.configure_canonical(:value, :optional, "VAL", "=")
      assert_equal(:boolean, fs.flag_type)
    end

    it "updates a flag to boolean type" do
      fs = Toys::Definition::FlagSyntax.new("--abc")
      fs.configure_canonical(:boolean, nil, nil, " ")
      assert_equal(:boolean, fs.flag_type)
      assert_nil(fs.value_type)
    end

    it "updates a flag to value type" do
      fs = Toys::Definition::FlagSyntax.new("--abc")
      fs.configure_canonical(:value, :optional, "FOO", " ")
      assert_equal(:value, fs.flag_type)
      assert_equal(:optional, fs.value_type)
      assert_equal(" ", fs.value_delim)
      assert_equal("FOO", fs.value_label)
      assert_equal("--abc [FOO]", fs.canonical_str)
    end

    it "updates long flag with short flag delimiter" do
      fs = Toys::Definition::FlagSyntax.new("--abc")
      fs.configure_canonical(:value, :optional, "FOO", "")
      assert_equal("=", fs.value_delim)
    end

    it "updates short flag with long flag delimiter" do
      fs = Toys::Definition::FlagSyntax.new("-a")
      fs.configure_canonical(:value, :optional, "FOO", "=")
      assert_equal("", fs.value_delim)
    end
  end
end

describe Toys::Definition::Flag do
  it "defaults to a boolean switch" do
    flag = Toys::Definition::Flag.new(:abc, [], [], true, nil, nil, nil, nil, nil)
    assert_equal(1, flag.flag_syntax.size)
    assert_equal("--abc", flag.flag_syntax.first.canonical_str)
    assert_equal(:boolean, flag.flag_syntax.first.flag_type)
    assert_equal(:boolean, flag.flag_type)
  end

  it "defaults to a value switch with a string default" do
    flag = Toys::Definition::Flag.new(:abc, [], [], true, nil, nil, "hello", nil, nil)
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
    assert_nil(flag.accept)
  end

  it "defaults to a value switch with an integer acceptor" do
    flag = Toys::Definition::Flag.new(:abc, [], [], true, Integer, nil, nil, nil, nil)
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
    assert_equal(Integer, flag.accept)
  end

  it "chooses the first long flag's value label and delim as canonical" do
    flag = Toys::Definition::Flag.new(:abc, ["--bb=VAL", "--aa LAV", "-aFOO"], [],
                                      true, nil, nil, nil, nil, nil)
    assert_equal(3, flag.flag_syntax.size)
    assert_equal(:value, flag.flag_type)
    assert_equal(:required, flag.value_type)
    assert_equal("VAL", flag.value_label)
    assert_equal("=", flag.value_delim)
    assert_equal("--bb=VAL", flag.display_name)
    assert_equal("bb", flag.sort_str)
  end

  it "chooses the first short flag's value label and delim as canonical" do
    flag = Toys::Definition::Flag.new(:abc, ["-aFOO", "-b BAR"], [],
                                      true, nil, nil, nil, nil, nil)
    assert_equal(2, flag.flag_syntax.size)
    assert_equal(:value, flag.flag_type)
    assert_equal(:required, flag.value_type)
    assert_equal("FOO", flag.value_label)
    assert_equal("", flag.value_delim)
    assert_equal("-aFOO", flag.display_name)
    assert_equal("a", flag.sort_str)
  end

  it "canonicalizes to required value flags" do
    flag = Toys::Definition::Flag.new(:abc, ["--aa VAL", "--bb", "-a"], [],
                                      true, nil, nil, nil, nil, nil)
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
    flag = Toys::Definition::Flag.new(:abc, ["--aa", "--cc [VAL]", "--bb", "-a"], [],
                                      true, nil, nil, nil, nil, nil)
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
    flag = Toys::Definition::Flag.new(:abc, ["--[no-]aa", "--bb", "-a"], [],
                                      true, nil, nil, nil, nil, nil)
    assert_equal(3, flag.flag_syntax.size)
    assert_equal(:boolean, flag.flag_type)
    assert_equal(:boolean, flag.flag_syntax[1].flag_type)
    assert_equal(:boolean, flag.flag_syntax[2].flag_type)
    assert_equal("--[no-]aa", flag.display_name)
    assert_equal("aa", flag.sort_str)
  end

  it "honors provided display name" do
    flag = Toys::Definition::Flag.new(:abc, ["--aa VAL", "--bb", "-a"], [],
                                      true, nil, nil, nil, "aa flag", nil)
    assert_equal("aa flag", flag.display_name)
  end

  it "prevents value and boolean collisions" do
    assert_raises(Toys::ToolDefinitionError) do
      Toys::Definition::Flag.new(:abc, ["--[no-]aa", "--bb=VAL"], [],
                                 true, nil, nil, nil, nil, nil)
    end
  end

  it "prevents required and optional collisions" do
    assert_raises(Toys::ToolDefinitionError) do
      Toys::Definition::Flag.new(:abc, ["--aa=VAL", "--bb=[VAL]"], [],
                                 true, nil, nil, nil, nil, nil)
    end
  end

  it "updates used flags" do
    used_flags = []
    Toys::Definition::Flag.new(:abc, ["--[no-]aa", "--bb", "-a"], used_flags,
                               true, nil, nil, nil, nil, nil)
    assert_equal(["--aa", "--no-aa", "--bb", "-a"], used_flags)
  end

  it "reports collisions with used flags" do
    assert_raises(Toys::ToolDefinitionError) do
      Toys::Definition::Flag.new(:abc, ["--[no-]aa", "--bb", "-a"], ["--aa"],
                                 true, nil, nil, nil, nil, nil)
    end
  end

  it "defaults to the set handler" do
    flag = Toys::Definition::Flag.new(:abc, [], [], true, nil, nil, nil, nil, nil)
    assert_equal(Toys::Definition::Flag::SET_HANDLER, flag.handler)
    assert_equal(1, flag.handler.call(1, 2))
  end

  it "recognizes the set handler" do
    flag = Toys::Definition::Flag.new(:abc, [], [], true, nil, :set, nil, nil, nil)
    assert_equal(Toys::Definition::Flag::SET_HANDLER, flag.handler)
    assert_equal(1, flag.handler.call(1, 2))
  end

  it "recognizes the push handler" do
    flag = Toys::Definition::Flag.new(:abc, [], [], true, nil, :push, [], nil, nil)
    assert_equal(Toys::Definition::Flag::PUSH_HANDLER, flag.handler)
    assert_equal([1, 2], flag.handler.call(2, [1]))
  end
end
