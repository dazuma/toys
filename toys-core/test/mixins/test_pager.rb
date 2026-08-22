# frozen_string_literal: true

require "helper"
require "toys/standard_mixins/pager"

describe Toys::StandardMixins::Pager do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: [])
  }

  it "accesses a pager" do
    cli.add_config_block do
      tool "foo" do
        include :pager
        def run
          puts pager.class.name
        end
      end
    end
    out, _err = capture_subprocess_io do
      assert_equal(0, cli.run("foo"))
    end
    assert_equal("Toys::Utils::Pager", out.strip)
  end

  it "runs a pager" do
    cli.add_config_block do
      tool "foo" do
        include :pager
        def run
          pager do |io|
            io.puts "Hello Ruby"
          end
        end
      end
    end
    out, _err = capture_subprocess_io do
      assert_equal(0, cli.run("foo"))
    end
    assert_equal("Hello Ruby", out.strip)
  end
end
