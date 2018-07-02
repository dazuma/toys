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
  let(:binary_name) { "toys" }
  let(:cli) { Toys::CLI.new(binary_name: binary_name, logger: logger, middleware_stack: []) }

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

  describe "exit_on_nonzero_status method" do
    let(:ok_process_status) { FakeProcessStatus.new(0) }
    let(:ok_exec_result) { Toys::Utils::Exec::Result.new(nil, nil, ok_process_status) }
    let(:error_process_status) { FakeProcessStatus.new(2) }
    let(:error_exec_result) { Toys::Utils::Exec::Result.new(nil, nil, error_process_status) }

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
