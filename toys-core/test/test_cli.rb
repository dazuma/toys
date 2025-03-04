# frozen_string_literal: true

require "helper"

require "toys/utils/exec"
require "toys/utils/standard_ui"

describe Toys::CLI do
  let(:logger_io) { ::StringIO.new }
  let(:logger) {
    Logger.new(logger_io).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(
      executable_name: executable_name,
      logger: logger,
      middleware_stack: [],
      index_file_name: ".toys.rb",
      data_dir_name: ".data",
      lib_dir_name: ".lib",
      extra_delimiters: ":"
    )
  }
  let(:lookup_cases_dir) { File.join(File.dirname(__dir__), "test-data", "lookup-cases") }

  describe "execution" do
    it "returns the exit value" do
      cli.add_config_block do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      assert_equal(3, cli.run("foo"))
    end

    it "handles no script defined" do
      cli.add_config_block do
        tool "foo" do
          # Empty tool
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo")
      end
      assert_kind_of(Toys::NotRunnableError, error.cause)
    end

    it "can disable argument parsing" do
      test = self
      cli.add_config_block do
        tool "foo" do
          disable_argument_parsing
          to_run do
            test.assert_equal(["baz", "--bar"], args)
            test.assert(usage_errors.empty?)
          end
        end
      end
      cli.run("foo", "baz", "--bar")
    end

    it "runs initializer at the beginning" do
      test = self
      cli.add_config_block do
        tool "foo" do
          t = Toys::DSL::Internal.current_tool(self, true)
          t.add_initializer(proc { |a| set(:a, a) }, 123)
          to_run do
            test.assert_equal(123, get(:a))
          end
        end
      end
      cli.run("foo")
    end

    it "makes context fields available via convenience methods" do
      test = self
      cli.add_config_block do
        tool "foo" do
          optional_arg(:arg1)
          optional_arg(:arg2)
          flag(:sw1, "-a")
          to_run do
            test.assert_equal(0, verbosity)
            test.assert_equal(["foo"], tool_name)
            test.assert_instance_of(Logger, logger)
            test.assert_equal("toys", cli.executable_name)
            test.assert_equal(["hello", "-a"], args)
            test.assert_equal({arg1: "hello", arg2: nil, sw1: true}, options)
          end
        end
      end
      cli.run(["foo", "hello", "-a"])
    end

    it "makes context fields available via get" do
      test = self
      cli.add_config_block do
        tool "foo" do
          optional_arg(:arg1)
          optional_arg(:arg2)
          flag(:sw1, "-a")
          to_run do
            test.assert_equal(0, get(Toys::Context::Key::VERBOSITY))
            test.assert_equal(["foo"], get(Toys::Context::Key::TOOL).full_name)
            test.assert_equal(["foo"], get(Toys::Context::Key::TOOL_NAME))
            test.assert_instance_of(Logger, get(Toys::Context::Key::LOGGER))
            test.assert_equal("toys", get(Toys::Context::Key::CLI).executable_name)
            test.assert_equal(["hello", "-a"], get(Toys::Context::Key::ARGS))
          end
        end
      end
      cli.run(["foo", "hello", "-a"])
    end

    it "makes options available via get" do
      test = self
      cli.add_config_block do
        tool "foo" do
          optional_arg(:arg1)
          optional_arg(:arg2)
          flag(:sw1, "-a")
          to_run do
            test.assert_equal(true, get(:sw1))
            test.assert_equal("hello", get(:arg1))
            test.assert_nil(get(:arg2))
          end
        end
      end
      cli.run(["foo", "hello", "-a"])
    end

    it "supports sub-runs" do
      test = self
      cli.add_config_block do
        tool "foo" do
          optional_arg :arg1
          to_run do
            test.assert_equal("hi", self[:arg1])
            exit(cli.run("bar", "ho"))
          end
        end
        tool "bar" do
          optional_arg :arg2
          to_run do
            test.assert_equal("ho", self[:arg2])
            exit(3)
          end
        end
      end
      assert_equal(3, cli.run(["foo", "hi"]))
    end

    it "accesses data from run" do
      cli.loader.add_path(File.join(lookup_cases_dir, "data-finder"))
      assert_equal(0, cli.run("ns-1", "ns-1a", "foo"))
    end

    it "accesses lib directory" do
      skip unless Toys::Compat.allow_fork?
      cli.loader.add_path(File.join(lookup_cases_dir, "lib-dirs"))
      func = proc do
        puts cli.run("foo")
      end
      result = Toys::Utils::Exec.new.capture_proc(func)
      assert_equal("7\n", result)
    end

    it "accesses lib directory with overrides" do
      skip unless Toys::Compat.allow_fork?
      cli.loader.add_path(File.join(lookup_cases_dir, "lib-dirs"))
      func = proc do
        puts cli.run("ns", "bar")
      end
      result = Toys::Utils::Exec.new.capture_proc(func)
      assert_equal("9\n", result)
    end

    it "recognizes delimiters" do
      cli.add_config_block do
        tool "foo" do
          tool "bar" do
            def run
              exit(3)
            end
          end
        end
      end
      assert_equal(3, cli.run("foo:bar"))
    end
  end

  describe "error handling" do
    it "raises the error by default" do
      cli.add_config_block do
        tool "foo" do
          def run
            raise "whoops"
          end
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo")
      end
      assert_equal("whoops", error.cause.message)
    end

    it "supports a custom handler that receives definition errors" do
      my_handler = proc do |error|
        assert_nil(error.tool_name)
        assert_includes(error.config_path, "/errors/definition.rb")
        assert_kind_of(NameError, error.cause)
        9
      end
      my_cli = cli.child(error_handler: my_handler)
      my_cli.loader.add_path(File.join(lookup_cases_dir, "errors"))
      assert_equal(9, my_cli.run("definition"))
    end

    it "supports a custom handler that receives runtime errors" do
      my_handler = proc do |error|
        assert_equal(["runtime", "hello"], error.tool_name)
        assert_includes(error.config_path, "/errors/runtime.rb")
        assert_kind_of(NameError, error.cause)
        10
      end
      my_cli = cli.child(error_handler: my_handler)
      my_cli.loader.add_path(File.join(lookup_cases_dir, "errors"))
      assert_equal(10, my_cli.run("runtime", "hello"))
    end

    it "supports a custom handler that receives signals" do
      my_handler = proc do |error|
        cause = error.cause
        assert_kind_of(SignalException, cause)
        assert_equal(4, cause.signo)
        12
      end
      my_cli = cli.child(error_handler: my_handler)
      my_cli.add_config_block do
        tool "foo" do
          def run
            raise SignalException, 4
          end
        end
      end
      assert_equal(12, my_cli.run("foo"))
    end
  end

  describe "signal_handling" do
    it "raises the signal by default" do
      cli.add_config_block do
        tool "foo" do
          def run
            raise SignalException, 4
          end
        end
      end
      error = assert_raises(SignalException) do
        cli.run("foo")
      end
      assert_equal(4, error.signo)
    end

    it "executes a signal handler block that matches the signal" do
      cli.add_config_block do
        tool "foo" do
          def run
            raise SignalException, 15
          end

          on_signal(15) do
            exit(16)
          end
        end
      end
      assert_equal(16, cli.run("foo"))
    end

    it "bypasses a signal handler block that doesn't match the signal" do
      cli.add_config_block do
        tool "foo" do
          def run
            raise SignalException, 15
          end

          on_signal(4) do
            exit(2)
          end
        end
      end
      error = assert_raises(SignalException) do
        cli.run("foo")
      end
      assert_equal(15, error.signo)
    end

    it "supports an interrupt block with no argument" do
      cli.add_config_block do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt do
            exit(2)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "supports propagating an interrupt" do
      cli.add_config_block do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt do |ex|
            raise ex
          end
        end
      end
      assert_raises(Interrupt) do
        cli.run("foo")
      end
    end

    it "supports an interrupt block with an argument" do
      test = self
      cli.add_config_block do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt do |ex|
            test.assert_instance_of(::Interrupt, ex)
            exit(2)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "supports nested interrupts" do
      counter = 0
      cli.add_config_block do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt do |ex|
            counter += 1
            raise ::Interrupt if ex.cause.nil?
            exit(counter)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "supports an interrupt method with no argument" do
      cli.add_config_block do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt :int_handler

          def int_handler
            exit(2)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "supports an interrupt method with an argument" do
      cli.add_config_block do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          def int_handler(exception)
            exit(exception.is_a?(::Interrupt) ? 2 : 3)
          end

          on_interrupt :int_handler
        end
      end
      assert_equal(2, cli.run("foo"))
    end
  end

  describe "usage error handling" do
    it "passes the exception out by default" do
      cli.add_config_block do
        tool "foo" do
          def run; end
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo", "--bar")
      end
      usage_errors = error.cause.usage_errors
      assert(usage_errors.any? { |ue| ue.message == "Flag \"--bar\" is not recognized." })
    end

    it "supports setting the handler back to the default" do
      cli.add_config_block do
        tool "foo" do
          on_usage_error :run
          on_usage_error nil

          def run; end
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo", "--bar")
      end
      usage_errors = error.cause.usage_errors
      assert(usage_errors.any? { |ue| ue.message == "Flag \"--bar\" is not recognized." })
    end

    it "supports redirecting back to run" do
      cli.add_config_block do
        tool "foo" do
          on_usage_error :run

          def run
            exit usage_errors.size
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end

    it "supports invoking a method with no argument" do
      cli.add_config_block do
        tool "foo" do
          on_usage_error :usage_handler

          def run
            exit(-1)
          end

          def usage_handler
            exit usage_errors.size
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end

    it "supports invoking a method with an argument" do
      cli.add_config_block do
        tool "foo" do
          on_usage_error :usage_handler

          def run
            exit(-1)
          end

          def usage_handler(errs)
            exit errs.size
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end

    it "supports invoking a block with no argument" do
      cli.add_config_block do
        tool "foo" do
          on_usage_error do
            exit usage_errors.size
          end

          def run
            exit(-1)
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end

    it "supports invoking a block with no argument" do
      cli.add_config_block do
        tool "foo" do
          on_usage_error do |errs|
            exit errs.size
          end

          def run
            exit(-1)
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end
  end

  describe "directive alterations" do
    it "allows partial flag match" do
      cli.add_config_block do
        tool "foo" do
          flag :abcde
          def run
            exit(0)
          end
        end
      end
      assert_equal(0, cli.run("foo", "--abc"))
    end

    it "requires exact flag match" do
      cli.add_config_block do
        tool "foo" do
          flag :abcde
          require_exact_flag_match
          def run
            exit(0)
          end
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo", "--abc")
      end
      assert_equal('Flag "--abc" is not recognized.', error.cause.usage_errors.first.message)
    end
  end

  describe "child" do
    let(:logger2) {
      Logger.new(logger_io).tap do |lgr|
        lgr.level = Logger::DEBUG
      end
    }

    it "resets tool blocks" do
      cli.add_config_block do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      child = cli.child
      child.add_config_block do
        tool "foo" do
          def run
            exit(4)
          end
        end
      end
      assert_equal(4, child.run("foo"))
    end

    it "copies parameters" do
      assert_same(logger, cli.logger_factory.call)
      child = cli.child
      assert_same(logger, child.logger_factory.call)
    end

    it "overrides parameters" do
      assert_same(logger, cli.logger_factory.call)
      child = cli.child(logger: logger2)
      assert_same(logger2, child.logger_factory.call)
    end
  end
end
