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
require "toys/standard_middleware/show_root_version"

describe Toys::StandardMiddleware::ShowRootVersion do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:version_string) { "v1.2.3" }
  let(:string_io) { ::StringIO.new }
  let(:cli) {
    middleware = [[Toys::StandardMiddleware::ShowRootVersion,
                   version_string: version_string, stream: string_io]]
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: middleware)
  }

  it "displays a version string for the root" do
    cli.add_config_block do
      tool "foo" do
      end
    end
    assert_equal(0, cli.run("--version"))
    assert_equal(version_string, string_io.string.strip)
  end

  it "does not alter non-root" do
    cli.add_config_block do
      tool "foo" do
        on_usage_error :run
        def run
          exit(usage_errors.empty? ? 3 : 4)
        end
      end
    end
    assert_equal(4, cli.run("foo", "--version"))
  end
end
