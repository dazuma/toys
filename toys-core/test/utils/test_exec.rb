# frozen_string_literal: true

require "helper"
require "timeout"
require "toys/utils/exec"

# This is just a token set of smoke tests to ensure the library vendored
# correctly from its source in the exec_service gem. The full test suite is
# present in that gem's source.

describe Toys::Utils::Exec do
  let(:logger_stringio) { ::StringIO.new }
  let(:logger) { ::Logger.new(logger_stringio) }
  let(:exec_service) { Toys::Utils::Exec.new(logger: logger) }
  let(:simple_exec_timeout) { 5 }
  let(:ruby_exec_timeout) {
    Toys::Compat.jruby? || Toys::Compat.truffleruby? ? 10 : simple_exec_timeout
  }

  it "has the expected classes" do
    assert(defined?(::Toys::Utils::Exec))
    assert(defined?(::Toys::Utils::Exec::Controller))
    assert(defined?(::Toys::Utils::Exec::Result))
    assert(defined?(::Toys::Utils::Exec::Opts))
    assert(defined?(::Toys::Utils::Exec::Executor))
  end

  it "runs a simple command and gets a result" do
    ::Timeout.timeout(simple_exec_timeout) do
      result = exec_service.exec(["true"])
      assert_nil(result.exception)
      assert_instance_of(::Process::Status, result.status)
      assert_equal(0, result.exit_code)
      assert_nil(result.signal_code)
      assert_equal(0, result.effective_code)
      assert_equal(true, result.success?)
      assert_equal(false, result.error?)
      assert_equal(false, result.signaled?)
      assert_equal(false, result.failed?)
    end
  end

  it "captures output stream" do
    ::Timeout.timeout(simple_exec_timeout) do
      result = exec_service.capture(["echo", "hi"])
      assert_equal("hi\n", result)
      assert_match(/exec: \["echo", "hi"\]\n/, logger_stringio.string)
    end
  end

  it "forks procs" do
    skip "Skipped test because fork is not available" unless Toys::Compat.allow_fork?
    ::Timeout.timeout(simple_exec_timeout) do
      func = proc do
        puts "pid: #{::Process.pid}"
      end
      result = exec_service.exec_proc(func, out: :capture)
      match = /pid: (\d+)/.match(result.captured_out)
      refute_nil(match)
      refute_equal(match[1].to_i, ::Process.pid)
      assert_match(/exec proc:/, logger_stringio.string)
    end
  end

  it "yields to a controller" do
    ::Timeout.timeout(simple_exec_timeout) do
      result = exec_service.exec(["echo", "hi"], out: :capture, name: "my-echo") do |c|
        assert_equal("my-echo", c.name)
      end
      assert_equal("my-echo", result.name)
    end
  end

  it "runs ruby and handles stream redirect" do
    ::Timeout.timeout(ruby_exec_timeout) do
      result = exec_service.ruby(["-e", 'STDOUT.puts "hello"; STDERR.puts "world"'],
                                 out: :capture, err: [:child, :out])
      assert_match(/hello/, result.captured_out)
      assert_match(/world/, result.captured_out)
    end
  end
end
