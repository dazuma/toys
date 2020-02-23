# frozen_string_literal: true

require "helper"
require "stringio"
require "toys/standard_middleware/handle_usage_errors"

describe Toys::StandardMiddleware::HandleUsageErrors do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:error_io) { ::StringIO.new }
  let(:cli) {
    middleware = [[Toys::StandardMiddleware::HandleUsageErrors, {stream: error_io}]]
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: middleware)
  }

  it "does not intercept valid usage" do
    cli.add_config_block do
      tool "foo" do
        def run
          exit(1)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
    assert_equal("", error_io.string)
  end

  it "reports an invalid tool" do
    cli.add_config_block do
      tool "foo" do
        def run
          exit(1)
        end
      end
    end
    assert_equal(2, cli.run("bar"))
    assert_match(/Tool not found: "bar"/, error_io.string)
  end

  it "reports an invalid option" do
    cli.add_config_block do
      tool "foo" do
        def run
          exit(1)
        end
      end
    end
    assert_equal(2, cli.run("foo", "-v"))
    assert_match(/Flag "-v" is not recognized./, error_io.string)
  end

  it "reports an extra arg" do
    cli.add_config_block do
      tool "foo" do
        def run
          exit(1)
        end
      end
    end
    assert_equal(2, cli.run("foo", "vee"))
    assert_match(/Extra arguments: "vee"/, error_io.string)
  end

  it "reports an unsatisfied required arg" do
    cli.add_config_block do
      tool "foo" do
        required :arg1
        def run
          exit(1)
        end
      end
    end
    assert_equal(2, cli.run("foo"))
    assert_match(/Required positional argument "ARG1" is missing/, error_io.string)
  end
end
