# frozen_string_literal: true

require "helper"

describe Toys::Execution do
  let(:logger_io) { ::StringIO.new }
  let(:logger) {
    Logger.new(logger_io).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:cli) {
    Toys::CLI.new(
      executable_name: "toys",
      logger: logger,
      middleware_stack: [],
      index_file_name: ".toys.rb"
    )
  }

  def make_execution(*args, **opts)
    tool, remaining = cli.loader.lookup(args.flatten)
    Toys::Execution.new(tool, remaining, cli.loader, **opts)
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
    assert_raises(Toys::ArgParsingError) do
      execution.run
    end
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
    Toys::Execution.new(tool, remaining, middleware_cli.loader).run do |_context|
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
    assert_raises(Toys::NotRunnableError) do
      make_execution("foo").run
    end
  end
end
