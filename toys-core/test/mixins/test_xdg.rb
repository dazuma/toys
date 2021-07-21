# frozen_string_literal: true

require "helper"
require "toys/standard_mixins/xdg"

describe Toys::StandardMixins::XDG do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: [])
  }

  it "accesses xdg" do
    cli.add_config_block do
      tool "foo" do
        include :xdg
        def run
          puts xdg.config_home
        end
      end
    end
    out, _err = capture_subprocess_io do
      assert_equal(0, cli.run("foo"))
    end
    assert_equal(File.join(ENV["HOME"], ".config"), out.strip)
  end
end
