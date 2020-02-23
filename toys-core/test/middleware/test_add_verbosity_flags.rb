# frozen_string_literal: true

require "helper"
require "toys/standard_middleware/add_verbosity_flags"

describe Toys::StandardMiddleware::AddVerbosityFlags do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  def make_cli(**opts)
    middleware = [[Toys::StandardMiddleware::AddVerbosityFlags, opts]]
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: middleware)
  end

  it "recognizes short verbose flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(11, cli.run("foo", "-v"))
  end

  it "recognizes long verbose flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(11, cli.run("foo", "--verbose"))
  end

  it "recognizes short quiet flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(9, cli.run("foo", "-q"))
  end

  it "recognizes long quiet flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(9, cli.run("foo", "--quiet"))
  end

  it "allows multiple flags" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(12, cli.run("foo", "-vvqv"))
  end

  it "supports custom verbose flag" do
    cli = make_cli(verbose_flags: ["--abc"])
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(12, cli.run("foo", "--abc", "--abc"))
  end

  it "supports custom quiet flag" do
    cli = make_cli(quiet_flags: ["--abc"])
    cli.add_config_block do
      tool "foo" do
        def run
          exit(10 + verbosity)
        end
      end
    end
    assert_equal(8, cli.run("foo", "--abc", "--abc"))
  end

  it "allows disabling of verbose flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        disable_flag "--verbose"
        on_usage_error :run
        def run
          exit(usage_errors.empty? ? 10 + verbosity : -2)
        end
      end
    end
    assert_equal(-2, cli.run("foo", "--verbose"))
    assert_equal(11, cli.run("foo", "-v"))
  end

  it "allows disabling of quiet flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        disable_flag "--quiet"
        on_usage_error :run
        def run
          exit(usage_errors.empty? ? 10 + verbosity : -2)
        end
      end
    end
    assert_equal(-2, cli.run("foo", "--quiet"))
    assert_equal(9, cli.run("foo", "-q"))
  end
end
