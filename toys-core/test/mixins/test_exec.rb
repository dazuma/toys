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
require "toys/standard_mixins/exec"

class FakeProcessStatus
  def initialize(exitstatus)
    @exitstatus = exitstatus
  end
  attr_reader :exitstatus
end

describe Toys::StandardMixins::Exec do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: [])
  }

  it "executes a shell command" do
    cli.add_config_block do
      tool "foo" do
        include :exec
        def run
          result = sh('FOO=bar; test "$FOO" = foo')
          exit result
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "executes a unix command" do
    cli.add_config_block do
      tool "foo" do
        include :exec
        def run
          result = exec(["echo", "hello"], out: :capture)
          exit(result.captured_out == "hello\n" ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "executes a ruby command" do
    cli.add_config_block do
      tool "foo" do
        include :exec
        def run
          result = exec_ruby(["-e", "puts 'hello'"], out: :capture)
          exit(result.captured_out == "hello\n" ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "executes a proc" do
    cli.add_config_block do
      tool "foo" do
        include :exec
        def run
          result = exec_proc(proc { puts "hello" }, out: :capture)
          exit(result.captured_out == "hello\n" ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "executes a toys tool" do
    cli.add_config_block do
      tool "bar" do
        def run
          puts "hello"
        end
      end
      tool "foo" do
        include :exec
        def run
          result = exec_tool(["bar"], out: :capture)
          exit(result.captured_out == "hello\n" ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "captures a unix command" do
    cli.add_config_block do
      tool "foo" do
        include :exec
        def run
          result = capture(["echo", "hello"])
          exit(result == "hello\n" ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "captures a ruby command" do
    cli.add_config_block do
      tool "foo" do
        include :exec
        def run
          result = capture_ruby(["-e", "puts 'hello'"])
          exit(result == "hello\n" ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "captures a proc" do
    cli.add_config_block do
      tool "foo" do
        include :exec
        def run
          result = capture_proc(proc { puts "hello" })
          exit(result == "hello\n" ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "captures a toys tool" do
    cli.add_config_block do
      tool "bar" do
        def run
          puts "hello"
        end
      end
      tool "foo" do
        include :exec
        def run
          result = capture_tool(["bar"])
          exit(result == "hello\n" ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "does not exit on nonzero status by default" do
    cli.add_config_block do
      tool "foo" do
        include :exec
        def run
          exec(["false"])
          exit(0)
        end
      end
    end
    assert_equal(0, cli.run("foo"))
  end

  it "configures exit_on_nonzero_status" do
    cli.add_config_block do
      tool "foo" do
        include :exec
        def run
          configure_exec(exit_on_nonzero_status: true)
          exec(["false"])
          exit(0)
        end
      end
    end
    refute_equal(0, cli.run("foo"))
  end

  it "handles a proc as a result callback" do
    cli.add_config_block do
      tool "foo" do
        include :exec
        def run
          configure_exec(
            result_callback: proc do |r|
              exit(r.exit_code)
            end
          )
          exec(["false"])
          exit(0)
        end
      end
    end
    refute_equal(0, cli.run("foo"))
  end

  it "handles a method as a result callback" do
    cli.add_config_block do
      tool "foo" do
        include :exec

        def callback(result)
          exit(result.exit_code)
        end

        def run
          configure_exec(result_callback: :callback)
          exec(["false"])
          exit(0)
        end
      end
    end
    refute_equal(0, cli.run("foo"))
  end

  describe "include options" do
    it "supports a stream option" do
      cli.add_config_block do
        tool "foo" do
          include :exec, out: :capture
          def run
            result = exec(["echo", "hello"])
            exit(result.captured_out == "hello\n" ? 1 : 2)
          end
        end
      end
      assert_equal(1, cli.run("foo"))
    end

    it "supports exit_on_nonzero_status" do
      cli.add_config_block do
        tool "foo" do
          include :exec, exit_on_nonzero_status: true
          def run
            exec(["false"])
          end
        end
      end
      refute_equal(0, cli.run("foo"))
    end

    it "supports a proc as a result_callback" do
      cli.add_config_block do
        tool "foo" do
          callback = proc do |result, context|
            context.exit(result.exit_code)
          end
          include :exec, result_callback: callback
          def run
            exec(["false"])
          end
        end
      end
      refute_equal(0, cli.run("foo"))
    end

    it "supports a method name as a result_callback" do
      cli.add_config_block do
        tool "foo" do
          include :exec, result_callback: :callback

          def run
            exec(["false"])
          end

          def callback(result)
            exit(result.exit_code)
          end
        end
      end
      refute_equal(0, cli.run("foo"))
    end
  end

  describe "exit_on_nonzero_status method" do
    let(:ok_process_status) { FakeProcessStatus.new(0) }
    let(:ok_exec_result) { Toys::Utils::Exec::Result.new(nil, nil, nil, ok_process_status, nil) }
    let(:error_process_status) { FakeProcessStatus.new(2) }
    let(:error_exec_result) {
      Toys::Utils::Exec::Result.new(nil, nil, nil, error_process_status, nil)
    }

    it "handles ok result object" do
      result = ok_exec_result
      cli.add_config_block do
        tool "foo" do
          include :exec
          to_run do
            exit_on_nonzero_status(result)
            exit(3)
          end
        end
      end
      assert_equal(3, cli.run("foo"))
    end

    it "handles ok process status" do
      status = ok_process_status
      cli.add_config_block do
        tool "foo" do
          include :exec
          to_run do
            exit_on_nonzero_status(status)
            exit(3)
          end
        end
      end
      assert_equal(3, cli.run("foo"))
    end

    it "handles ok integer" do
      cli.add_config_block do
        tool "foo" do
          include :exec
          to_run do
            exit_on_nonzero_status(0)
            exit(3)
          end
        end
      end
      assert_equal(3, cli.run("foo"))
    end

    it "handles error result object" do
      result = error_exec_result
      cli.add_config_block do
        tool "foo" do
          include :exec
          to_run do
            exit_on_nonzero_status(result)
            exit(3)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "handles error process status" do
      status = error_process_status
      cli.add_config_block do
        tool "foo" do
          include :exec
          to_run do
            exit_on_nonzero_status(status)
            exit(3)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "handles error integer" do
      cli.add_config_block do
        tool "foo" do
          include :exec
          to_run do
            exit_on_nonzero_status(2)
            exit(3)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end
  end
end
