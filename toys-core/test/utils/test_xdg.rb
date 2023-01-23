# frozen_string_literal: true

require "helper"
require "fileutils"
require "pathname"
require "toys/utils/xdg"

describe Toys::Utils::XDG do
  include Toys::TestHelper

  let(:root_dir) { Toys::Compat.absolute_path?("/usr") ? "/" : "c:" }
  let(:home_dir) { File.join(root_dir, "home") }
  let(:workspace_dir) { File.join(root_dir, "workspace") }
  let(:env) { { "HOME" => home_dir } }
  let(:xdg) { Toys::Utils::XDG.new(env: env) }
  let(:base_dir) { File.dirname(__dir__) }
  let(:data1_dir) { File.join(base_dir, "data") }
  let(:data2_dir) { File.join(base_dir, "data2") }
  let(:default_data_home) { File.join(home_dir, ".local", "share") }
  let(:default_config_home) { File.join(home_dir, ".config") }
  let(:default_state_home) { File.join(home_dir, ".local", "state") }
  let(:default_cache_home) { File.join(home_dir, ".cache") }
  let(:default_executable_home) { File.join(home_dir, ".local", "bin") }

  it "can be loaded in isolation" do
    result = isolate_ruby do |io|
      io.puts "require 'toys/utils/xdg'"
      io.puts "Toys::Utils::XDG.new.data_dirs"
    end
    assert result.success?
  end

  describe "#data_home" do
    it "honors XDG_DATA_HOME" do
      custom_dir = File.join(workspace_dir, "data")
      env["XDG_DATA_HOME"] = custom_dir
      assert_equal(custom_dir, xdg.data_home)
    end

    it "returns the default" do
      assert_equal(default_data_home, xdg.data_home)
    end

    it "ignores non-absolute paths in XDG_DATA_HOME" do
      env["XDG_DATA_HOME"] = "my/data"
      assert_equal(default_data_home, xdg.data_home)
    end
  end

  describe "#config_home" do
    it "honors XDG_CONFIG_HOME" do
      custom_dir = File.join(workspace_dir, "config")
      env["XDG_CONFIG_HOME"] = custom_dir
      assert_equal(custom_dir, xdg.config_home)
    end

    it "returns the default" do
      assert_equal(default_config_home, xdg.config_home)
    end
  end

  describe "#state_home" do
    it "honors XDG_STATE_HOME" do
      custom_dir = File.join(workspace_dir, "state")
      env["XDG_STATE_HOME"] = custom_dir
      assert_equal(custom_dir, xdg.state_home)
    end

    it "returns the default" do
      assert_equal(default_state_home, xdg.state_home)
    end
  end

  describe "#cache_home" do
    it "honors XDG_CACHE_HOME" do
      custom_dir = File.join(workspace_dir, "cache")
      env["XDG_CACHE_HOME"] = custom_dir
      assert_equal(custom_dir, xdg.cache_home)
    end

    it "returns the default" do
      assert_equal(default_cache_home, xdg.cache_home)
    end
  end

  describe "#executable_home" do
    it "returns the default" do
      assert_equal(default_executable_home, xdg.executable_home)
    end
  end

  describe "#data_dirs" do
    it "honors XDG_DATA_DIRS" do
      dir1 = File.join(root_dir, "var1", "data")
      dir2 = File.join(root_dir, "var2", "data")
      env["XDG_DATA_DIRS"] = "#{dir1}#{File::PATH_SEPARATOR}#{dir2}"
      assert_equal([dir1, dir2], xdg.data_dirs)
    end

    it "returns the default" do
      expected = root_dir == "/" ? ["/usr/local/share", "/usr/share"] : []
      assert_equal(expected, xdg.data_dirs)
    end

    it "ignores non-absolute paths in XDG_DATA_DIRS" do
      dir2 = File.join(root_dir, "var2", "data")
      env["XDG_DATA_DIRS"] = "my/data#{File::PATH_SEPARATOR}#{dir2}"
      assert_equal([dir2], xdg.data_dirs)
    end
  end

  describe "#config_dirs" do
    it "honors XDG_CONFIG_DIRS" do
      dir1 = File.join(root_dir, "var1", "config")
      dir2 = File.join(root_dir, "var2", "config")
      env["XDG_CONFIG_DIRS"] = "#{dir1}#{File::PATH_SEPARATOR}#{dir2}"
      assert_equal([dir1, dir2], xdg.config_dirs)
    end

    it "returns the default" do
      expected = root_dir == "/" ? ["/etc/xdg"] : []
      assert_equal(expected, xdg.config_dirs)
    end
  end

  describe "#runtime_dir" do
    it "honors XDG_RUNTIME_DIR" do
      custom_dir = File.join(workspace_dir, "run")
      env["XDG_RUNTIME_DIR"] = custom_dir
      assert_equal(custom_dir, xdg.runtime_dir)
    end

    it "returns nil if not set" do
      assert_nil(xdg.runtime_dir)
    end
  end

  describe "#lookup_data" do
    it "finds files" do
      env["XDG_DATA_HOME"] = data1_dir
      env["XDG_DATA_DIRS"] = data2_dir
      input1_path = File.join(data1_dir, "input.txt")
      input2_path = File.join(data2_dir, "input.txt")
      assert_equal([input1_path, input2_path], xdg.lookup_data("input.txt"))
    end

    it "finds directories" do
      env["XDG_DATA_HOME"] = data2_dir
      env["XDG_DATA_DIRS"] = data1_dir
      dir_path = File.join(data1_dir, "indirectory")
      assert_equal([dir_path], xdg.lookup_data("indirectory", type: :directory))
    end

    it "does not find directories when asked for files" do
      env["XDG_DATA_HOME"] = data2_dir
      env["XDG_DATA_DIRS"] = data1_dir
      file_path = File.join(data2_dir, "indirectory")
      assert_equal([file_path], xdg.lookup_data("indirectory", type: :file))
    end

    it "honors mulitple types" do
      env["XDG_DATA_HOME"] = data2_dir
      env["XDG_DATA_DIRS"] = data1_dir
      file_path = File.join(data2_dir, "indirectory")
      dir_path = File.join(data1_dir, "indirectory")
      assert_equal([file_path, dir_path], xdg.lookup_data("indirectory", type: [:file, :directory]))
    end

    it "honors the any type" do
      env["XDG_DATA_HOME"] = data2_dir
      env["XDG_DATA_DIRS"] = data1_dir
      file_path = File.join(data2_dir, "indirectory")
      dir_path = File.join(data1_dir, "indirectory")
      assert_equal([file_path, dir_path], xdg.lookup_data("indirectory", type: :any))
    end

    it "finds nested files" do
      env["XDG_DATA_HOME"] = data1_dir
      env["XDG_DATA_DIRS"] = data2_dir
      input1_path = File.join(data1_dir, "indirectory", "content.txt")
      assert_equal([input1_path], xdg.lookup_data("indirectory/content.txt"))
    end

    it "finds nothing" do
      env["XDG_DATA_HOME"] = data1_dir
      env["XDG_DATA_DIRS"] = data2_dir
      assert_empty(xdg.lookup_data("blah"))
    end
  end

  describe "#lookup_config" do
    it "finds files" do
      env["XDG_CONFIG_HOME"] = data1_dir
      env["XDG_CONFIG_DIRS"] = data2_dir
      input1_path = File.join(data1_dir, "input.txt")
      input2_path = File.join(data2_dir, "input.txt")
      assert_equal([input1_path, input2_path], xdg.lookup_config("input.txt"))
    end
  end

  describe "ensure methods" do
    let(:parent_dir) { File.join(data2_dir, "temp1") }
    let(:target_dir) { File.join(parent_dir, "temp2") }

    after do
      FileUtils.rm_rf(parent_dir)
    end

    describe "#ensure_data_subdir" do
      it "creates subdirs" do
        refute(File.directory?(target_dir))
        env["XDG_DATA_HOME"] = data2_dir
        assert_equal(target_dir, xdg.ensure_data_subdir("temp1/temp2"))
        assert(File.directory?(target_dir))
      end

      it "leaves existing directory alone" do
        FileUtils.mkdir_p(target_dir)
        env["XDG_DATA_HOME"] = data2_dir
        assert_equal(target_dir, xdg.ensure_data_subdir("temp1/temp2"))
        assert(File.directory?(target_dir))
      end

      it "errors if the target is already a file" do
        FileUtils.mkdir_p(parent_dir)
        FileUtils.touch(target_dir)
        env["XDG_DATA_HOME"] = data2_dir
        assert_raises(Errno::EEXIST) do
          xdg.ensure_data_subdir("temp1/temp2")
        end
      end
    end

    describe "#ensure_config_subdir" do
      it "creates subdirs" do
        refute(File.directory?(target_dir))
        env["XDG_CONFIG_HOME"] = data2_dir
        assert_equal(target_dir, xdg.ensure_config_subdir("temp1/temp2"))
        assert(File.directory?(target_dir))
      end
    end

    describe "#ensure_state_subdir" do
      it "creates subdirs" do
        refute(File.directory?(target_dir))
        env["XDG_STATE_HOME"] = data2_dir
        assert_equal(target_dir, xdg.ensure_state_subdir("temp1/temp2"))
        assert(File.directory?(target_dir))
      end
    end

    describe "#ensure_cache_subdir" do
      it "creates subdirs" do
        refute(File.directory?(target_dir))
        env["XDG_CACHE_HOME"] = data2_dir
        assert_equal(target_dir, xdg.ensure_cache_subdir("temp1/temp2"))
        assert(File.directory?(target_dir))
      end
    end
  end
end
