# frozen_string_literal: true

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
    skip if Toys::Compat.windows?
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
    skip unless Toys::Compat.allow_fork?
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

  it "executes a toys tool in a fork" do
    skip unless Toys::Compat.allow_fork?
    cli.add_config_block do
      tool "bar" do
        def run
          puts "hello" if defined?(::Minitest)
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

  it "executes a toys tool in a spawned process" do
    cli.add_config_block do
      tool "foo" do
        include :exec
        def run
          result = nil
          Toys.stub(:executable_path, "toys-temp") do
            my_spawn = proc do |*args|
              cmd = args.find_all { |a| a.is_a?(::String) }
              if cmd[1..-1] == ["--disable=gems", "toys-temp", "bar"]
                nil
              else
                ::RuntimeError.new "Wrong args: #{args}"
              end
            end
            Process.stub(:spawn, my_spawn) do
              result = exec_separate_tool(["bar"])
            end
          end
          if result.exception
            puts result.exception.to_s
            exit(1)
          elsif result.status
            exit(2)
          else
            exit(4)
          end
        end
      end
    end
    assert_equal(4, cli.run("foo"))
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
    skip unless Toys::Compat.allow_fork?
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
    skip unless Toys::Compat.allow_fork?
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

  it "configures e" do
    cli.add_config_block do
      tool "foo" do
        include :exec
        def run
          configure_exec(e: true)
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

  describe "exit_on_nonzero_status option" do
    it "exits on nonzero status" do
      completed = false
      cli.add_config_block do
        tool "foo" do
          include :exec, exit_on_nonzero_status: true
          to_run do
            exec("exit 3")
            completed = true
          end
        end
      end
      assert_equal(3, cli.run("foo"))
      refute(completed)
    end

    it "exits on failure to spawn" do
      completed = false
      cli.add_config_block do
        tool "foo" do
          include :exec, exit_on_nonzero_status: true
          to_run do
            exec(["blahblahblah"])
            completed = true
          end
        end
      end
      assert_equal(127, cli.run("foo"))
      refute(completed)
    end

    it "exits on signal" do
      skip if Toys::Compat.windows?
      completed = false
      cli.add_config_block do
        tool "foo" do
          include :exec, exit_on_nonzero_status: true
          to_run do
            exec("sleep 5") do |controller|
              sleep(0.5)
              controller.kill("TERM")
            end
            completed = true
          end
        end
      end
      assert_equal(143, cli.run("foo"))
      refute(completed)
    end

    it "can be overridden to false" do
      completed = false
      cli.add_config_block do
        tool "foo" do
          include :exec, exit_on_nonzero_status: true
          to_run do
            exec(["false"], exit_on_nonzero_status: false)
            completed = true
          end
        end
      end
      assert_equal(0, cli.run("foo"))
      assert(completed)
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
