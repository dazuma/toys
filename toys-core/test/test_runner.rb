# frozen_string_literal: true

require "helper"
require "stringio"
require "toys/standard_middleware/show_help"

describe Toys::Runner do
  let(:logger_io) { ::StringIO.new }
  let(:logger) {
    Logger.new(logger_io).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:logger_factory) { proc { logger } }
  let(:cli) {
    Toys::CLI.new(
      executable_name: "toys",
      logger: logger,
      middleware_stack: [],
      index_file_name: ".toys.rb"
    )
  }
  let(:lookup_cases_dir) { File.join(File.dirname(__dir__), "test-data", "lookup-cases") }

  # Builds a runner against the default CLI's loader. Any keyword arguments are
  # passed to the constructor; per-run settings go to Runner#run instead.
  def make_runner(**opts)
    opts = {logger_factory: logger_factory}.merge(opts)
    Toys::Runner.new(cli.loader, **opts)
  end

  def add_delegation_config(&target_body)
    cli.add_config_block do
      tool "target" do
        remaining_args :rest
        to_run(&target_body)
      end
      tool "front" do
        delegate_to ["target"]
      end
    end
  end

  it "runs a tool and returns its exit code" do
    cli.add_config_block do
      tool "foo" do
        def run
          exit(3)
        end
      end
    end
    assert_equal(3, make_runner.run(["foo"]))
  end

  it "returns 0 when the tool completes normally" do
    test = self
    cli.add_config_block do
      tool "foo" do
        required_arg :bar
        to_run do
          test.assert_equal("hello", bar)
        end
      end
    end
    assert_equal(0, make_runner.run(["foo", "hello"]))
  end

  it "runs a given block in place of the tool's run handler" do
    test = self
    cli.add_config_block do
      tool "foo" do
        required_arg :bar
        to_run do
          test.flunk("Should not have called the tool's run handler")
        end
      end
    end
    called = false
    result = make_runner.run(["foo", "hello"]) do |context|
      called = true
      assert_equal("hello", context[:bar])
    end
    assert(called)
    assert_equal(0, result)
  end

  it "wraps a given block in the tool's middleware" do
    order = []
    middleware = ::Object.new
    middleware.define_singleton_method(:run) do |_context, &rest|
      order << :middleware
      rest.call
    end
    middleware_cli = Toys::CLI.new(logger: logger, middleware_stack: [middleware])
    test = self
    middleware_cli.add_config_block do
      tool "foo" do
        to_run do
          test.flunk("Should not have called the tool's run handler")
        end
      end
    end
    Toys::Runner.new(middleware_cli.loader).run(["foo"]) do |_context|
      order << :block
    end
    assert_equal([:middleware, :block], order)
  end

  it "honors the verbosity setting" do
    test = self
    cli.add_config_block do
      tool "foo" do
        to_run do
          test.assert_equal(2, verbosity)
          test.assert_equal(Logger::WARN - 2, logger.level)
        end
      end
    end
    assert_equal(0, make_runner.run(["foo"], verbosity: 2))
  end

  it "raises when the tool is not runnable" do
    cli.add_config_block do
      tool "foo" do
        # Empty tool
      end
    end
    err = assert_raises(Toys::ContextualError) do
      make_runner.run(["foo"])
    end
    assert_kind_of(Toys::NotRunnableError, err.cause)
  end

  describe "reuse" do
    it "runs different tools from one runner with independent contexts" do
      test = self
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_nil(self[:shared])
            set(:shared, "from foo")
            exit(1)
          end
        end
        tool "bar" do
          to_run do
            test.assert_nil(self[:shared])
            exit(2)
          end
        end
      end
      runner = make_runner
      assert_equal(1, runner.run(["foo"]))
      assert_equal(2, runner.run(["bar"]))
    end

    it "does not modify the arguments given to run" do
      cli.add_config_block do
        tool "foo" do
          remaining_args :rest
          to_run { nil }
        end
      end
      args = ["foo", "arg1"]
      assert_equal(0, make_runner.run(args))
      assert_equal(["foo", "arg1"], args)
    end
  end

  describe "tool lookup" do
    it "raises an ArgumentError when the args are not an array" do
      runner = make_runner
      err = assert_raises(::ArgumentError) do
        runner.run("foo")
      end
      assert_includes(err.message, "array of strings")
    end

    it "looks up the tool from the args" do
      test = self
      cli.add_config_block do
        tool "foo" do
          tool "bar" do
            required_arg :baz
            to_run do
              test.assert_equal(["foo", "bar"], tool_name)
              test.assert_equal("hello", baz)
            end
          end
        end
      end
      assert_equal(0, make_runner.run(["foo", "bar", "hello"]))
    end

    it "raises a finalized contextual error for a tool definition error" do
      cli.loader.add_path(File.join(lookup_cases_dir, "errors"))
      runner = make_runner
      err = assert_raises(Toys::ContextualError) do
        runner.run(["definition"])
      end
      assert(err.final?)
      assert_kind_of(::NameError, err.root_cause)
      assert_includes(err.config_path, "/errors/definition.rb")
    end

    it "does not finalize a tool definition error when wrap_errors is false" do
      cli.loader.add_path(File.join(lookup_cases_dir, "errors"))
      runner = make_runner
      err = assert_raises(Toys::ContextualError) do
        runner.run(["definition"], wrap_errors: false, handle_errors: false)
      end
      refute(err.final?)
      assert_kind_of(::NameError, err.root_cause)
    end
  end

  describe "logger" do
    it "calls the logger factory with the tool definition" do
      seen = []
      factory = proc do |tool|
        seen << tool.full_name
        logger
      end
      cli.add_config_block do
        tool "foo" do
          to_run { nil }
        end
      end
      assert_equal(0, make_runner(logger_factory: factory).run(["foo"]))
      assert_equal([["foo"]], seen)
    end

    it "calls the logger factory once per run" do
      count = 0
      factory = proc do
        count += 1
        Logger.new(::StringIO.new)
      end
      cli.add_config_block do
        tool "foo" do
          to_run { nil }
        end
      end
      runner = make_runner(logger_factory: factory)
      runner.run(["foo"])
      runner.run(["foo"])
      assert_equal(2, count)
    end

    it "provides a default logger when no factory is given" do
      test = self
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_kind_of(Logger, logger)
          end
        end
      end
      assert_equal(0, Toys::Runner.new(cli.loader).run(["foo"]))
    end

    it "honors base_level" do
      test = self
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_equal(Logger::INFO - 1, logger.level)
          end
        end
      end
      runner = make_runner(base_level: Logger::INFO)
      assert_equal(0, runner.run(["foo"], verbosity: 1))
    end

    it "restores the logger level after running" do
      cli.add_config_block do
        tool "foo" do
          to_run { nil }
        end
      end
      assert_equal(0, make_runner.run(["foo"], verbosity: 2))
      assert_equal(Logger::WARN, logger.level)
    end

    # The logger factory used by these tests returns the same logger for every
    # run, so nested runs all adjust the level of one logger object.
    describe "nested runs sharing a logger" do
      it "does not compound the verbosity of an inner run" do
        test = self
        runner = make_runner
        cli.add_config_block do
          tool "inner" do
            to_run do
              test.assert_equal(Logger::WARN - 1, logger.level)
            end
          end
          tool "outer" do
            to_run do
              test.assert_equal(Logger::WARN - 1, logger.level)
              test.assert_equal(0, runner.run(["inner"], verbosity: 1))
              test.assert_equal(Logger::WARN - 1, logger.level)
            end
          end
        end
        assert_equal(0, runner.run(["outer"], verbosity: 1))
      end

      it "does not compound the verbosity across three levels of nesting" do
        test = self
        runner = make_runner
        cli.add_config_block do
          tool "level3" do
            to_run do
              test.assert_equal(Logger::WARN - 1, logger.level)
            end
          end
          tool "level2" do
            to_run do
              test.assert_equal(Logger::WARN - 1, logger.level)
              test.assert_equal(0, runner.run(["level3"], verbosity: 1))
            end
          end
          tool "level1" do
            to_run do
              test.assert_equal(Logger::WARN - 1, logger.level)
              test.assert_equal(0, runner.run(["level2"], verbosity: 1))
            end
          end
        end
        assert_equal(0, runner.run(["level1"], verbosity: 1))
      end

      it "does not compound the verbosity of a delegated run" do
        test = self
        add_delegation_config do
          test.assert_equal(Logger::WARN - 2, logger.level)
        end
        assert_equal(0, make_runner.run(["front"], verbosity: 2))
      end

      it "resamples the base level in a later independent run" do
        levels = []
        runner = make_runner
        cli.add_config_block do
          tool "inner" do
            to_run { levels << logger.level }
          end
          tool "outer" do
            to_run { runner.run(["inner"], verbosity: 1) }
          end
        end
        assert_equal(0, runner.run(["outer"], verbosity: 1))
        assert_equal(Logger::WARN, logger.level)
        logger.level = Logger::ERROR
        assert_equal(0, runner.run(["inner"], verbosity: 1))
        assert_equal([Logger::WARN - 1, Logger::ERROR - 1], levels)
        assert_equal(Logger::ERROR, logger.level)
      end

      it "honors an explicit base_level in an inner run" do
        test = self
        outer_runner = make_runner
        inner_runner = make_runner(base_level: Logger::ERROR)
        cli.add_config_block do
          tool "inner" do
            to_run do
              test.assert_equal(Logger::ERROR - 1, logger.level)
            end
          end
          tool "outer" do
            to_run do
              test.assert_equal(Logger::WARN - 1, logger.level)
              test.assert_equal(0, inner_runner.run(["inner"], verbosity: 1))
              test.assert_equal(Logger::WARN - 1, logger.level)
            end
          end
        end
        assert_equal(0, outer_runner.run(["outer"], verbosity: 1))
      end

      it "uses the enclosing base_level in an inner run that has none" do
        test = self
        outer_runner = make_runner(base_level: Logger::ERROR)
        inner_runner = make_runner
        cli.add_config_block do
          tool "inner" do
            to_run do
              test.assert_equal(Logger::ERROR - 1, logger.level)
            end
          end
          tool "outer" do
            to_run do
              test.assert_equal(Logger::ERROR - 1, logger.level)
              test.assert_equal(0, inner_runner.run(["inner"], verbosity: 1))
            end
          end
        end
        assert_equal(0, outer_runner.run(["outer"], verbosity: 1))
      end

      it "does not record a base level for a run that failed to apply one" do
        levels = []
        cli.add_config_block do
          tool "foo" do
            to_run { nil }
          end
          tool "bar" do
            to_run { levels << logger.level }
          end
        end
        # A base level that cannot be combined with the verbosity fails while
        # the logger level is being set. That run must leave no base level
        # recorded behind it, or it would poison every later run of this thread
        # that shares the logger.
        assert_raises(::NoMethodError) do
          make_runner(base_level: :bogus).run(["foo"], wrap_errors: false, handle_errors: false)
        end
        assert_equal(Logger::WARN, logger.level)
        assert_equal(0, make_runner.run(["bar"], verbosity: 1))
        assert_equal([Logger::WARN - 1], levels)
      end

      it "leaves nested runs using different loggers alone" do
        levels = []
        loggers = []
        factory = proc do
          Logger.new(::StringIO.new).tap { |lgr| lgr.level = Logger::WARN }
        end
        runner = make_runner(logger_factory: factory)
        cli.add_config_block do
          tool "inner" do
            to_run do
              levels << logger.level
              loggers << logger
            end
          end
          tool "outer" do
            to_run do
              levels << logger.level
              loggers << logger
              runner.run(["inner"], verbosity: 1)
            end
          end
        end
        assert_equal(0, runner.run(["outer"], verbosity: 1))
        assert_equal([Logger::WARN - 1, Logger::WARN - 1], levels)
        refute_same(loggers[0], loggers[1])
      end
    end

    describe "default factory" do
      it "is the same proc returned by the CLI" do
        assert_same(Toys::Runner::DEFAULT_LOGGER_FACTORY, Toys::CLI.default_logger_factory)
      end

      it "builds a new logger writing to the current stderr on each call" do
        factory = Toys::Runner::DEFAULT_LOGGER_FACTORY
        stringio = ::StringIO.new
        logger1 = logger2 = nil
        begin
          original_stderr = $stderr
          $stderr = stringio
          logger1 = factory.call
          logger2 = factory.call
        ensure
          $stderr = original_stderr
        end
        refute_same(logger1, logger2)
        assert_equal(Logger::WARN, logger1.level)
        logger1.warn("hello from the factory")
        assert_match(/hello from the factory/, stringio.string)
      end
    end
  end

  describe "context data" do
    it "provides the loader in the context" do
      test = self
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_same(test.cli.loader, self[Toys::Context::Key::LOADER])
          end
        end
      end
      assert_equal(0, make_runner.run(["foo"]))
    end

    it "provides the loader via the context getter" do
      test = self
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_same(test.cli.loader, loader)
          end
        end
      end
      assert_equal(0, make_runner.run(["foo"]))
    end

    it "provides the loader via __loader when the tool overrides loader" do
      test = self
      cli.add_config_block do
        tool "foo" do
          def loader
            "shadowed"
          end

          to_run do
            test.assert_equal("shadowed", loader)
            test.assert_same(test.cli.loader, __loader)
          end
        end
      end
      assert_equal(0, make_runner.run(["foo"]))
    end

    it "provides external data in the context" do
      test = self
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_equal("hello", self[:custom_data])
          end
        end
      end
      external_data = {custom_data: "hello"}
      assert_equal(0, make_runner(external_data: external_data).run(["foo"]))
    end

    it "provides the executable name in the context" do
      test = self
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_equal("my-exe", self[Toys::Context::Key::EXECUTABLE_NAME])
          end
        end
      end
      assert_equal(0, make_runner(executable_name: "my-exe").run(["foo"]))
    end

    it "defaults the executable name to the ruby program name" do
      test = self
      expected = ::File.basename($PROGRAM_NAME)
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_equal(expected, self[Toys::Context::Key::EXECUTABLE_NAME])
          end
        end
      end
      assert_equal(0, make_runner.run(["foo"]))
    end

    it "provides the runner in the context" do
      test = self
      runner = make_runner
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_same(runner, self[Toys::Context::Key::RUNNER])
            test.assert_same(runner, self.runner)
          end
        end
      end
      assert_equal(0, runner.run(["foo"]))
    end

    it "runs a sibling tool from within a tool" do
      test = self
      cli.add_config_block do
        tool "sibling" do
          to_run do
            test.assert_equal(["sibling"], tool_name)
            exit(4)
          end
        end
        tool "foo" do
          to_run do
            test.assert_equal(4, runner.run(["sibling"]))
          end
        end
      end
      assert_equal(0, make_runner.run(["foo"]))
    end

    it "leaves the CLI key unset when no CLI is provided" do
      test = self
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_nil(cli)
          end
        end
      end
      assert_equal(0, make_runner.run(["foo"]))
    end

    it "does not let external data override runtime-owned keys" do
      test = self
      external_data = {
        Toys::Context::Key::TOOL_NAME => ["hijacked"],
        Toys::Context::Key::VERBOSITY => 99,
        Toys::Context::Key::EXECUTABLE_NAME => "hijacked-exe",
        Toys::Context::Key::RUNNER => "hijacked-runner",
      }
      runner = make_runner(external_data: external_data, executable_name: "my-exe")
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_equal(["foo"], self[Toys::Context::Key::TOOL_NAME])
            test.assert_equal(2, self[Toys::Context::Key::VERBOSITY])
            test.assert_equal("my-exe", self[Toys::Context::Key::EXECUTABLE_NAME])
            test.assert_same(runner, self[Toys::Context::Key::RUNNER])
          end
        end
      end
      assert_equal(0, runner.run(["foo"], verbosity: 2))
    end

    it "does not modify the external data hash" do
      cli.add_config_block do
        tool "foo" do
          flag :bar, "--bar=VAL"
          to_run { nil }
        end
      end
      external_data = {custom_data: "hello"}
      assert_equal(0, make_runner(external_data: external_data).run(["foo", "--bar=x"]))
      assert_equal({custom_data: "hello"}, external_data)
    end
  end

  describe "error wrapping" do
    it "wraps an error raised during argument parsing" do
      cli.add_config_block do
        tool "foo" do
          flag :bar, "--bar=VAL", handler: proc { |_val, _prev| raise "handler kaboom" }
          to_run { nil }
        end
      end
      err = assert_raises(Toys::ContextualError) do
        make_runner.run(["foo", "--bar=x"])
      end
      assert_equal(["foo"], err.tool_name)
      assert_equal(["--bar=x"], err.tool_args)
      assert_equal("handler kaboom", err.root_cause.message)
    end

    it "wraps an error raised by the tool, including tool context" do
      cli.add_config_block do
        tool "foo" do
          remaining_args :rest
          to_run { raise "kaboom" }
        end
      end
      err = assert_raises(Toys::ContextualError) do
        make_runner.run(["foo", "arg1"])
      end
      assert(err.final?)
      assert_equal("Error during tool execution", err.banner)
      assert_equal(["foo"], err.tool_name)
      assert_equal(["arg1"], err.tool_args)
      assert_equal("kaboom", err.root_cause.message)
    end

    it "wraps an error raised by a given block" do
      cli.add_config_block do
        tool "foo" do
          to_run { nil }
        end
      end
      err = assert_raises(Toys::ContextualError) do
        make_runner.run(["foo"]) { raise "from the block" }
      end
      assert_equal("from the block", err.root_cause.message)
    end

    it "propagates errors as-is when wrap_errors is false" do
      cli.add_config_block do
        tool "foo" do
          to_run { raise "kaboom" }
        end
      end
      err = assert_raises(::RuntimeError) do
        make_runner.run(["foo"], wrap_errors: false, handle_errors: false)
      end
      assert_equal("kaboom", err.message)
    end

    it "propagates argument parsing errors as-is when wrap_errors is false" do
      cli.add_config_block do
        tool "foo" do
          required_arg :bar
          to_run { nil }
        end
      end
      assert_raises(Toys::ArgParsingError) do
        make_runner.run(["foo"], wrap_errors: false, handle_errors: false)
      end
    end

    it "propagates block errors as-is when wrap_errors is false" do
      cli.add_config_block do
        tool "foo" do
          to_run { nil }
        end
      end
      err = assert_raises(::RuntimeError) do
        make_runner.run(["foo"], wrap_errors: false, handle_errors: false) do
          raise "from the block"
        end
      end
      assert_equal("from the block", err.message)
    end
  end

  describe "error handling" do
    it "reraises a wrapped error by default" do
      cli.add_config_block do
        tool "foo" do
          to_run { raise "kaboom" }
        end
      end
      err = assert_raises(Toys::ContextualError) do
        make_runner.run(["foo"])
      end
      assert_equal("kaboom", err.root_cause.message)
    end

    it "passes a wrapped error to a custom handler and returns its code" do
      seen = nil
      handler = proc do |error|
        seen = error
        7
      end
      cli.add_config_block do
        tool "foo" do
          to_run { raise "kaboom" }
        end
      end
      assert_equal(7, make_runner(error_handler: handler).run(["foo"]))
      assert_kind_of(Toys::ContextualError, seen)
      assert_equal("kaboom", seen.root_cause.message)
    end

    it "passes a bare error to a custom handler when wrap_errors is false" do
      seen = nil
      handler = proc do |error|
        seen = error
        7
      end
      cli.add_config_block do
        tool "foo" do
          to_run { raise "kaboom" }
        end
      end
      runner = make_runner(error_handler: handler)
      assert_equal(7, runner.run(["foo"], wrap_errors: false))
      assert_instance_of(::RuntimeError, seen)
      assert_equal("kaboom", seen.message)
    end

    it "passes a bare signal to a custom handler" do
      seen = nil
      handler = proc do |error|
        seen = error
        7
      end
      cli.add_config_block do
        tool "foo" do
          to_run { raise ::Interrupt }
        end
      end
      assert_equal(7, make_runner(error_handler: handler).run(["foo"]))
      assert_instance_of(::Interrupt, seen)
    end

    it "propagates a wrapped error when handle_errors is false" do
      handler = proc { |_error| flunk("Should not have called the error handler") }
      cli.add_config_block do
        tool "foo" do
          to_run { raise "kaboom" }
        end
      end
      runner = make_runner(error_handler: handler)
      err = assert_raises(Toys::ContextualError) do
        runner.run(["foo"], handle_errors: false)
      end
      assert(err.final?)
      assert_equal("kaboom", err.root_cause.message)
    end

    it "does not pass SystemExit to the handler" do
      handler = proc { |_error| flunk("Should not have called the error handler") }
      cli.add_config_block do
        tool "foo" do
          to_run { ::Kernel.exit(5) }
        end
      end
      err = assert_raises(::SystemExit) do
        make_runner(error_handler: handler).run(["foo"])
      end
      assert_equal(5, err.status)
    end

    it "calls the handler exactly once for a delegation chain" do
      count = 0
      handler = proc do |_error|
        count += 1
        7
      end
      cli.add_config_block do
        tool "target" do
          to_run { raise "kaboom" }
        end
        tool "mid" do
          delegate_to ["target"]
        end
        tool "front" do
          delegate_to ["mid"]
        end
      end
      assert_equal(7, make_runner(error_handler: handler).run(["front"]))
      assert_equal(1, count)
    end

    describe "default handler" do
      it "is the same proc returned by the CLI" do
        assert_same(Toys::Runner::DEFAULT_ERROR_HANDLER, Toys::CLI.default_error_handler)
      end

      it "is frozen" do
        assert(Toys::Runner::DEFAULT_ERROR_HANDLER.frozen?)
      end
    end
  end

  describe "delegation" do
    it "attributes an error to the delegate and the delegating tool" do
      add_delegation_config { raise "kaboom" }
      err = assert_raises(Toys::ContextualError) do
        make_runner.run(["front", "arg1"])
      end
      assert_equal(["front"], err.tool_name)
      inner = err.cause
      assert_kind_of(Toys::ContextualError, inner)
      assert_equal(["target"], inner.tool_name)
      assert_equal(["arg1"], inner.tool_args)
      assert_kind_of(::RuntimeError, err.root_cause)
      assert_equal("kaboom", err.root_cause.message)
    end

    it "calls the logger factory for each tool in the delegation" do
      seen = []
      factory = proc do |tool|
        seen << tool.full_name
        logger
      end
      add_delegation_config { nil }
      assert_equal(0, make_runner(logger_factory: factory).run(["front"]))
      assert_equal([["front"], ["target"]], seen)
    end

    it "passes the verbosity to the delegate" do
      test = self
      add_delegation_config do
        test.assert_equal(2, verbosity)
      end
      assert_equal(0, make_runner.run(["front"], verbosity: 2))
    end

    it "passes external data to the delegate" do
      test = self
      add_delegation_config do
        test.assert_equal("hello", self[:custom_data])
      end
      external_data = {custom_data: "hello"}
      assert_equal(0, make_runner(external_data: external_data).run(["front"]))
    end

    it "passes wrap_errors to the delegate" do
      add_delegation_config { raise "kaboom" }
      err = assert_raises(::RuntimeError) do
        make_runner.run(["front"], wrap_errors: false, handle_errors: false)
      end
      assert_equal("kaboom", err.message)
    end

    it "sets delegated_from on the delegate context" do
      test = self
      add_delegation_config do
        delegator = self[Toys::Context::Key::DELEGATED_FROM]
        test.refute_nil(delegator)
        test.assert_equal(["front"], delegator[Toys::Context::Key::TOOL_NAME])
      end
      assert_equal(0, make_runner.run(["front"]))
    end
  end

  describe "standard middleware" do
    let(:help_io) { ::StringIO.new }
    let(:help_cli) {
      middleware = [[Toys::StandardMiddleware::ShowHelp, {help_flags: true, stream: help_io}]]
      Toys::CLI.new(executable_name: "toys", logger: logger, middleware_stack: middleware).tap do |c|
        c.add_config_block do
          tool "foo" do
            to_run { nil }
          end
        end
      end
    }

    it "displays help without a CLI in the context" do
      runner = Toys::Runner.new(help_cli.loader,
                                logger_factory: logger_factory,
                                executable_name: "my-exe")
      assert_equal(0, runner.run(["foo", "--help"]))
      assert_match(/SYNOPSIS/, help_io.string)
      assert_match(/my-exe foo/, help_io.string)
    end

    it "honors the verbosity setting when verbosity flags are present" do
      test = self
      verbose_cli = Toys::CLI.new(executable_name: "toys", logger: logger)
      verbose_cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_equal(2, verbosity)
          end
        end
      end
      runner = Toys::Runner.new(verbose_cli.loader, logger_factory: logger_factory)
      assert_equal(0, runner.run(["foo"], verbosity: 2))
    end

    it "adds verbosity flags to the initial verbosity setting" do
      test = self
      verbose_cli = Toys::CLI.new(executable_name: "toys", logger: logger)
      verbose_cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_equal(3, verbosity)
          end
        end
      end
      runner = Toys::Runner.new(verbose_cli.loader, logger_factory: logger_factory)
      assert_equal(0, runner.run(["foo", "-v"], verbosity: 2))
    end
  end
end
