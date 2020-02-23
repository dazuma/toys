# frozen_string_literal: true

require "helper"
require "toys/standard_mixins/fileutils"

describe Toys::StandardMixins::Fileutils do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: [])
  }

  it "adds fileutils module" do
    cli.add_config_block do
      tool "foo" do
        include :fileutils
        def run
          exit(self.class.included_modules.include?(::FileUtils) ? 1 : 2)
        end
      end
    end
    assert_equal(1, cli.run("foo"))
  end
end
