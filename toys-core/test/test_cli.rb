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
  let(:logger_io) { ::StringIO.new }
  let(:logger) {
    Logger.new(logger_io).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:error_io) { ::StringIO.new }
  let(:error_handler) { Toys::CLI::DefaultErrorHandler.new(output: error_io) }
  let(:cli) {
    Toys::CLI.new(
      executable_name: executable_name, logger: logger, middleware_stack: [],
      error_handler: error_handler, index_file_name: ".toys.rb",
      data_dir_name: ".data", extra_delimiters: ":"
    )
  }

  describe "execution" do
    it "returns the exit value" do
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
      assert_equal(1, cli.run("foo"))
      assert_match(/RuntimeError: whoops/, error_io.string)
    end

    it "handles no script defined" do
      cli.add_config_block do
        tool "foo" do
        end
      end
      assert_equal(126, cli.run("foo"))
      assert_match(/No implementation for tool/, error_io.string)
    end

    it "can disable argument parsing" do
      test = self
      cli.add_config_block do
        tool "foo" do
          disable_argument_parsing
          to_run do
            test.assert_equal(["baz", "--bar"], args)
            test.assert(usage_errors.empty?)
          end
        end
      end
      assert_equal(0, cli.run("foo", "baz", "--bar"), error_io.string)
    end

    it "runs initializer at the beginning" do
      test = self
      cli.add_config_block do
        tool "foo" do
          t = Toys::DSL::Tool.current_tool(self, true)
          t.add_initializer(proc { |a| set(:a, a) }, 123)
          to_run do
            test.assert_equal(123, get(:a))
          end
        end
      end
      assert_equal(0, cli.run("foo"), error_io.string)
    end

    it "makes context fields available via convenience methods" do
      test = self
      cli.add_config_block do
        tool "foo" do
          optional_arg(:arg1)
          optional_arg(:arg2)
          flag(:sw1, "-a")
          to_run do
            test.assert_equal(0, verbosity)
            test.assert_equal(["foo"], tool_name)
            test.assert_instance_of(Logger, logger)
            test.assert_equal("toys", cli.executable_name)
            test.assert_equal(["hello", "-a"], args)
            test.assert_equal({arg1: "hello", arg2: nil, sw1: true}, options)
          end
        end
      end
      assert_equal(0, cli.run(["foo", "hello", "-a"]), error_io.string)
    end

    it "makes context fields available via get" do
      test = self
      cli.add_config_block do
        tool "foo" do
          optional_arg(:arg1)
          optional_arg(:arg2)
          flag(:sw1, "-a")
          to_run do
            test.assert_equal(0, get(Toys::Context::Key::VERBOSITY))
            test.assert_equal(["foo"], get(Toys::Context::Key::TOOL).full_name)
            test.assert_equal(["foo"], get(Toys::Context::Key::TOOL_NAME))
            test.assert_instance_of(Logger, get(Toys::Context::Key::LOGGER))
            test.assert_equal("toys", get(Toys::Context::Key::CLI).executable_name)
            test.assert_equal(["hello", "-a"], get(Toys::Context::Key::ARGS))
          end
        end
      end
      assert_equal(0, cli.run(["foo", "hello", "-a"]), error_io.string)
    end

    it "makes options available via get" do
      test = self
      cli.add_config_block do
        tool "foo" do
          optional_arg(:arg1)
          optional_arg(:arg2)
          flag(:sw1, "-a")
          to_run do
            test.assert_equal(true, get(:sw1))
            test.assert_equal("hello", get(:arg1))
            test.assert_nil(get(:arg2))
          end
        end
      end
      assert_equal(0, cli.run(["foo", "hello", "-a"]), error_io.string)
    end

    it "supports sub-runs" do
      test = self
      cli.add_config_block do
        tool "foo" do
          optional_arg :arg1
          to_run do
            test.assert_equal("hi", self[:arg1])
            exit(cli.run("bar", "ho"))
          end
        end
        tool "bar" do
          optional_arg :arg2
          to_run do
            test.assert_equal("ho", self[:arg2])
            exit(3)
          end
        end
      end
      assert_equal(3, cli.run(["foo", "hi"]))
    end

    it "accesses data from run" do
      cli.loader.add_path(File.join(__dir__, "lookup-cases", "data-finder"))
      assert_equal(0, cli.run("ns-1", "ns-1a", "foo"))
    end

    it "recognizes delimiters" do
      cli.add_config_block do
        tool "foo" do
          tool "bar" do
            def run
              exit(3)
            end
          end
        end
      end
      assert_equal(3, cli.run("foo:bar"))
    end
  end

  describe "interrupt handling" do
    it "uses the default interrupt handler" do
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

    it "supports an interrupt block with no argument" do
      cli.add_config_block do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt do
            exit(2)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "supports propagating an interrupt" do
      cli.add_config_block do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt do |ex|
            raise ex
          end
        end
      end
      assert_equal(130, cli.run("foo"))
      assert_match(/INTERRUPT/, error_io.string)
    end

    it "supports an interrupt block with an argument" do
      test = self
      cli.add_config_block do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt do |ex|
            test.assert_instance_of(::Interrupt, ex)
            exit(2)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "supports nested interrupts" do
      counter = 0
      cli.add_config_block do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt do |ex|
            counter += 1
            raise ::Interrupt if ex.cause.nil?
            exit(counter)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "supports an interrupt method with no argument" do
      cli.add_config_block do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt :int_handler

          def int_handler
            exit(2)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "supports an interrupt method with an argument" do
      cli.add_config_block do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          def int_handler(exception)
            exit(exception.is_a?(::Interrupt) ? 2 : 3)
          end

          on_interrupt :int_handler
        end
      end
      assert_equal(2, cli.run("foo"))
    end
  end

  describe "usage error handling" do
    it "uses the default handler" do
      cli.add_config_block do
        tool "foo" do
          def run; end
        end
      end
      assert_equal(2, cli.run("foo", "--bar"))
      assert_match(/Flag "--bar" is not recognized/, error_io.string)
    end

    it "sets the default handler" do
      cli.add_config_block do
        tool "foo" do
          on_usage_error :run
          on_usage_error nil

          def run; end
        end
      end
      assert_equal(2, cli.run("foo", "--bar"))
      assert_match(/Flag "--bar" is not recognized/, error_io.string)
    end

    it "supports redirecting back to run" do
      cli.add_config_block do
        tool "foo" do
          on_usage_error :run

          def run
            exit usage_errors.size
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end

    it "supports invoking a method with no argument" do
      cli.add_config_block do
        tool "foo" do
          on_usage_error :usage_handler

          def run
            exit(-1)
          end

          def usage_handler
            exit usage_errors.size
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end

    it "supports invoking a method with an argument" do
      cli.add_config_block do
        tool "foo" do
          on_usage_error :usage_handler

          def run
            exit(-1)
          end

          def usage_handler(errs)
            exit errs.size
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end

    it "supports invoking a block with no argument" do
      cli.add_config_block do
        tool "foo" do
          on_usage_error do
            exit usage_errors.size
          end

          def run
            exit(-1)
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end

    it "supports invoking a block with no argument" do
      cli.add_config_block do
        tool "foo" do
          on_usage_error do |errs|
            exit errs.size
          end

          def run
            exit(-1)
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end
  end

  describe "directive alterations" do
    it "allows partial flag match" do
      cli.add_config_block do
        tool "foo" do
          flag :abcde
          def run
            exit(0)
          end
        end
      end
      assert_equal(0, cli.run("foo", "--abc"))
    end

    it "requires exact flag match" do
      cli.add_config_block do
        tool "foo" do
          flag :abcde
          require_exact_flag_match
          def run
            exit(0)
          end
        end
      end
      assert_equal(2, cli.run("foo", "--abc"))
    end
  end

  describe "child" do
    let(:logger2) {
      Logger.new(logger_io).tap do |lgr|
        lgr.level = Logger::DEBUG
      end
    }

    it "resets tool blocks" do
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

    it "copies parameters" do
      assert_same(logger, cli.logger)
      child = cli.child
      assert_same(logger, child.logger)
    end

    it "overrides parameters" do
      assert_same(logger, cli.logger)
      child = cli.child(logger: logger2)
      assert_same(logger2, child.logger)
    end
  end
end
