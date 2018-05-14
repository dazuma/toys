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

require "toys/utils/help_text"

describe Toys::Utils::HelpText do
  let(:binary_name) { "toys" }
  let(:tool_name) { ["foo", "bar"] }
  let(:group_tool) do
    Toys::Tool.new(tool_name)
  end
  let(:normal_tool) do
    Toys::Tool.new(tool_name).tap do |t|
      t.executor = proc {}
    end
  end
  let(:subtool_one) do
    Toys::Tool.new(["foo", "bar", "one"])
  end
  let(:subtool_one_a) do
    Toys::Tool.new(["foo", "bar", "one", "a"]).tap do |t|
      t.executor = proc {}
    end
  end
  let(:subtool_one_b) do
    Toys::Tool.new(["foo", "bar", "one", "b"]).tap do |t|
      t.executor = proc {}
    end
  end
  let(:subtool_two) do
    Toys::Tool.new(["foo", "bar", "two"]).tap do |t|
      t.executor = proc {}
    end
  end
  let(:long_tool_name) { "long-long-long-long-long-long-long-long" }
  let(:subtool_long) do
    Toys::Tool.new(["foo", "bar", long_tool_name])
  end
  let(:empty_loader) do
    m = Minitest::Mock.new
    m.expect(:list_subtools, [], [["foo", "bar"], recursive: false])
    m
  end
  let(:group_loader) do
    m = Minitest::Mock.new
    m.expect(:list_subtools, [subtool_one, subtool_two], [["foo", "bar"], recursive: false])
    m
  end
  let(:recursive_group_loader) do
    m = Minitest::Mock.new
    m.expect(:list_subtools, [subtool_one, subtool_one_a, subtool_one_b, subtool_two],
             [["foo", "bar"], recursive: true])
    m
  end
  let(:long_group_loader) do
    m = Minitest::Mock.new
    m.expect(:list_subtools, [subtool_long], [["foo", "bar"], recursive: false])
    m
  end

  describe "short usage" do
    describe "synopsis" do
      it "is set for a group" do
        usage = Toys::Utils::HelpText.new(group_tool, group_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        assert_equal("Usage:  toys foo bar TOOL [ARGUMENTS...]", usage_array[0])
        assert_equal("        toys foo bar", usage_array[1])
        assert_equal("", usage_array[2])
      end

      it "is set for a group with an executor" do
        usage = Toys::Utils::HelpText.new(normal_tool, group_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        assert_equal("Usage:  toys foo bar", usage_array[0])
        assert_equal("        toys foo bar TOOL [ARGUMENTS...]", usage_array[1])
        assert_equal("", usage_array[2])
      end

      it "is set for a normal tool with no flags" do
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        assert_equal("Usage:  toys foo bar", usage_array[0])
        assert_equal(1, usage_array.size)
      end

      it "is set for a normal tool with flags" do
        normal_tool.add_flag(:aa, "-a", "--aa=VALUE", desc: "set aa")
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        assert_equal("Usage:  toys foo bar [FLAGS...]", usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a normal tool with required args" do
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        assert_equal("Usage:  toys foo bar CC DD", usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a normal tool with optional args" do
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        assert_equal("Usage:  toys foo bar [EE] [FF]", usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a normal tool with remaining args" do
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        assert_equal("Usage:  toys foo bar [GG...]", usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a normal tool with the kitchen sink" do
        normal_tool.add_flag(:aa, "-a", "--aa=VALUE", desc: "set aa")
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        assert_equal("Usage:  toys foo bar [FLAGS...] CC DD [EE] [FF] [GG...]",
                     usage_array[0])
        assert_equal("", usage_array[1])
      end
    end

    describe "commands section" do
      it "is not present for a normal tool" do
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        index = usage_array.index("Tools:")
        assert_nil(index)
      end

      it "is set for a group non-recursive" do
        usage = Toys::Utils::HelpText.new(group_tool, group_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}one\s{30}$/, usage_array[index + 1])
        assert_match(/^\s{4}two\s{30}$/, usage_array[index + 2])
        assert_equal(index + 3, usage_array.size)
      end

      it "is set for a group recursive" do
        usage = Toys::Utils::HelpText.new(group_tool, recursive_group_loader, binary_name)
        usage_array = usage.short_string(recursive: true).split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}one\s{30}$/, usage_array[index + 1])
        assert_match(/^\s{4}one a\s{28}$/, usage_array[index + 2])
        assert_match(/^\s{4}one b\s{28}$/, usage_array[index + 3])
        assert_match(/^\s{4}two\s{30}$/, usage_array[index + 4])
        assert_equal(index + 5, usage_array.size)
      end

      it "shows command desc" do
        subtool_one.desc = "one desc"
        subtool_two.desc = Toys::Utils::WrappableString.new("two desc on two lines")
        usage = Toys::Utils::HelpText.new(group_tool, group_loader, binary_name)
        usage_array = usage.short_string(wrap_width: 49).split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}one\s{30}one desc$/, usage_array[index + 1])
        assert_match(/^\s{4}two\s{30}two desc on$/, usage_array[index + 2])
        assert_match(/^\s{37}two lines$/, usage_array[index + 3])
        assert_equal(index + 4, usage_array.size)
      end

      it "shows long command desc" do
        subtool_long.desc = Toys::Utils::WrappableString.new("long desc on two lines")
        usage = Toys::Utils::HelpText.new(group_tool, long_group_loader, binary_name)
        usage_array = usage.short_string(wrap_width: 49).split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}#{long_tool_name}$/, usage_array[index + 1])
        assert_match(/^\s{37}long desc on$/, usage_array[index + 2])
        assert_match(/^\s{37}two lines$/, usage_array[index + 3])
        assert_equal(index + 4, usage_array.size)
      end
    end

    describe "positional args section" do
      it "is not present for a group" do
        usage = Toys::Utils::HelpText.new(group_tool, group_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        index = usage_array.index("Positional arguments:")
        assert_nil(index)
      end

      it "is not present for a normal tool with no positional args" do
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        index = usage_array.index("Positional arguments:")
        assert_nil(index)
      end

      it "is set for a normal tool with positional args" do
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        index = usage_array.index("Positional arguments:")
        refute_nil(index)
        assert_match(/^\s{4}CC\s{31}set cc$/, usage_array[index + 1])
        assert_match(/^\s{4}DD\s{31}set dd$/, usage_array[index + 2])
        assert_match(/^\s{4}\[EE\]\s{29}set ee$/, usage_array[index + 3])
        assert_match(/^\s{4}\[FF\]\s{29}set ff$/, usage_array[index + 4])
        assert_match(/^\s{4}\[GG\.\.\.\]\s{26}set gg$/, usage_array[index + 5])
        assert_equal(index + 6, usage_array.size)
      end

      it "shows long arg desc" do
        normal_tool.add_required_arg(:long_long_long_long_long_long_long_long,
                                     desc: Toys::Utils::WrappableString.new("set long arg desc"))
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string(wrap_width: 47).split("\n")
        index = usage_array.index("Positional arguments:")
        refute_nil(index)
        assert_match(/^\s{4}LONG_LONG_LONG_LONG_LONG_LONG_LONG_LONG$/, usage_array[index + 1])
        assert_match(/^\s{37}set long$/, usage_array[index + 2])
        assert_match(/^\s{37}arg desc$/, usage_array[index + 3])
        assert_equal(index + 4, usage_array.size)
      end
    end

    describe "flags section" do
      it "is not present for a tool with no flags" do
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        index = usage_array.index("Flags:")
        assert_nil(index)
      end

      it "is set for a tool with flags" do
        normal_tool.add_flag(:aa, "-a", "--aa=VALUE", desc: "set aa")
        normal_tool.add_flag(:bb, "--[no-]bb", desc: "set bb")
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        index = usage_array.index("Flags:")
        refute_nil(index)
        assert_match(/^\s{4}-a, --aa=VALUE\s{19}set aa$/, usage_array[index + 1])
        assert_match(/^\s{8}--\[no-\]bb\s{20}set bb$/, usage_array[index + 2])
        assert_equal(index + 3, usage_array.size)
      end

      it "shows value only for last flag" do
        normal_tool.add_flag(:aa, "-a VALUE", "--aa", desc: "set aa")
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        index = usage_array.index("Flags:")
        refute_nil(index)
        assert_match(/^\s{4}-a, --aa VALUE\s{19}set aa$/, usage_array[index + 1])
        assert_equal(index + 2, usage_array.size)
      end

      it "orders single dashes before double dashes" do
        normal_tool.add_flag(:aa, "--aa", "-a VALUE", desc: "set aa")
        usage = Toys::Utils::HelpText.new(normal_tool, empty_loader, binary_name)
        usage_array = usage.short_string.split("\n")
        index = usage_array.index("Flags:")
        refute_nil(index)
        assert_match(/^\s{4}-a, --aa VALUE\s{19}set aa$/, usage_array[index + 1])
        assert_equal(index + 2, usage_array.size)
      end
    end
  end
end