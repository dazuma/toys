# frozen_string_literal: true

require "helper"
require "toys/testing"

describe Toys::Testing do
  let(:class_testing) do
    Class.new do
      include Toys::Testing
    end
  end
  let(:empty_testing) { class_testing.new }
  let(:configured_testing) do
    testing = empty_testing
    testing.class.toys_custom_paths(File.join(__dir__, "testing-cases"))
    testing.class.toys_include_builtins(false)
    testing
  end

  describe "#toys_load_tool" do
    it "loads a tool" do
      configured_testing.toys_load_tool(["hello"]) do |tool|
        assert_equal("hello", tool.message)
      end
    end

    it "parses a command line string" do
      configured_testing.toys_load_tool("hello --shout") do |tool|
        assert_equal("HELLO", tool.message)
      end
    end

    it "reports that it fails to find a tool" do
      result_code = nil
      _out, err = capture_io do
        result_code = configured_testing.toys_load_tool(["bye"]) do
          flunk("Shouldn't get here")
          :whoops
        end
      end
      assert_includes(err, "Tool not found: \"bye\"")
      assert_equal(2, result_code)
    end
  end

  describe "#toys_run_tool" do
    it "returns the exit code" do
      result_code = configured_testing.toys_run_tool(["exit", "5"])
      assert_equal(5, result_code)
    end

    it "reports that it fails to find a tool" do
      result_code = nil
      _out, err = capture_io do
        result_code = configured_testing.toys_run_tool(["bye"])
      end
      assert_includes(err, "Tool not found: \"bye\"")
      assert_equal(2, result_code)
    end
  end

  describe "#toys_exec_tool" do
    before do
      skip unless Toys::Compat.allow_fork?
    end

    it "captures a tool's output" do
      result = configured_testing.toys_exec_tool(["hello"])
      assert_equal("hello hello\n", result.captured_out)
    end

    it "parses a command line string" do
      result = configured_testing.toys_exec_tool("hello --shout")
      assert_equal("HELLO HELLO\n", result.captured_out)
    end

    it "yields a controller" do
      result = configured_testing.toys_exec_tool(["hello"]) do |controller|
        assert_equal("hello hello\n", controller.out.read)
      end
      assert_equal(0, result.exit_code)
    end

    it "reports that it fails to find a tool" do
      result = configured_testing.toys_exec_tool(["bye"])
      assert_includes(result.captured_err, "Tool not found: \"bye\"")
      assert_equal(2, result.exit_code)
    end
  end
end
