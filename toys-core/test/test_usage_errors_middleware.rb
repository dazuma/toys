# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
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
    assert_match(/Tool not found: bar/, error_io.string)
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
    assert_match(/invalid option: -v/, error_io.string)
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
    assert_match(/Extra arguments provided: vee/, error_io.string)
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
    assert_match(/No value given for required argument ARG1/, error_io.string)
  end
end
