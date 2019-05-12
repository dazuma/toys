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

describe Toys::CLI do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  let(:error_io) { ::StringIO.new }
  let(:error_handler) { Toys::CLI::DefaultErrorHandler.new(error_io) }
  let(:cli) {
    Toys::CLI.new(
      binary_name: binary_name, logger: logger, middleware_stack: [],
      error_handler: error_handler
    )
  }

  it "runs a tool" do
    cli.add_config_block do
      tool "foo" do
        def run
          exit(3)
        end
      end
    end
    assert_equal(3, cli.run("foo"))
  end

  it "handles an error" do
    cli.add_config_block do
      tool "foo" do
        def run
          raise "whoops"
        end
      end
    end
    assert_equal(-1, cli.run("foo"))
    assert_match(/RuntimeError: whoops/, error_io.string)
  end

  it "handles an interrupt" do
    cli.add_config_block do
      tool "foo" do
        def run
          raise ::Interrupt
        end
      end
    end
    assert_equal(130, cli.run("foo"))
    assert_match(/INTERRUPT/, error_io.string)
  end

  it "creates a child" do
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
end
