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
require "toys/standard_mixins/highline"

describe Toys::StandardMixins::Highline do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  let(:cli) { Toys::CLI.new(binary_name: binary_name, logger: logger, middleware_stack: []) }

  it "provides a highline instance" do
    cli.add_config_block do
      tool "foo" do
        include :highline
        def run
          exit(highline.is_a?(::HighLine) ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end

  it "supports say" do
    cli.add_config_block do
      tool "foo" do
        include :highline
        def run
          say "hello"
        end
      end
      tool "bar" do
        include :exec
        def run
          result = capture_tool(["foo"])
          exit(result == "hello\n" ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("bar"))
  end
end
