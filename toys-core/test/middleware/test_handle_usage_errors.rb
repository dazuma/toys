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
require "stringio"
require "toys/standard_middleware/handle_usage_errors"

describe Toys::StandardMiddleware::HandleUsageErrors do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  let(:error_io) { ::StringIO.new }
  let(:cli) {
    middleware = [[Toys::StandardMiddleware::HandleUsageErrors, {stream: error_io}]]
    Toys::CLI.new(binary_name: binary_name, logger: logger, middleware_stack: middleware)
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
    assert_equal(-1, cli.run("bar"))
    assert_match(/Tool not found: \["bar"\]/, error_io.string)
  end

  it "reports an invalid option" do
    cli.add_config_block do
      tool "foo" do
        def run
          exit(1)
        end
      end
    end
    assert_equal(-1, cli.run("foo", "-v"))
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
    assert_equal(-1, cli.run("foo", "vee"))
    assert_match(/Extra arguments: \["vee"\]/, error_io.string)
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
    assert_equal(-1, cli.run("foo"))
    assert_match(/Required argument "ARG1" is missing/, error_io.string)
  end
end
