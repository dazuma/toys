require "psych"
require "toys/utils/exec"

describe "toys system tools" do
  include Toys::Testing

  toys_custom_paths(::File.dirname(::File.dirname(__dir__)))
  toys_include_builtins(false)

  let(:toys_gem_dir) { ::File.dirname(::File.dirname(::File.dirname(__dir__))) }
  let(:toys_repo_dir) { ::File.dirname(toys_gem_dir) }

  def capture_system_tools_output(cmd, expected_status: 0, format: nil)
    out, _err = capture_subprocess_io do
      cmd += ["--format", format] if format
      status = toys_run_tool(["system", "tools"] + cmd)
      assert_equal(expected_status, status)
    end
    case format
    when nil, "yaml"
      assert_match(/^---/, out)
      ::Psych.load(out)
    when "json"
      assert_match(/^\{\n/, out)
      ::JSON.parse(out)
    when "json-compact"
      assert_match(/^\{\S/, out)
      ::JSON.parse(out)
    else
      flunk("Unrecognized format: #{format}")
    end
  end

  describe "list" do
    it "lists tools non-recursively" do
      result = capture_system_tools_output(["list"])
      assert_equal("", result["namespace"])
      system_tool = result["tools"].find { |t| t["name"] == "system" }
      refute_nil(system_tool)
      assert_equal("A set of system commands for Toys", system_tool["desc"])
      refute(system_tool["runnable"])
    end

    it "lists tools recursively" do
      result = capture_system_tools_output(["list", "--recursive"])
      assert_equal("", result["namespace"])
      system_tool = result["tools"].find { |t| t["name"] == "system" }
      tools_tool = system_tool["tools"].find { |t| t["name"] == "tools" }
      assert_equal("Tools that introspect available tools", tools_tool["desc"])
      refute(tools_tool["runnable"])
      list_tool = tools_tool["tools"].find { |t| t["name"] == "list" }
      assert_equal("Output a list of the tools under the given namespace.", list_tool["desc"])
      assert(list_tool["runnable"])
    end

    it "outputs a flattened list" do
      result = capture_system_tools_output(["list", "--recursive", "--flatten"])
      assert_equal("", result["namespace"])
      list_tool = result["tools"].find { |t| t["name"] == "system tools list" }
      assert_equal("Output a list of the tools under the given namespace.", list_tool["desc"])
      assert(list_tool["runnable"])
      system_tool = result["tools"].find { |t| t["name"] == "system" }
      assert_nil(system_tool)
    end

    it "shows namespaces when outputting a flattened list with --all" do
      result = capture_system_tools_output(["list", "--recursive", "--flatten", "--all"])
      assert_equal("", result["namespace"])
      list_tool = result["tools"].find { |t| t["name"] == "system tools list" }
      assert_equal("Output a list of the tools under the given namespace.", list_tool["desc"])
      assert(list_tool["runnable"])
      system_tool = result["tools"].find { |t| t["name"] == "system" }
      refute_nil(system_tool)
      assert_equal("A set of system commands for Toys", system_tool["desc"])
      refute(system_tool["runnable"])
    end

    it "lists tools recursively under a namespace" do
      result = capture_system_tools_output(["list", "--recursive", "system"])
      assert_equal("system", result["namespace"])
      tools_tool = result["tools"].find { |t| t["name"] == "tools" }
      assert_equal("Tools that introspect available tools", tools_tool["desc"])
      refute(tools_tool["runnable"])
      list_tool = tools_tool["tools"].find { |t| t["name"] == "list" }
      assert_equal("Output a list of the tools under the given namespace.", list_tool["desc"])
      assert(list_tool["runnable"])
    end

    it "recognizes deeper namespaces delimited by spaces" do
      result = capture_system_tools_output(["list", "--recursive", "system", "tools"])
      assert_equal("system tools", result["namespace"])
      list_tool = result["tools"].find { |t| t["name"] == "list" }
      assert_equal("Output a list of the tools under the given namespace.", list_tool["desc"])
      assert(list_tool["runnable"])
    end

    it "recognizes deeper namespaces delimited by dots" do
      result = capture_system_tools_output(["list", "--recursive", "system.tools"])
      assert_equal("system tools", result["namespace"])
      list_tool = result["tools"].find { |t| t["name"] == "list" }
      assert_equal("Output a list of the tools under the given namespace.", list_tool["desc"])
      assert(list_tool["runnable"])
    end

    it "lists only local tools from a directory" do
      result = capture_system_tools_output(["list", "--recursive", "--local", "--dir", toys_gem_dir])
      assert_equal("", result["namespace"])
      system_tool = result["tools"].find { |t| t["name"] == "system" }
      assert_nil(system_tool)
      ci_tool = result["tools"].find { |t| t["name"] == "ci" }
      assert_equal("Run all CI checks", ci_tool["desc"])
      assert(ci_tool["runnable"])
    end

    it "handles --dir pointing at a .toys dir" do
      dir = "#{toys_gem_dir}/.toys"
      result = capture_system_tools_output(["list", "--recursive", "--local", "--dir", dir])
      ci_tool = result["tools"].find { |t| t["name"] == "ci" }
      assert_equal("Run all CI checks", ci_tool["desc"])
      assert(ci_tool["runnable"])
    end

    it "lists tools non-recursively, outputting as json" do
      result = capture_system_tools_output(["list"], format: "json")
      assert_equal("", result["namespace"])
      system_tool = result["tools"].find { |t| t["name"] == "system" }
      refute_nil(system_tool)
      assert_equal("A set of system commands for Toys", system_tool["desc"])
      refute(system_tool["runnable"])
    end

    it "lists tools non-recursively, outputting as json-compact" do
      result = capture_system_tools_output(["list"], format: "json-compact")
      assert_equal("", result["namespace"])
      system_tool = result["tools"].find { |t| t["name"] == "system" }
      refute_nil(system_tool)
      assert_equal("A set of system commands for Toys", system_tool["desc"])
      refute(system_tool["runnable"])
    end

    it "displays the correct error if --dir doesn't exist" do
      out, err = capture_subprocess_io do
        cmd = ["system", "tools", "list", "--local", "--dir", "#{toys_gem_dir}/nope"]
        status = toys_run_tool(cmd)
        assert_equal(1, status)
      end
      assert_empty(out)
      assert_match(/Not a directory:/, err)
    end

    it "displays the correct error if --dir points at a file" do
      out, err = capture_subprocess_io do
        cmd = ["system", "tools", "list", "--local", "--dir", "#{toys_gem_dir}/README.md"]
        status = toys_run_tool(cmd)
        assert_equal(1, status)
      end
      assert_empty(out)
      assert_match(/Not a directory:/, err)
    end

    it "displays the correct error if --dir points inside a toys dir" do
      out, err = capture_subprocess_io do
        cmd = ["system", "tools", "list", "--local", "--dir", "#{toys_repo_dir}/.toys/release"]
        status = toys_run_tool(cmd)
        assert_equal(1, status)
      end
      assert_empty(out)
      assert_match(/Directory is inside a toys directory:/, err)
    end
  end

  describe "show" do
    it "shows a runnable tool" do
      result = capture_system_tools_output(["show", "system", "tools", "list"])
      assert_equal("system tools list", result["name"])
      assert_equal("Output a list of the tools under the given namespace.", result["desc"])
      assert(result["runnable"])
      assert(result["exists"])
    end

    it "shows a runnable tool specified using dots" do
      result = capture_system_tools_output(["show", "system.tools.list"])
      assert_equal("system tools list", result["name"])
      assert_equal("Output a list of the tools under the given namespace.", result["desc"])
      assert(result["runnable"])
      assert(result["exists"])
    end

    it "shows a namespace" do
      result = capture_system_tools_output(["show", "system", "tools"])
      assert_equal("system tools", result["name"])
      assert_equal("Tools that introspect available tools", result["desc"])
      refute(result["runnable"])
      assert(result["exists"])
    end

    it "shows a nonexistent tool" do
      result = capture_system_tools_output(["show", "system", "tools", "blahblah"], expected_status: 1)
      assert_equal("system tools blahblah", result["name"])
      refute_includes(result, "desc")
      refute(result["exists"])
    end

    it "shows a local tool from a directory" do
      result = capture_system_tools_output(["show", "--local", "--dir", toys_gem_dir, "ci"])
      assert_equal("ci", result["name"])
      assert_equal("Run all CI checks", result["desc"])
      assert(result["runnable"])
      assert(result["exists"])
    end

    it "omits tools not found in a local directory" do
      result = capture_system_tools_output(["show", "--local", "--dir", toys_gem_dir, "system"], expected_status: 1)
      assert_equal("system", result["name"])
      refute_includes(result, "desc")
      refute(result["exists"])
    end
  end
end
