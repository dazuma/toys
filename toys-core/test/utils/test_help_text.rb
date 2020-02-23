# frozen_string_literal: true

require "helper"
require "toys/utils/help_text"

describe Toys::Utils::HelpText do
  let(:executable_name) { "toys" }
  let(:long_tool_name) { "long-long-long-long-long-long-long-long" }
  let(:tool_name) { ["foo", "bar"] }
  let(:tool2_name) { ["foo", "baz"] }
  let(:subtool_one_name) { tool_name + ["one"] }
  let(:subtool_two_name) { tool_name + ["two"] }
  let(:hidden_subtool_name) { tool_name + ["_three"] }
  let(:runnable) { proc {} }

  let(:single_loader) {
    loader = Toys::Loader.new
    loader.activate_tool(tool_name, 0).run_handler = runnable
    loader
  }
  let(:namespace_loader) {
    loader = Toys::Loader.new
    loader.activate_tool(tool_name, 0)
    loader.activate_tool(subtool_one_name, 0).run_handler = runnable
    loader.activate_tool(subtool_two_name, 0).run_handler = runnable
    loader.activate_tool(hidden_subtool_name, 0).run_handler = runnable
    loader
  }
  let(:runnable_namespace_loader) {
    loader = Toys::Loader.new
    loader.activate_tool(tool_name, 0).run_handler = runnable
    loader.activate_tool(subtool_one_name, 0).run_handler = runnable
    loader.activate_tool(subtool_two_name, 0).run_handler = runnable
    loader
  }
  let(:recursive_namespace_loader) {
    loader = Toys::Loader.new
    loader.activate_tool(tool_name, 0)
    loader.activate_tool(subtool_one_name, 0)
    loader.activate_tool(subtool_one_name + ["a"], 0).run_handler = runnable
    loader.activate_tool(subtool_one_name + ["b"], 0).run_handler = runnable
    loader.activate_tool(subtool_two_name, 0).run_handler = runnable
    loader
  }
  let(:long_namespace_loader) {
    loader = Toys::Loader.new
    loader.activate_tool(tool_name, 0)
    loader.activate_tool(tool_name + [long_tool_name], 0).run_handler = runnable
    loader
  }
  let(:delegation_loader) {
    loader = Toys::Loader.new
    loader.activate_tool(tool_name, 0).run_handler = runnable
    loader.activate_tool(tool2_name, 0).delegate_to(tool_name)
    loader
  }

  let(:normal_tool) do
    single_loader.get_tool(tool_name, 0)
  end
  let(:runnable_namespace_tool) do
    runnable_namespace_loader.get_tool(tool_name, 0)
  end
  let(:namespace_tool) do
    namespace_loader.get_tool(tool_name, 0)
  end
  let(:subtool_one) do
    namespace_loader.get_tool(subtool_one_name, 0)
  end
  let(:subtool_two) do
    namespace_loader.get_tool(subtool_two_name, 0)
  end
  let(:recursive_namespace_tool) do
    recursive_namespace_loader.get_tool(tool_name, 0)
  end
  let(:long_namespace_tool) do
    long_namespace_loader.get_tool(tool_name, 0)
  end
  let(:subtool_long) do
    long_namespace_loader.get_tool(tool_name + [long_tool_name], 0)
  end
  let(:delegating_tool) do
    delegation_loader.get_tool(tool2_name, 0)
  end

  describe "help text" do
    describe "name section" do
      it "renders with no description" do
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        assert_equal("NAME", help_array[0])
        assert_equal("    toys foo bar", help_array[1])
        assert_equal("", help_array[2])
      end

      it "renders with a description" do
        normal_tool.desc = "Hello world"
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        assert_equal("NAME", help_array[0])
        assert_equal("    toys foo bar - Hello world", help_array[1])
        assert_equal("", help_array[2])
      end

      it "renders with wrapping" do
        normal_tool.desc = Toys::WrappableString.new("Hello world")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false, wrap_width: 25).split("\n")
        assert_equal("NAME", help_array[0])
        assert_equal("    toys foo bar - Hello", help_array[1])
        assert_equal("        world", help_array[2])
        assert_equal("", help_array[3])
      end

      it "does not break the tool name when wrapping" do
        normal_tool.desc = Toys::WrappableString.new("Hello world")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false, wrap_width: 5).split("\n")
        assert_equal("NAME", help_array[0])
        assert_equal("    toys foo bar -", help_array[1])
        assert_equal("        Hello", help_array[2])
        assert_equal("        world", help_array[3])
        assert_equal("", help_array[4])
      end
    end

    describe "synopsis section" do
      it "is set for a namespace" do
        help = Toys::Utils::HelpText.new(namespace_tool, namespace_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar TOOL [ARGUMENTS...]", help_array[index + 1])
        assert_equal("    toys foo bar", help_array[index + 2])
        assert_equal("", help_array[index + 3])
      end

      it "is set for a namespace that is runnable" do
        help = Toys::Utils::HelpText.new(runnable_namespace_tool, runnable_namespace_loader,
                                         executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar TOOL [ARGUMENTS...]", help_array[index + 1])
        assert_equal("    toys foo bar", help_array[index + 2])
        assert_equal("", help_array[index + 3])
      end

      it "is set for a normal tool with no flags" do
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar", help_array[index + 1])
        assert_equal(index + 2, help_array.size)
      end

      it "is set for a normal tool with flags" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa")
        normal_tool.add_flag(:bb, ["--[no-]bb"], desc: "set bb")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar [-aVALUE | --aa=VALUE] [--[no-]bb]", help_array[index + 1])
        assert_equal("", help_array[index + 2])
      end

      it "is set for a normal tool with required args" do
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar CC DD", help_array[index + 1])
        assert_equal("", help_array[index + 2])
      end

      it "is set for a normal tool with optional args" do
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar [EE] [FF]", help_array[index + 1])
        assert_equal("", help_array[index + 2])
      end

      it "is set for a normal tool with remaining args" do
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar [GG...]", help_array[index + 1])
        assert_equal("", help_array[index + 2])
      end

      it "is set for a normal tool with the kitchen sink and wrapping" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa")
        normal_tool.add_flag(:bb, ["--[no-]bb"], desc: "set bb")
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false, wrap_width: 40).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal("    toys foo bar [-aVALUE | --aa=VALUE]", help_array[index + 1])
        assert_equal("        [--[no-]bb] CC DD [EE] [FF]", help_array[index + 2])
        assert_equal("        [GG...]", help_array[index + 3])
        assert_equal("", help_array[index + 4])
      end

      it "is set for a tool with a required group" do
        normal_tool.add_flag_group(type: :required, name: :mygroup)
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa", group: :mygroup)
        normal_tool.add_flag(:bb, ["-b", "--bb=VALUE"], desc: "set bb", group: :mygroup)
        normal_tool.add_flag(:cc, ["-c", "--cc=VALUE"], desc: "set cc")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal(
          "    toys foo bar [-cVALUE | --cc=VALUE]" \
              " (-aVALUE | --aa=VALUE) (-bVALUE | --bb=VALUE)",
          help_array[index + 1]
        )
      end

      it "is set for a tool with an exactly-one group" do
        normal_tool.add_flag_group(type: :exactly_one, name: :mygroup)
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa", group: :mygroup)
        normal_tool.add_flag(:bb, ["-b", "--bb=VALUE"], desc: "set bb", group: :mygroup)
        normal_tool.add_flag(:cc, ["-c", "--cc=VALUE"], desc: "set cc")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal(
          "    toys foo bar [-cVALUE | --cc=VALUE]" \
              " ( -aVALUE | --aa=VALUE | -bVALUE | --bb=VALUE )",
          help_array[index + 1]
        )
      end

      it "is set for a tool with an at-most-one group" do
        normal_tool.add_flag_group(type: :at_most_one, name: :mygroup)
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa", group: :mygroup)
        normal_tool.add_flag(:bb, ["-b", "--bb=VALUE"], desc: "set bb", group: :mygroup)
        normal_tool.add_flag(:cc, ["-c", "--cc=VALUE"], desc: "set cc")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal(
          "    toys foo bar [-cVALUE | --cc=VALUE]" \
              " [ -aVALUE | --aa=VALUE | -bVALUE | --bb=VALUE ]",
          help_array[index + 1]
        )
      end

      it "is set for a tool with an at-least-one group" do
        normal_tool.add_flag_group(type: :at_least_one, name: :mygroup)
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa", group: :mygroup)
        normal_tool.add_flag(:bb, ["-b", "--bb=VALUE"], desc: "set bb", group: :mygroup)
        normal_tool.add_flag(:cc, ["-c", "--cc=VALUE"], desc: "set cc")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal(
          "    toys foo bar [-cVALUE | --cc=VALUE]" \
              " ( [-aVALUE | --aa=VALUE] [-bVALUE | --bb=VALUE] )",
          help_array[index + 1]
        )
      end

      it "is set for a delegating tool" do
        help = Toys::Utils::HelpText.new(delegating_tool, delegation_loader, executable_name,
                                         delegate_target: tool_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("SYNOPSIS")
        refute_nil(index)
        assert_equal('    toys foo baz [ARGUMENTS FOR "foo bar"...]', help_array[index + 1])
      end
    end

    describe "description section" do
      it "renders with no long description" do
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("DESCRIPTION")
        assert_nil(index)
      end

      it "renders with a long description" do
        normal_tool.long_desc = ["Hello world"]
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("DESCRIPTION")
        refute_nil(index)
        assert_equal("    Hello world", help_array[index + 1])
        assert_equal(index + 2, help_array.size)
      end

      it "renders a delegating tool with no long description" do
        help = Toys::Utils::HelpText.new(delegating_tool, delegation_loader, executable_name,
                                         delegate_target: tool_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("DESCRIPTION")
        refute_nil(index)
        assert_equal("    Passes all arguments to \"#{tool_name.join(' ')}\" if invoked directly.",
                     help_array[index + 1])
        assert_equal(index + 2, help_array.size)
      end

      it "renders a delegating tool with a long description" do
        delegating_tool.long_desc = ["Hello world"]
        help = Toys::Utils::HelpText.new(delegating_tool, delegation_loader, executable_name,
                                         delegate_target: tool_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("DESCRIPTION")
        refute_nil(index)
        assert_equal("    Hello world", help_array[index + 1])
        assert_equal("    ", help_array[index + 2])
        assert_equal("    Passes all arguments to \"#{tool_name.join(' ')}\" if invoked directly.",
                     help_array[index + 3])
        assert_equal(index + 4, help_array.size)
      end
    end

    describe "flags section" do
      it "is not present for a tool with no flags" do
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("FLAGS")
        assert_nil(index)
      end

      it "is set for a tool with flags in the default group" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa")
        normal_tool.add_flag(:bb, ["--[no-]bb"], desc: "set bb")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("FLAGS")
        refute_nil(index)
        assert_equal("    -aVALUE, --aa=VALUE", help_array[index + 1])
        assert_equal("        set aa", help_array[index + 2])
        assert_equal("", help_array[index + 3])
        assert_equal("    --[no-]bb", help_array[index + 4])
        assert_equal("        set bb", help_array[index + 5])
        assert_equal(index + 6, help_array.size)
      end

      it "handles no description" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"])
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("FLAGS")
        refute_nil(index)
        assert_equal("    -aVALUE, --aa=VALUE", help_array[index + 1])
        assert_equal(index + 2, help_array.size)
      end

      it "prefers long description over short description" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "short desc", long_desc: "long desc")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("FLAGS")
        refute_nil(index)
        assert_equal("    -aVALUE, --aa=VALUE", help_array[index + 1])
        assert_equal("        long desc", help_array[index + 2])
        assert_equal(index + 3, help_array.size)
      end

      it "wraps long description" do
        long_desc = ["long desc", Toys::WrappableString.new("hello ruby world")]
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], long_desc: long_desc)
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false, wrap_width: 20).split("\n")
        index = help_array.index("FLAGS")
        refute_nil(index)
        assert_equal("    -aVALUE, --aa=VALUE", help_array[index + 1])
        assert_equal("        long desc", help_array[index + 2])
        assert_equal("        hello ruby", help_array[index + 3])
        assert_equal("        world", help_array[index + 4])
        assert_equal(index + 5, help_array.size)
      end

      it "shows separate sections per flag group" do
        normal_tool.add_flag_group(type: :required, name: :required, prepend: true,
                                   desc: "Required flags", long_desc: "List of required args")
        normal_tool.add_flag(:opt1, ["--opt1=VAL"], desc: "set opt1")
        normal_tool.add_flag(:opt2, ["--opt2=VAL"], desc: "set opt2")
        normal_tool.add_flag(:req1, ["--req1=VAL"], group: :required, desc: "set req1")
        normal_tool.add_flag(:req2, ["--req2=VAL"], group: :required, desc: "set req2")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        req_index = help_array.index("REQUIRED FLAGS")
        opt_index = help_array.index("FLAGS")
        refute_nil(req_index)
        assert_equal("    List of required args", help_array[req_index + 1])
        assert_equal("", help_array[req_index + 2])
        assert_equal("    --req1=VAL", help_array[req_index + 3])
        assert_equal("        set req1", help_array[req_index + 4])
        assert_equal("", help_array[req_index + 5])
        assert_equal("    --req2=VAL", help_array[req_index + 6])
        assert_equal("        set req2", help_array[req_index + 7])
        assert_equal(opt_index, req_index + 9)
        assert_equal("    --opt1=VAL", help_array[opt_index + 1])
        assert_equal("        set opt1", help_array[opt_index + 2])
        assert_equal("", help_array[opt_index + 3])
        assert_equal("    --opt2=VAL", help_array[opt_index + 4])
        assert_equal("        set opt2", help_array[opt_index + 5])
        assert_equal(opt_index + 6, help_array.size)
      end
    end

    describe "positional args section" do
      it "is not present for a tool with no args" do
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("POSITIONAL ARGUMENTS")
        assert_nil(index)
      end

      it "is set for a tool with args" do
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("POSITIONAL ARGUMENTS")
        refute_nil(index)
        assert_equal("    CC", help_array[index + 1])
        assert_equal("        set cc", help_array[index + 2])
        assert_equal("", help_array[index + 3])
        assert_equal("    DD", help_array[index + 4])
        assert_equal("        set dd", help_array[index + 5])
        assert_equal("", help_array[index + 6])
        assert_equal("    [EE]", help_array[index + 7])
        assert_equal("        set ee", help_array[index + 8])
        assert_equal("", help_array[index + 9])
        assert_equal("    [FF]", help_array[index + 10])
        assert_equal("        set ff", help_array[index + 11])
        assert_equal("", help_array[index + 12])
        assert_equal("    [GG...]", help_array[index + 13])
        assert_equal("        set gg", help_array[index + 14])
        assert_equal(index + 15, help_array.size)
      end

      it "handles no description" do
        normal_tool.add_required_arg(:cc)
        normal_tool.add_required_arg(:dd, desc: "set dd")
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff)
        normal_tool.set_remaining_args(:gg)
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("POSITIONAL ARGUMENTS")
        refute_nil(index)
        assert_equal("    CC", help_array[index + 1])
        assert_equal("", help_array[index + 2])
        assert_equal("    DD", help_array[index + 3])
        assert_equal("        set dd", help_array[index + 4])
        assert_equal("", help_array[index + 5])
        assert_equal("    [EE]", help_array[index + 6])
        assert_equal("        set ee", help_array[index + 7])
        assert_equal("", help_array[index + 8])
        assert_equal("    [FF]", help_array[index + 9])
        assert_equal("", help_array[index + 10])
        assert_equal("    [GG...]", help_array[index + 11])
        assert_equal(index + 12, help_array.size)
      end

      it "prefers long description over short description" do
        normal_tool.add_required_arg(:cc, desc: "short desc", long_desc: "long desc")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("POSITIONAL ARGUMENTS")
        refute_nil(index)
        assert_equal("    CC", help_array[index + 1])
        assert_equal("        long desc", help_array[index + 2])
        assert_equal(index + 3, help_array.size)
      end

      it "wraps long description" do
        long_desc = ["long desc", Toys::WrappableString.new("hello ruby world")]
        normal_tool.add_required_arg(:cc, long_desc: long_desc)
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false, wrap_width: 20).split("\n")
        index = help_array.index("POSITIONAL ARGUMENTS")
        refute_nil(index)
        assert_equal("    CC", help_array[index + 1])
        assert_equal("        long desc", help_array[index + 2])
        assert_equal("        hello ruby", help_array[index + 3])
        assert_equal("        world", help_array[index + 4])
        assert_equal(index + 5, help_array.size)
      end
    end

    describe "subtools section" do
      it "is not present for a normal tool" do
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("TOOLS")
        assert_nil(index)
      end

      it "shows subtools non-recursively" do
        help = Toys::Utils::HelpText.new(namespace_tool, namespace_loader, executable_name)
        help_array = help.help_string(styled: false).split("\n")
        index = help_array.index("TOOLS")
        refute_nil(index)
        assert_equal("    one", help_array[index + 1])
        assert_equal("    two", help_array[index + 2])
        assert_equal(index + 3, help_array.size)
      end

      it "shows hidden tools when requested" do
        help = Toys::Utils::HelpText.new(namespace_tool, namespace_loader, executable_name)
        help_array = help.help_string(styled: false, include_hidden: true).split("\n")
        index = help_array.index("TOOLS")
        refute_nil(index)
        assert_equal("    _three", help_array[index + 1])
        assert_equal("    one", help_array[index + 2])
        assert_equal("    two", help_array[index + 3])
        assert_equal(index + 4, help_array.size)
      end

      it "shows recursively omitting redundant namespaces" do
        help = Toys::Utils::HelpText.new(recursive_namespace_tool, recursive_namespace_loader,
                                         executable_name)
        help_array = help.help_string(styled: false, recursive: true).split("\n")
        index = help_array.index("TOOLS")
        refute_nil(index)
        assert_equal("    one a", help_array[index + 1])
        assert_equal("    one b", help_array[index + 2])
        assert_equal("    two", help_array[index + 3])
        assert_equal(index + 4, help_array.size)
      end

      it "shows recursively including namespaces when requested" do
        help = Toys::Utils::HelpText.new(recursive_namespace_tool, recursive_namespace_loader,
                                         executable_name)
        help_array = help.help_string(styled: false, recursive: true,
                                      include_hidden: true).split("\n")
        index = help_array.index("TOOLS")
        refute_nil(index)
        assert_equal("    one", help_array[index + 1])
        assert_equal("    one a", help_array[index + 2])
        assert_equal("    one b", help_array[index + 3])
        assert_equal("    two", help_array[index + 4])
        assert_equal(index + 5, help_array.size)
      end

      it "shows subtool desc" do
        subtool_one.desc = "one desc"
        subtool_one.long_desc = ["long desc"]
        subtool_two.desc = Toys::WrappableString.new("two desc on two lines")
        help = Toys::Utils::HelpText.new(namespace_tool, namespace_loader, executable_name)
        help_array = help.help_string(styled: false, wrap_width: 20).split("\n")
        index = help_array.index("TOOLS")
        refute_nil(index)
        assert_equal("    one - one desc", help_array[index + 1])
        assert_equal("    two - two desc", help_array[index + 2])
        assert_equal("        on two lines", help_array[index + 3])
        assert_equal(index + 4, help_array.size)
      end
    end
  end

  describe "list string" do
    it "shows subtools non-recursively" do
      help = Toys::Utils::HelpText.new(namespace_tool, namespace_loader, executable_name)
      list_array = help.list_string(styled: false).split("\n")
      assert_equal("List of tools under foo bar:", list_array[0])
      assert_equal("", list_array[1])
      assert_equal("one", list_array[2])
      assert_equal("two", list_array[3])
      assert_equal(4, list_array.size)
    end

    it "shows hidden subtools when requested" do
      help = Toys::Utils::HelpText.new(namespace_tool, namespace_loader, executable_name)
      list_array = help.list_string(styled: false, include_hidden: true).split("\n")
      assert_equal("List of tools under foo bar:", list_array[0])
      assert_equal("", list_array[1])
      assert_equal("_three", list_array[2])
      assert_equal("one", list_array[3])
      assert_equal("two", list_array[4])
      assert_equal(5, list_array.size)
    end

    it "shows subtools recursively omitting redundant namespaces" do
      help = Toys::Utils::HelpText.new(recursive_namespace_tool, recursive_namespace_loader,
                                       executable_name)
      list_array = help.list_string(styled: false, recursive: true).split("\n")
      assert_equal("Recursive list of tools under foo bar:", list_array[0])
      assert_equal("", list_array[1])
      assert_equal("one a", list_array[2])
      assert_equal("one b", list_array[3])
      assert_equal("two", list_array[4])
      assert_equal(5, list_array.size)
    end

    it "shows subtools recursively including namespaces when requested" do
      help = Toys::Utils::HelpText.new(recursive_namespace_tool, recursive_namespace_loader,
                                       executable_name)
      list_array = help.list_string(styled: false, recursive: true,
                                    include_hidden: true).split("\n")
      assert_equal("Recursive list of tools under foo bar:", list_array[0])
      assert_equal("", list_array[1])
      assert_equal("one", list_array[2])
      assert_equal("one a", list_array[3])
      assert_equal("one b", list_array[4])
      assert_equal("two", list_array[5])
      assert_equal(6, list_array.size)
    end

    it "shows subtool desc" do
      subtool_one.desc = "one desc"
      subtool_one.long_desc = ["long desc"]
      subtool_two.desc = Toys::WrappableString.new("two desc on two lines")
      help = Toys::Utils::HelpText.new(namespace_tool, namespace_loader, executable_name)
      list_array = help.list_string(styled: false, wrap_width: 16).split("\n")
      assert_equal("List of tools under foo bar:", list_array[0])
      assert_equal("", list_array[1])
      assert_equal("one - one desc", list_array[2])
      assert_equal("two - two desc", list_array[3])
      assert_equal("    on two lines", list_array[4])
      assert_equal(5, list_array.size)
    end
  end

  describe "usage string" do
    describe "synopsis" do
      it "is set for a namespace" do
        help = Toys::Utils::HelpText.new(namespace_tool, namespace_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar TOOL [ARGUMENTS...]", usage_array[0])
        assert_equal("        toys foo bar", usage_array[1])
        assert_equal("", usage_array[2])
      end

      it "is set for a namespace that is runnable" do
        help = Toys::Utils::HelpText.new(runnable_namespace_tool, runnable_namespace_loader,
                                         executable_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar TOOL [ARGUMENTS...]", usage_array[0])
        assert_equal("        toys foo bar", usage_array[1])
        assert_equal("", usage_array[2])
      end

      it "is set for a normal tool with no flags" do
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar", usage_array[0])
        assert_equal(1, usage_array.size)
      end

      it "is set for a normal tool with flags" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar [FLAGS...]", usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a normal tool with required args" do
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar CC DD", usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a normal tool with optional args" do
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar [EE] [FF]", usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a normal tool with remaining args" do
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar [GG...]", usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a normal tool with the kitchen sink" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa")
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        assert_equal("Usage:  toys foo bar [FLAGS...] CC DD [EE] [FF] [GG...]",
                     usage_array[0])
        assert_equal("", usage_array[1])
      end

      it "is set for a delegating tool" do
        help = Toys::Utils::HelpText.new(delegating_tool, delegation_loader, executable_name,
                                         delegate_target: tool_name)
        usage_array = help.usage_string.split("\n")
        assert_equal('Usage:  toys foo baz [ARGUMENTS FOR "foo bar"...]', usage_array[0])
        assert_equal(1, usage_array.size)
      end
    end

    describe "subtools section" do
      it "is not present for a normal tool" do
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Tools:")
        assert_nil(index)
      end

      it "shows subtools non-recursively" do
        help = Toys::Utils::HelpText.new(namespace_tool, namespace_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}one\s{30}$/, usage_array[index + 1])
        assert_match(/^\s{4}two\s{30}$/, usage_array[index + 2])
        assert_equal(index + 3, usage_array.size)
      end

      it "shows hidden subtools when requested" do
        help = Toys::Utils::HelpText.new(namespace_tool, namespace_loader, executable_name)
        usage_array = help.usage_string(include_hidden: true).split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}_three\s{27}$/, usage_array[index + 1])
        assert_match(/^\s{4}one\s{30}$/, usage_array[index + 2])
        assert_match(/^\s{4}two\s{30}$/, usage_array[index + 3])
        assert_equal(index + 4, usage_array.size)
      end

      it "shows subtools recursive" do
        help = Toys::Utils::HelpText.new(recursive_namespace_tool, recursive_namespace_loader,
                                         executable_name)
        usage_array = help.usage_string(recursive: true).split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}one a\s{28}$/, usage_array[index + 1])
        assert_match(/^\s{4}one b\s{28}$/, usage_array[index + 2])
        assert_match(/^\s{4}two\s{30}$/, usage_array[index + 3])
        assert_equal(index + 4, usage_array.size)
      end

      it "shows subtools including namespaces when requested" do
        help = Toys::Utils::HelpText.new(recursive_namespace_tool, recursive_namespace_loader,
                                         executable_name)
        usage_array = help.usage_string(recursive: true, include_hidden: true).split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}one\s{30}$/, usage_array[index + 1])
        assert_match(/^\s{4}one a\s{28}$/, usage_array[index + 2])
        assert_match(/^\s{4}one b\s{28}$/, usage_array[index + 3])
        assert_match(/^\s{4}two\s{30}$/, usage_array[index + 4])
        assert_equal(index + 5, usage_array.size)
      end

      it "shows subtool desc" do
        subtool_one.desc = "one desc"
        subtool_two.desc = Toys::WrappableString.new("two desc on two lines")
        help = Toys::Utils::HelpText.new(namespace_tool, namespace_loader, executable_name)
        usage_array = help.usage_string(wrap_width: 49).split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}one\s{30}one desc$/, usage_array[index + 1])
        assert_match(/^\s{4}two\s{30}two desc on$/, usage_array[index + 2])
        assert_match(/^\s{37}two lines$/, usage_array[index + 3])
        assert_equal(index + 4, usage_array.size)
      end

      it "shows desc for long subtool name" do
        subtool_long.desc = Toys::WrappableString.new("long desc on two lines")
        help = Toys::Utils::HelpText.new(long_namespace_tool, long_namespace_loader,
                                         executable_name)
        usage_array = help.usage_string(wrap_width: 49).split("\n")
        index = usage_array.index("Tools:")
        refute_nil(index)
        assert_match(/^\s{4}#{long_tool_name}$/, usage_array[index + 1])
        assert_match(/^\s{37}long desc on$/, usage_array[index + 2])
        assert_match(/^\s{37}two lines$/, usage_array[index + 3])
        assert_equal(index + 4, usage_array.size)
      end
    end

    describe "positional args section" do
      it "is not present for a namespace" do
        help = Toys::Utils::HelpText.new(namespace_tool, namespace_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Positional arguments:")
        assert_nil(index)
      end

      it "is not present for a normal tool with no positional args" do
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Positional arguments:")
        assert_nil(index)
      end

      it "is set for a normal tool with positional args" do
        normal_tool.add_required_arg(:cc, desc: "set cc")
        normal_tool.add_required_arg(:dd, desc: "set dd")
        normal_tool.add_optional_arg(:ee, desc: "set ee")
        normal_tool.add_optional_arg(:ff, desc: "set ff")
        normal_tool.set_remaining_args(:gg, desc: "set gg")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Positional arguments:")
        refute_nil(index)
        assert_match(/^\s{4}CC\s{31}set cc$/, usage_array[index + 1])
        assert_match(/^\s{4}DD\s{31}set dd$/, usage_array[index + 2])
        assert_match(/^\s{4}\[EE\]\s{29}set ee$/, usage_array[index + 3])
        assert_match(/^\s{4}\[FF\]\s{29}set ff$/, usage_array[index + 4])
        assert_match(/^\s{4}\[GG\.\.\.\]\s{26}set gg$/, usage_array[index + 5])
        assert_equal(index + 6, usage_array.size)
      end

      it "shows desc for long arg" do
        normal_tool.add_required_arg(:long_long_long_long_long_long_long_long,
                                     desc: Toys::WrappableString.new("set long arg desc"))
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string(wrap_width: 47).split("\n")
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
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Flags:")
        assert_nil(index)
      end

      it "is set for a tool with flags in the default group" do
        normal_tool.add_flag(:aa, ["-a", "--aa=VALUE"], desc: "set aa")
        normal_tool.add_flag(:bb, ["--[no-]bb"], desc: "set bb")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Flags:")
        refute_nil(index)
        assert_match(/^\s{4}-a, --aa=VALUE\s{19}set aa$/, usage_array[index + 1])
        assert_match(/^\s{8}--\[no-\]bb\s{20}set bb$/, usage_array[index + 2])
        assert_equal(index + 3, usage_array.size)
      end

      it "shows value only for last flag" do
        normal_tool.add_flag(:aa, ["-a VALUE", "--aa"], desc: "set aa")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Flags:")
        refute_nil(index)
        assert_match(/^\s{4}-a, --aa VALUE\s{19}set aa$/, usage_array[index + 1])
        assert_equal(index + 2, usage_array.size)
      end

      it "orders single dashes before double dashes" do
        normal_tool.add_flag(:aa, ["--aa", "-a VALUE"], desc: "set aa")
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        index = usage_array.index("Flags:")
        refute_nil(index)
        assert_match(/^\s{4}-a, --aa VALUE\s{19}set aa$/, usage_array[index + 1])
        assert_equal(index + 2, usage_array.size)
      end

      it "shows separate sections per flag group" do
        normal_tool.add_flag_group(type: :required, name: :required, prepend: true,
                                   desc: "Required Flags", long_desc: "List of required args")
        normal_tool.add_flag(:opt1, ["--opt1=VAL"])
        normal_tool.add_flag(:opt2, ["--opt2=VAL"])
        normal_tool.add_flag(:req1, ["--req1=VAL"], group: :required)
        normal_tool.add_flag(:req2, ["--req2=VAL"], group: :required)
        help = Toys::Utils::HelpText.new(normal_tool, single_loader, executable_name)
        usage_array = help.usage_string.split("\n")
        req_index = usage_array.index("Required Flags:")
        opt_index = usage_array.index("Flags:")
        assert(req_index < opt_index)
        assert_match(/^\s{8}--req1=VAL/, usage_array[req_index + 1])
        assert_match(/^\s{8}--req2=VAL/, usage_array[req_index + 2])
        assert_match(/^\s{8}--opt1=VAL/, usage_array[opt_index + 1])
        assert_match(/^\s{8}--opt2=VAL/, usage_array[opt_index + 2])
      end
    end
  end
end
