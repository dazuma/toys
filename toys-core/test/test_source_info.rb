# frozen_string_literal: true

require "helper"
require "toys/utils/gems"
require "toys/utils/git_cache"

describe Toys::SourceInfo do
  let(:lookup_cases_dir) { File.join(File.dirname(__dir__), "test-data", "lookup-cases") }
  let(:directory_path) { File.join(lookup_cases_dir, "config-items") }
  let(:config_items_dir) { directory_path }
  let(:lib_dirs_path) { File.join(lookup_cases_dir, "lib-dirs") }
  let(:preloads_path) { File.join(lookup_cases_dir, "preloads") }
  let(:file_path) { File.join(directory_path, ".toys.rb") }
  let(:path_with_data) { File.join(lookup_cases_dir, "data-finder") }
  let(:bad_path) { File.join(lookup_cases_dir, "doesnotexist") }
  let(:git_remote) { "https://github.com/dazuma/toys.git" }
  let(:git_commit) { "main" }
  let(:git_directory_path) { "toys-core/test-data/lookup-cases/config-items" }
  let(:git_file_path) { "toys-core/test-data/lookup-cases/config-items/.toys.rb" }
  let(:git_path_with_data) { "toys-core/test-data/lookup-cases/data-finder" }

  # Stands in for a GitCache holding a checkout of this repo, so that paths
  # within the repo resolve without touching the network.
  let(:git_cache) {
    repo_root = File.dirname(File.dirname(__dir__))
    cache = Object.new
    cache.define_singleton_method(:get) do |_remote, path:, **_opts|
      File.join(repo_root, path)
    end
    cache
  }

  # The gem fixtures use toys-core itself, whose gem directory is this
  # source tree, so that gem paths resolve to real files. Activation is
  # stubbed out because the gem is already loaded.
  let(:gem_name) { "toys-core" }
  let(:gem_version) { Gem.loaded_specs["toys-core"].version }
  let(:gem_toys_dir) { "test-data/lookup-cases" }
  let(:gem_directory_path) { "test-data/lookup-cases/config-items" }
  let(:gem_file_path) { "test-data/lookup-cases/config-items/.toys.rb" }
  let(:gem_path_with_data) { "test-data/lookup-cases/data-finder" }
  let(:gems_util) {
    util = Object.new
    util.define_singleton_method(:activate) { |*_args| nil }
    util
  }

  let(:my_proc) { proc { :a } }
  let(:my_proc2) { proc { :b } }
  let(:data_dir_name) { ".data" }
  let(:custom_source_name) { "mysource" }
  let(:priority) { -1 }

  describe "creation" do
    it "creates a file system root pointing to a directory" do
      si = Toys::SourceInfo.create_path_root(directory_path, priority,
                                             context_directory: :path)
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_equal(directory_path, si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal(directory_path, si.source_name)
    end

    it "creates a file system root pointing to a file" do
      si = Toys::SourceInfo.create_path_root(file_path, priority,
                                             context_directory: :parent)
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_equal(directory_path, si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal(file_path, si.source_name)
    end

    it "creates a proc root" do
      si = Toys::SourceInfo.create_proc_root(my_proc, priority,
                                             source_name: custom_source_name)
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_proc, si.source)
      assert_equal(:proc, si.source_type)
      assert_nil(si.source_path)
      assert_equal(my_proc, si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal(custom_source_name, si.source_name)
    end

    it "creates a git root pointing to a directory" do
      si = Toys::SourceInfo.create_git_root(git_remote, priority,
                                            git_path: git_directory_path,
                                            git_commit: git_commit,
                                            git_cache: git_cache)
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_directory_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "creates a gem root pointing to a directory" do
      si = Toys::SourceInfo.create_gem_root(gem_name, priority,
                                            gem_path: "config-items",
                                            gem_toys_dir: gem_toys_dir,
                                            gems_util: gems_util)
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(gem_name, si.gem_name)
      assert_equal(gem_version, si.gem_version)
      assert_equal(gem_directory_path, si.gem_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_directory_path})",
                   si.source_name)
    end

    it "errors when attempting to create a file system root with a nonexistent path" do
      assert_raises(Toys::ToolDefinitionError) do
        Toys::SourceInfo.create_path_root(bad_path, priority)
      end
    end
  end

  describe "#relative_child" do
    it "creates a relative child of a file system root" do
      parent = Toys::SourceInfo.create_path_root(directory_path, priority,
                                                 context_directory: :parent)
      si = parent.relative_child(".toys.rb")
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(lookup_cases_dir, si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal(file_path, si.source_name)
    end

    it "creates a relative child of a git root" do
      parent = Toys::SourceInfo.create_git_root(git_remote, priority,
                                                git_path: git_directory_path,
                                                git_commit: git_commit,
                                                git_cache: git_cache)
      si = parent.relative_child(".toys.rb")
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_file_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal("git(remote=#{git_remote} path=#{git_file_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "creates a relative child of a gem root" do
      parent = Toys::SourceInfo.create_gem_root(gem_name, priority,
                                                gem_path: "config-items",
                                                gem_toys_dir: gem_toys_dir,
                                                gems_util: gems_util)
      si = parent.relative_child(".toys.rb")
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(gem_name, si.gem_name)
      assert_equal(gem_version, si.gem_version)
      assert_equal(gem_file_path, si.gem_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_file_path})",
                   si.source_name)
    end

    it "errors when attempting to create a relative child of a file" do
      parent = Toys::SourceInfo.create_path_root(file_path, priority)
      assert_raises(::ArgumentError) do
        parent.relative_child(".toys.rb")
      end
    end

    it "errors when attempting to create a relative child of a proc" do
      parent = Toys::SourceInfo.create_proc_root(my_proc, priority,
                                                 source_name: custom_source_name)
      assert_raises(::ArgumentError) do
        parent.relative_child(".toys.rb")
      end
    end
  end

  describe "#absolute_child" do
    it "creates an absolute child of a file system root" do
      parent = Toys::SourceInfo.create_path_root(path_with_data, priority,
                                                 context_directory: lookup_cases_dir)
      si = parent.absolute_child(file_path)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(lookup_cases_dir, si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal(file_path, si.source_name)
    end

    it "creates an absolute child of a proc root" do
      parent = Toys::SourceInfo.create_proc_root(my_proc, priority,
                                                 source_name: custom_source_name)
      si = parent.absolute_child(file_path)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal(file_path, si.source_name)
    end
  end

  describe "#git_child" do
    it "creates a git child of a file system root" do
      parent = Toys::SourceInfo.create_path_root(path_with_data, priority,
                                                 context_directory: lookup_cases_dir)
      si = parent.git_child(git_remote,
                            child_git_path: git_directory_path,
                            child_git_commit: git_commit,
                            git_cache: git_cache)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(lookup_cases_dir, si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_directory_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "creates a git child of a git root" do
      parent = Toys::SourceInfo.create_git_root(git_remote, priority,
                                                git_path: git_path_with_data,
                                                git_commit: git_commit,
                                                git_cache: git_cache)
      si = parent.git_child(git_remote,
                            child_git_path: git_directory_path,
                            child_git_commit: git_commit,
                            git_cache: git_cache)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_directory_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "creates a git child of a gem root" do
      parent = Toys::SourceInfo.create_gem_root(gem_name, priority,
                                                gem_path: "data-finder",
                                                gem_toys_dir: gem_toys_dir,
                                                gems_util: gems_util)
      si = parent.git_child(git_remote,
                            child_git_path: git_directory_path,
                            child_git_commit: git_commit,
                            git_cache: git_cache)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_directory_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "creates a git child of a proc root" do
      parent = Toys::SourceInfo.create_proc_root(my_proc, priority,
                                                 source_name: custom_source_name)
      si = parent.git_child(git_remote,
                            child_git_path: git_directory_path,
                            child_git_commit: git_commit,
                            git_cache: git_cache)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_directory_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end
  end

  describe "#gem_child" do
    it "creates a gem child of a file system root" do
      parent = Toys::SourceInfo.create_path_root(path_with_data, priority,
                                                 context_directory: lookup_cases_dir)
      si = parent.gem_child(gem_name,
                            child_gem_path: "config-items",
                            gem_toys_dir: gem_toys_dir,
                            gems_util: gems_util)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(lookup_cases_dir, si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(gem_name, si.gem_name)
      assert_equal(gem_version, si.gem_version)
      assert_equal(gem_directory_path, si.gem_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_directory_path})",
                   si.source_name)
    end

    it "creates a gem child of a git root" do
      parent = Toys::SourceInfo.create_git_root(git_remote, priority,
                                                git_path: git_path_with_data,
                                                git_commit: git_commit,
                                                git_cache: git_cache)
      si = parent.gem_child(gem_name,
                            child_gem_path: "config-items",
                            gem_toys_dir: gem_toys_dir,
                            gems_util: gems_util)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(gem_name, si.gem_name)
      assert_equal(gem_version, si.gem_version)
      assert_equal(gem_directory_path, si.gem_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_directory_path})",
                   si.source_name)
    end

    it "creates a gem child of a gem root" do
      parent = Toys::SourceInfo.create_gem_root(gem_name, priority,
                                                gem_path: "data-finder",
                                                gem_toys_dir: gem_toys_dir,
                                                gems_util: gems_util)
      si = parent.gem_child(gem_name,
                            child_gem_path: "config-items",
                            gem_toys_dir: gem_toys_dir,
                            gems_util: gems_util)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(gem_name, si.gem_name)
      assert_equal(gem_version, si.gem_version)
      assert_equal(gem_directory_path, si.gem_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_directory_path})",
                   si.source_name)
    end

    it "creates a gem child of a proc root" do
      parent = Toys::SourceInfo.create_proc_root(my_proc, priority,
                                                 source_name: custom_source_name)
      si = parent.gem_child(gem_name,
                            child_gem_path: "config-items",
                            gem_toys_dir: gem_toys_dir,
                            gems_util: gems_util)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(gem_name, si.gem_name)
      assert_equal(gem_version, si.gem_version)
      assert_equal(gem_directory_path, si.gem_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_directory_path})",
                   si.source_name)
    end
  end

  describe "#proc_child" do
    it "creates a proc child of a file system root" do
      parent = Toys::SourceInfo.create_path_root(file_path, priority,
                                                 context_directory: :parent)
      si = parent.proc_child(my_proc)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(directory_path, si.context_directory)
      assert_equal(my_proc, si.source)
      assert_equal(:proc, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_equal(my_proc, si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal(file_path, si.source_name)
    end

    it "creates a proc child of a git root" do
      parent = Toys::SourceInfo.create_git_root(git_remote, priority,
                                                git_path: git_file_path,
                                                git_commit: git_commit,
                                                git_cache: git_cache)
      si = parent.proc_child(my_proc)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_proc, si.source)
      assert_equal(:proc, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_equal(my_proc, si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_file_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal("git(remote=#{git_remote} path=#{git_file_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "creates a proc child of a gem root" do
      parent = Toys::SourceInfo.create_gem_root(gem_name, priority,
                                                gem_path: "config-items/.toys.rb",
                                                gem_toys_dir: gem_toys_dir,
                                                gems_util: gems_util)
      si = parent.proc_child(my_proc)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_proc, si.source)
      assert_equal(:proc, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_equal(my_proc, si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(gem_name, si.gem_name)
      assert_equal(gem_version, si.gem_version)
      assert_equal(gem_file_path, si.gem_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_file_path})",
                   si.source_name)
    end

    it "creates a proc child of a proc root" do
      parent = Toys::SourceInfo.create_proc_root(my_proc, priority,
                                                 source_name: custom_source_name)
      si = parent.proc_child(my_proc2)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_proc2, si.source)
      assert_equal(:proc, si.source_type)
      assert_nil(si.source_path)
      assert_equal(my_proc2, si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_nil(si.gem_name)
      assert_nil(si.gem_version)
      assert_nil(si.gem_path)
      assert_equal(custom_source_name, si.source_name)
    end
  end

  it "looks up data from a root" do
    si = Toys::SourceInfo.create_path_root(path_with_data, priority)
    path = si.find_data("foo/root.txt")
    assert_equal(File.join(path_with_data, data_dir_name, "foo", "root.txt"), path)
  end

  describe "#index_child" do
    it "finds the index file in a directory" do
      si = Toys::SourceInfo.create_path_root(config_items_dir, priority)
      child = si.index_child
      assert_equal(File.join(config_items_dir, ".toys.rb"), child.source_path)
      assert_equal(:file, child.source_type)
    end

    it "returns nil when the directory has no index file" do
      si = Toys::SourceInfo.create_path_root(File.join(lib_dirs_path, "ns"), priority)
      assert_nil(si.index_child)
    end

    it "errors on a source that is not a directory" do
      si = Toys::SourceInfo.create_path_root(file_path, priority)
      assert_raises(::ArgumentError) do
        si.index_child
      end
    end
  end

  describe "#find_lib_paths" do
    it "returns nothing for a directory with no lib directory" do
      si = Toys::SourceInfo.create_path_root(config_items_dir, priority)
      assert_empty(si.find_lib_paths)
    end

    it "returns nothing for a file source" do
      si = Toys::SourceInfo.create_path_root(file_path, priority)
      assert_empty(si.find_lib_paths)
    end

    it "finds the lib directory of a directory source" do
      si = Toys::SourceInfo.create_path_root(lib_dirs_path, priority)
      assert_equal([File.join(lib_dirs_path, ".lib")], si.find_lib_paths)
    end

    it "orders a source ahead of its ancestors" do
      si = Toys::SourceInfo.create_path_root(lib_dirs_path, priority).relative_child("ns")
      assert_equal([File.join(lib_dirs_path, "ns", ".lib"), File.join(lib_dirs_path, ".lib")],
                   si.find_lib_paths)
    end
  end

  describe "#find_preload_files" do
    it "returns nothing for a directory with no preloads" do
      si = Toys::SourceInfo.create_path_root(config_items_dir, priority)
      assert_empty(si.find_preload_files)
    end

    it "returns nothing for a file source" do
      si = Toys::SourceInfo.create_path_root(file_path, priority)
      assert_empty(si.find_preload_files)
    end

    it "finds a standalone preload file" do
      si = Toys::SourceInfo.create_path_root(File.join(preloads_path, "ns-2"), priority)
      assert_equal([File.join(preloads_path, "ns-2", ".preload.rb")], si.find_preload_files)
    end

    it "finds sorted ruby files in a preload directory" do
      si = Toys::SourceInfo.create_path_root(File.join(preloads_path, "ns-1", "ns-1a"), priority)
      preload_dir = File.join(preloads_path, "ns-1", "ns-1a", ".preload")
      assert_equal([File.join(preload_dir, "preloaded1.rb"), File.join(preload_dir, "preloaded2.rb")],
                   si.find_preload_files)
    end

    it "does not include preloads from ancestors" do
      si = Toys::SourceInfo.create_path_root(File.join(preloads_path, "ns-1"), priority)
                           .relative_child("ns-1a")
      refute_includes(si.find_preload_files, File.join(preloads_path, "ns-1", ".preload.rb"))
    end
  end

  describe "resolution errors" do
    let(:non_ruby_file) { File.join(lookup_cases_dir, "normal-file-hierarchy", "hello.txt") }

    it "raises SourceResolutionError for an unreadable path" do
      error = assert_raises(Toys::SourceResolutionError) do
        Toys::SourceInfo.check_path(bad_path, false)
      end
      assert_equal("Cannot read: #{bad_path}", error.message)
    end

    it "raises SourceResolutionError for a non-ruby file" do
      error = assert_raises(Toys::SourceResolutionError) do
        Toys::SourceInfo.check_path(non_ruby_file, false)
      end
      assert_equal("File is not a ruby file: #{non_ruby_file}", error.message)
    end

    it "raises SourceResolutionError for a path that is neither a file nor a directory" do
      error = assert_raises(Toys::SourceResolutionError) do
        Toys::SourceInfo.check_path(File::NULL, false)
      end
      assert_equal("Not a ruby file or directory: #{File::NULL}", error.message)
    end

    it "raises SourceResolutionError when a gem cannot be activated" do
      failing_gems_util = Object.new
      failing_gems_util.define_singleton_method(:activate) do |*_args|
        raise Toys::Utils::Gems::ActivationFailedError, "activation went wrong"
      end
      error = assert_raises(Toys::SourceResolutionError) do
        Toys::SourceInfo.resolve_gem_info(failing_gems_util, gem_name, nil, nil, nil)
      end
      assert_equal("activation went wrong", error.message)
    end

    it "raises SourceResolutionError when an activated gem cannot be found" do
      error = assert_raises(Toys::SourceResolutionError) do
        Toys::SourceInfo.resolve_gem_info(gems_util, "nonexistent-gem", nil, nil, nil)
      end
      assert_equal("Unable to find gem nonexistent-gem", error.message)
    end

    it "raises SourceResolutionError when a git repo cannot be accessed" do
      failing_git_cache = Object.new
      failing_git_cache.define_singleton_method(:get) do |*_args, **_opts|
        raise Toys::Utils::GitCache::Error, "repo went wrong"
      end
      error = assert_raises(Toys::SourceResolutionError) do
        Toys::SourceInfo.resolve_git_info(failing_git_cache, git_remote, nil, nil, false)
      end
      assert_equal("Unable to access git repo #{git_remote}: repo went wrong", error.message)
    end

    it "raises an error that existing rescues of ToolDefinitionError still catch" do
      assert_raises(Toys::ToolDefinitionError) do
        Toys::SourceInfo.check_path(bad_path, false)
      end
    end
  end
end
