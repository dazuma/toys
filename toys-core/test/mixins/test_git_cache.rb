# frozen_string_literal: true

require "helper"
require "toys/standard_mixins/git_cache"

describe Toys::StandardMixins::GitCache do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: [])
  }

  it "accesses git_cache" do
    cli.add_config_block do
      tool "foo" do
        include :git_cache
        def run
          puts git_cache.cache_dir
        end
      end
    end
    out, _err = capture_subprocess_io do
      assert_equal(0, cli.run("foo"))
    end
    expected = File.expand_path(File.join(".cache", "toys", "git"), ::Dir.home)
    assert_equal(expected, out.strip)
  end
end
