# frozen_string_literal: true

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
