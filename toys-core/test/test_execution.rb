# frozen_string_literal: true

require "helper"
require "stringio"
require "toys/standard_middleware/show_help"

describe Toys::Execution do
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

  def make_execution(*args, **opts)
    tool, remaining = cli.loader.lookup(args.flatten)
    Toys::Execution.for_tool(tool, remaining, cli.loader, **opts)
  end

  # Builds an execution that looks the tool up from the args, which is the form
  # used by Toys::CLI.
  def lookup_execution(*args, **opts)
    opts = {logger_factory: logger_factory}.merge(opts)
    Toys::Execution.for_args(args.flatten, cli.loader, **opts)
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
    assert_equal(3, make_execution("foo").run)
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
    assert_equal(0, make_execution("foo", "hello").run)
  end

  it "defers argument parsing until run is called" do
    cli.add_config_block do
      tool "foo" do
        required_arg :bar
        def run
          # Never reached
        end
      end
    end
    execution = make_execution("foo")
    err = assert_raises(Toys::ContextualError) do
      execution.run
    end
    assert_kind_of(Toys::ArgParsingError, err.cause)
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
    result = make_execution("foo", "hello").run do |context|
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
    tool, remaining = middleware_cli.loader.lookup(["foo"])
    Toys::Execution.for_tool(tool, remaining, middleware_cli.loader).run do |_context|
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
    assert_equal(0, make_execution("foo", verbosity: 2).run)
  end

  it "honors the delegated_from setting" do
    delegator = ::Object.new
    test = self
    cli.add_config_block do
      tool "foo" do
        to_run do
          test.assert_same(delegator, self[Toys::Context::Key::DELEGATED_FROM])
        end
      end
    end
    assert_equal(0, make_execution("foo", delegated_from: delegator).run)
  end

  it "raises when the tool is not runnable" do
    cli.add_config_block do
      tool "foo" do
        # Empty tool
      end
    end
    err = assert_raises(Toys::ContextualError) do
      make_execution("foo").run
    end
    assert_kind_of(Toys::NotRunnableError, err.cause)
  end

  describe "construction" do
    it "exposes the tool and args given to for_tool" do
      cli.add_config_block do
        tool "foo" do
          to_run { nil }
        end
      end
      tool, remaining = cli.loader.lookup(["foo", "arg1"])
      execution = Toys::Execution.for_tool(tool, remaining, cli.loader)
      assert_same(tool, execution.tool)
      assert_equal(["arg1"], execution.args)
    end

    it "exposes the tool and remaining args resolved by for_args" do
      cli.add_config_block do
        tool "foo" do
          tool "bar" do
            to_run { nil }
          end
        end
      end
      execution = Toys::Execution.for_args(["foo", "bar", "arg1"], cli.loader)
      assert_equal(["foo", "bar"], execution.tool.full_name)
      assert_equal(["arg1"], execution.args)
    end
  end

  describe "tool lookup" do
    it "looks up the tool from the args when no tool is given" do
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
      assert_equal(0, lookup_execution("foo", "bar", "hello").run)
    end

    it "raises a finalized contextual error for a tool definition error" do
      cli.loader.add_path(File.join(lookup_cases_dir, "errors"))
      err = assert_raises(Toys::ContextualError) do
        lookup_execution("definition")
      end
      assert(err.final?)
      assert_kind_of(::NameError, err.root_cause)
      assert_includes(err.config_path, "/errors/definition.rb")
    end

    it "does not finalize a tool definition error when wrap_errors is false" do
      cli.loader.add_path(File.join(lookup_cases_dir, "errors"))
      err = assert_raises(Toys::ContextualError) do
        lookup_execution("definition", wrap_errors: false)
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
      assert_equal(0, lookup_execution("foo", logger_factory: factory).run)
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
      execution = lookup_execution("foo", logger_factory: factory)
      execution.run
      execution.run
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
      tool, remaining = cli.loader.lookup(["foo"])
      assert_equal(0, Toys::Execution.for_tool(tool, remaining, cli.loader).run)
    end

    it "honors base_logger_level" do
      test = self
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_equal(Logger::INFO - 1, logger.level)
          end
        end
      end
      execution = lookup_execution("foo", base_logger_level: Logger::INFO, verbosity: 1)
      assert_equal(0, execution.run)
    end

    it "restores the logger level after running" do
      cli.add_config_block do
        tool "foo" do
          to_run { nil }
        end
      end
      assert_equal(0, lookup_execution("foo", verbosity: 2).run)
      assert_equal(Logger::WARN, logger.level)
    end

    describe "default factory" do
      it "is the same proc returned by the CLI" do
        assert_same(Toys::Execution::DEFAULT_LOGGER_FACTORY, Toys::CLI.default_logger_factory)
      end

      it "builds a new logger writing to the current stderr on each call" do
        factory = Toys::Execution::DEFAULT_LOGGER_FACTORY
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
      assert_equal(0, lookup_execution("foo").run)
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
      assert_equal(0, lookup_execution("foo").run)
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
      assert_equal(0, lookup_execution("foo").run)
    end

    it "provides external data in the context" do
      test = self
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_equal("my-exe", self[Toys::Context::Key::EXECUTABLE_NAME])
          end
        end
      end
      external_data = {Toys::Context::Key::EXECUTABLE_NAME => "my-exe"}
      assert_equal(0, lookup_execution("foo", external_data: external_data).run)
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
      assert_equal(0, lookup_execution("foo").run)
    end

    it "does not let external data override execution-owned keys" do
      test = self
      cli.add_config_block do
        tool "foo" do
          to_run do
            test.assert_equal(["foo"], self[Toys::Context::Key::TOOL_NAME])
            test.assert_equal(2, self[Toys::Context::Key::VERBOSITY])
          end
        end
      end
      external_data = {
        Toys::Context::Key::TOOL_NAME => ["hijacked"],
        Toys::Context::Key::VERBOSITY => 99,
      }
      assert_equal(0, lookup_execution("foo", verbosity: 2, external_data: external_data).run)
    end

    it "does not modify the external data hash" do
      cli.add_config_block do
        tool "foo" do
          flag :bar, "--bar=VAL"
          to_run { nil }
        end
      end
      external_data = {Toys::Context::Key::EXECUTABLE_NAME => "my-exe"}
      assert_equal(0, lookup_execution("foo", "--bar=x", external_data: external_data).run)
      assert_equal({Toys::Context::Key::EXECUTABLE_NAME => "my-exe"}, external_data)
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
        lookup_execution("foo", "--bar=x").run
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
        lookup_execution("foo", "arg1").run
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
        lookup_execution("foo").run { raise "from the block" }
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
        lookup_execution("foo", wrap_errors: false).run
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
        lookup_execution("foo", wrap_errors: false).run
      end
    end

    it "propagates block errors as-is when wrap_errors is false" do
      cli.add_config_block do
        tool "foo" do
          to_run { nil }
        end
      end
      err = assert_raises(::RuntimeError) do
        lookup_execution("foo", wrap_errors: false).run { raise "from the block" }
      end
      assert_equal("from the block", err.message)
    end
  end

  describe "delegation" do
    it "attributes an error to the delegate and the delegating tool" do
      add_delegation_config { raise "kaboom" }
      err = assert_raises(Toys::ContextualError) do
        lookup_execution("front", "arg1").run
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
      assert_equal(0, lookup_execution("front", logger_factory: factory).run)
      assert_equal([["front"], ["target"]], seen)
    end

    it "passes the verbosity to the delegate" do
      test = self
      add_delegation_config do
        test.assert_equal(2, verbosity)
      end
      assert_equal(0, lookup_execution("front", verbosity: 2).run)
    end

    it "passes external data to the delegate" do
      test = self
      add_delegation_config do
        test.assert_equal("my-exe", self[Toys::Context::Key::EXECUTABLE_NAME])
      end
      external_data = {Toys::Context::Key::EXECUTABLE_NAME => "my-exe"}
      assert_equal(0, lookup_execution("front", external_data: external_data).run)
    end

    it "passes wrap_errors to the delegate" do
      add_delegation_config { raise "kaboom" }
      err = assert_raises(::RuntimeError) do
        lookup_execution("front", wrap_errors: false).run
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
      assert_equal(0, lookup_execution("front").run)
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
      execution = Toys::Execution.for_args(["foo", "--help"], help_cli.loader,
                                           logger_factory: logger_factory)
      assert_equal(0, execution.run)
      assert_match(/SYNOPSIS/, help_io.string)
      assert_match(/\(binary-name\) foo/, help_io.string)
    end

    it "displays help using an executable name from external data" do
      external_data = {Toys::Context::Key::EXECUTABLE_NAME => "my-exe"}
      execution = Toys::Execution.for_args(["foo", "--help"], help_cli.loader,
                                           logger_factory: logger_factory,
                                           external_data: external_data)
      assert_equal(0, execution.run)
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
      execution = Toys::Execution.for_args(["foo"], verbose_cli.loader,
                                           logger_factory: logger_factory, verbosity: 2)
      assert_equal(0, execution.run)
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
      execution = Toys::Execution.for_args(["foo", "-v"], verbose_cli.loader,
                                           logger_factory: logger_factory, verbosity: 2)
      assert_equal(0, execution.run)
    end
  end
end
