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
require "toys/standard_middleware/add_verbosity_flags"

describe Toys::StandardMiddleware::AddVerbosityFlags do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  def make_cli(opts = {})
    middleware = [[Toys::StandardMiddleware::AddVerbosityFlags, opts]]
    Toys::CLI.new(binary_name: binary_name, logger: logger, middleware_stack: middleware)
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
        def run
          exit(usage_errors.empty? ? 10 + verbosity : -1)
        end
      end
    end
    assert_equal(-1, cli.run("foo", "--verbose"))
    assert_equal(11, cli.run("foo", "-v"))
  end

  it "allows disabling of quiet flag" do
    cli = make_cli
    cli.add_config_block do
      tool "foo" do
        disable_flag "--quiet"
        def run
          exit(usage_errors.empty? ? 10 + verbosity : -1)
        end
      end
    end
    assert_equal(-1, cli.run("foo", "--quiet"))
    assert_equal(9, cli.run("foo", "-q"))
  end
end
