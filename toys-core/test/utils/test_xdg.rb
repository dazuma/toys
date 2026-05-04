# frozen_string_literal: true

require "helper"
require "toys/utils/xdg"

# This is just a token set of smoke tests to ensure the library vendored
# correctly from its source in the simple_xdg gem. The full test suite is
# present in that gem's source.

describe Toys::Utils::XDG do
  let(:root_dir) { ::File.absolute_path?("/usr") ? "/" : "c:" }
  let(:home_dir) { ::File.join(root_dir, "home") }
  let(:env) { { "HOME" => home_dir } }
  let(:xdg) { ::Toys::Utils::XDG.new(env: env) }
  let(:default_data_home) { ::File.join(home_dir, ".local", "share") }
  let(:default_config_home) { ::File.join(home_dir, ".config") }
  let(:default_state_home) { ::File.join(home_dir, ".local", "state") }
  let(:default_cache_home) { ::File.join(home_dir, ".cache") }
  let(:default_executable_home) { ::File.join(home_dir, ".local", "bin") }

  it "has the expected classes" do
    assert(defined?(::Toys::Utils::XDG))
    assert(defined?(::Toys::Utils::XDG::VERSION))
  end

  it "returns the defaults" do
    assert_equal(default_data_home, xdg.data_home)
    assert_equal(default_config_home, xdg.config_home)
    assert_equal(default_state_home, xdg.state_home)
    assert_equal(default_cache_home, xdg.cache_home)
    assert_equal(default_executable_home, xdg.executable_home)
  end
end
