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

describe Toys::Utils::Usage do
  let(:binary_name) { "toys" }
  let(:tool_name) { ["foo", "bar"] }
  let(:alias_target) { "bar" }
  let(:alias_name) { ["foo", "baz"] }
  let(:group_tool) do
    Toys::Tool.new(tool_name, [])
  end
  let(:normal_tool) do
    Toys::Tool.new(tool_name, []).tap do |t|
      t.executor = proc {}
    end
  end
  let(:alias_tool) do
    Toys::Tool.new(alias_name, []).tap do |t|
      t.make_alias_of(alias_target)
    end
  end
  let(:subtool_one) do
    Toys::Tool.new(["foo", "bar", "one"], [])
  end
  let(:subtool_one_a) do
    Toys::Tool.new(["foo", "bar", "one", "a"], []).tap do |t|
      t.executor = proc {}
    end
  end
  let(:subtool_one_b) do
    Toys::Tool.new(["foo", "bar", "one", "b"], []).tap do |t|
      t.executor = proc {}
    end
  end
  let(:subtool_two) do
    Toys::Tool.new(["foo", "bar", "two"], []).tap do |t|
      t.executor = proc {}
    end
  end
  let(:loader) { Minitest::Mock.new }
  let(:group_loader) do
    m = Minitest::Mock.new
    m.expect(:list_subtools, [subtool_one, subtool_two], [["foo", "bar"], false])
    m
  end
  let(:recursive_group_loader) do
    m = Minitest::Mock.new
    m.expect(:list_subtools, [subtool_one, subtool_one_a, subtool_one_b, subtool_two],
             [["foo", "bar"], true])
    m
  end

  describe "banner" do
    it "is set for a group" do
      usage = Toys::Utils::Usage.new(group_tool, binary_name, group_loader)
      usage_array = usage.string.split("\n")
      assert_equal("Usage: toys foo bar <command> [<options...>]", usage_array[0])
      assert_equal("", usage_array[1])
    end

    it "is set for a normal tool with no options" do
      usage = Toys::Utils::Usage.new(normal_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      assert_equal("Usage: toys foo bar", usage_array[0])
      assert_equal("", usage_array[1])
    end

    it "is set for a normal tool with switches" do
      normal_tool.add_switch(:aa, "-a", "--aa=VALUE", doc: "set aa")
      usage = Toys::Utils::Usage.new(normal_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      assert_equal("Usage: toys foo bar [<options...>]", usage_array[0])
      assert_equal("", usage_array[1])
    end

    it "is set for a normal tool with required args" do
      normal_tool.add_required_arg(:cc, doc: "set cc")
      normal_tool.add_required_arg(:dd, doc: "set dd")
      usage = Toys::Utils::Usage.new(normal_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      assert_equal("Usage: toys foo bar <cc> <dd>", usage_array[0])
      assert_equal("", usage_array[1])
    end

    it "is set for a normal tool with optional args" do
      normal_tool.add_optional_arg(:ee, doc: "set ee")
      normal_tool.add_optional_arg(:ff, doc: "set ff")
      usage = Toys::Utils::Usage.new(normal_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      assert_equal("Usage: toys foo bar [<ee>] [<ff>]", usage_array[0])
      assert_equal("", usage_array[1])
    end

    it "is set for a normal tool with remaining args" do
      normal_tool.set_remaining_args(:gg, doc: "set gg")
      usage = Toys::Utils::Usage.new(normal_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      assert_equal("Usage: toys foo bar [<gg...>]", usage_array[0])
      assert_equal("", usage_array[1])
    end

    it "is set for a normal tool with the kitchen sink" do
      normal_tool.add_switch(:aa, "-a", "--aa=VALUE", doc: "set aa")
      normal_tool.add_required_arg(:cc, doc: "set cc")
      normal_tool.add_required_arg(:dd, doc: "set dd")
      normal_tool.add_optional_arg(:ee, doc: "set ee")
      normal_tool.add_optional_arg(:ff, doc: "set ff")
      normal_tool.set_remaining_args(:gg, doc: "set gg")
      usage = Toys::Utils::Usage.new(normal_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      assert_equal("Usage: toys foo bar [<options...>] <cc> <dd> [<ee>] [<ff>] [<gg...>]",
                   usage_array[0])
      assert_equal("", usage_array[1])
    end
  end

  describe "description" do
    it "has a default for a group" do
      usage = Toys::Utils::Usage.new(group_tool, binary_name, group_loader)
      usage_array = usage.string.split("\n")
      assert_equal("(A group of commands)", usage_array[2])
      assert_equal("", usage_array[3])
    end

    it "has a default for a normal tool" do
      usage = Toys::Utils::Usage.new(normal_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      assert_equal("(No description available)", usage_array[2])
      assert_equal(3, usage_array.size)
    end

    it "has a default for an alias" do
      usage = Toys::Utils::Usage.new(alias_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      assert_equal("(Alias of \"bar\")", usage_array[2])
      assert_equal(3, usage_array.size)
    end

    it "uses the long description if present" do
      group_tool.desc = "The short description"
      group_tool.long_desc = "The long description"
      usage = Toys::Utils::Usage.new(group_tool, binary_name, group_loader)
      usage_array = usage.string.split("\n")
      assert_equal("The long description", usage_array[2])
      assert_equal("", usage_array[3])
    end

    it "uses the short description if no long description is available" do
      group_tool.desc = "The short description"
      usage = Toys::Utils::Usage.new(group_tool, binary_name, group_loader)
      usage_array = usage.string.split("\n")
      assert_equal("The short description", usage_array[2])
      assert_equal("", usage_array[3])
    end
  end

  describe "commands section" do
    it "is not present for a normal tool" do
      usage = Toys::Utils::Usage.new(normal_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      index = usage_array.index("Commands:")
      assert_nil(index)
    end

    it "is not present for an alias" do
      usage = Toys::Utils::Usage.new(alias_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      index = usage_array.index("Commands:")
      assert_nil(index)
    end

    it "is set for a group non-recursive" do
      usage = Toys::Utils::Usage.new(group_tool, binary_name, group_loader)
      usage_array = usage.string.split("\n")
      index = usage_array.index("Commands:")
      refute_nil(index)
      assert_match(/one\s+\(A group/, usage_array[index + 1])
      assert_match(/two\s+\(No description/, usage_array[index + 2])
      assert_equal(index + 3, usage_array.size)
    end

    it "is set for a group non-recursive" do
      usage = Toys::Utils::Usage.new(group_tool, binary_name, recursive_group_loader)
      usage_array = usage.string(recursive: true).split("\n")
      index = usage_array.index("Commands:")
      refute_nil(index)
      assert_match(/one\s+\(A group/, usage_array[index + 1])
      assert_match(/one a\s+\(No description/, usage_array[index + 2])
      assert_match(/one b\s+\(No description/, usage_array[index + 3])
      assert_match(/two\s+\(No description/, usage_array[index + 4])
      assert_equal(index + 5, usage_array.size)
    end
  end

  describe "positional args section" do
    it "is not present for a group" do
      usage = Toys::Utils::Usage.new(group_tool, binary_name, group_loader)
      usage_array = usage.string.split("\n")
      index = usage_array.index("Positional arguments:")
      assert_nil(index)
    end

    it "is not present for an alias" do
      usage = Toys::Utils::Usage.new(alias_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      index = usage_array.index("Positional arguments:")
      assert_nil(index)
    end

    it "is not present for a normal tool with no positional args" do
      usage = Toys::Utils::Usage.new(normal_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      index = usage_array.index("Positional arguments:")
      assert_nil(index)
    end

    it "is set for a normal tool with positional args" do
      normal_tool.add_required_arg(:cc, doc: "set cc")
      normal_tool.add_required_arg(:dd, doc: "set dd")
      normal_tool.add_optional_arg(:ee, doc: "set ee")
      normal_tool.add_optional_arg(:ff, doc: "set ff")
      normal_tool.set_remaining_args(:gg, doc: "set gg")
      usage = Toys::Utils::Usage.new(normal_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      index = usage_array.index("Positional arguments:")
      refute_nil(index)
      assert_match(/cc\s+set cc/, usage_array[index + 1])
      assert_match(/dd\s+set dd/, usage_array[index + 2])
      assert_match(/ee\s+set ee/, usage_array[index + 3])
      assert_match(/ff\s+set ff/, usage_array[index + 4])
      assert_match(/gg\s+set gg/, usage_array[index + 5])
      assert_equal(index + 6, usage_array.size)
    end
  end

  describe "switches section" do
    it "is not present for an alias" do
      usage = Toys::Utils::Usage.new(alias_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      index = usage_array.index("Options:")
      assert_nil(index)
    end

    it "is not present for a tool with no switches" do
      usage = Toys::Utils::Usage.new(normal_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      index = usage_array.index("Options:")
      assert_nil(index)
    end

    it "is set for a tool with switches" do
      normal_tool.add_switch(:aa, "-a", "--aa=VALUE", doc: "set aa")
      normal_tool.add_switch(:bb, "--[no-]bb", doc: "set bb")
      usage = Toys::Utils::Usage.new(normal_tool, binary_name, loader)
      usage_array = usage.string.split("\n")
      index = usage_array.index("Options:")
      refute_nil(index)
      assert_match(/-a, --aa=VALUE\s+set aa/, usage_array[index + 1])
      assert_match(/--\[no-\]bb\s+set bb/, usage_array[index + 2])
      assert_equal(index + 3, usage_array.size)
    end
  end
end
