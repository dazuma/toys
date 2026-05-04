# frozen_string_literal: true

require "helper"
require "toys/utils/exec"

describe "toys e2e" do
  let(:exec_service) { Toys::Utils::Exec.new }
  let(:e2e_cases_dir) { File.join(File.dirname(__dir__), "test-data", "e2e-cases") }

  def run_toys(*args, **opts)
    exec_service.exec_ruby([Toys.executable_path, *args], **opts)
  end

  describe "loading tools from .toys.rb" do
    it "runs a simple tool that prints hello world" do
      result = run_toys("greet", chdir: "#{e2e_cases_dir}/simple", out: :capture, err: :capture)
      assert(result.success?)
      assert_equal("hello world\n", result.captured_out)
    end

    it "displays exception message and source location on failure" do
      toys_rb = File.join(e2e_cases_dir, "exception", ".toys.rb")
      result = run_toys("boom", chdir: "#{e2e_cases_dir}/exception", out: :capture, err: :capture)
      refute(result.success?)
      assert_includes(result.captured_err, "RuntimeError: something went wrong")
      assert_includes(result.captured_err, "in config file: #{toys_rb}:5")
    end

    it "reports tool not found with exit code 2" do
      result = run_toys("nonexistent", chdir: "#{e2e_cases_dir}/simple", out: :capture, err: :capture)
      refute(result.success?)
      assert_equal(2, result.exit_code)
      assert_includes(result.captured_err, "Tool not found: \"nonexistent\"")
    end

    it "passes flags and arguments to a tool" do
      plain = run_toys("echo", "hello", chdir: "#{e2e_cases_dir}/simple", out: :capture, err: :capture)
      assert(plain.success?)
      assert_equal("hello\n", plain.captured_out)

      shouted = run_toys("echo", "--shout", "hello", chdir: "#{e2e_cases_dir}/simple",
                         out: :capture, err: :capture)
      assert(shouted.success?)
      assert_equal("HELLO\n", shouted.captured_out)
    end

    it "runs a namespaced subtool" do
      result = run_toys("calc", "add", "3", "4", chdir: "#{e2e_cases_dir}/simple",
                        out: :capture, err: :capture)
      assert(result.success?)
      assert_equal("7\n", result.captured_out)
    end

    it "finds .toys.rb by walking up the directory tree" do
      result = run_toys("greet", chdir: "#{e2e_cases_dir}/simple/subdir", out: :capture, err: :capture)
      assert(result.success?)
      assert_equal("hello world\n", result.captured_out)
    end
  end

  describe "built-in tools" do
    it "reports the toys version" do
      result = run_toys("system", "version", out: :capture, err: :capture)
      assert(result.success?)
      assert_match(/\A\d+\.\d+\.\d+\n\z/, result.captured_out)
    end
  end
end
