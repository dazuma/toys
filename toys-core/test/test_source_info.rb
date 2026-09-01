# frozen_string_literal: true

require "helper"
require "toys/utils/gems"
require "toys/utils/git_cache"

# Stand-ins for Toys::Tool subclasses. A SourceInfo only records the class and
# reads its name, and a real Toys::Tool subclass cannot be created here because
# subclassing is allowed only from within a tool file.
MyToolClass = Class.new
MyNestedToolClass = Class.new

describe Toys::SourceInfo do
  let(:lookup_cases_dir) { File.join(File.dirname(__dir__), "test-data", "lookup-cases") }
  let(:directory_path) { File.join(lookup_cases_dir, "config-items") }
  let(:config_items_dir) { directory_path }
  let(:lib_dirs_path) { File.join(lookup_cases_dir, "lib-dirs") }
  let(:preloads_path) { File.join(lookup_cases_dir, "preloads") }
  let(:file_path) { File.join(directory_path, ".toys.rb") }
  let(:path_with_data) { File.join(lookup_cases_dir, "data-finder") }
  let(:bad_path) { File.join(lookup_cases_dir, "doesnotexist") }
  let(:non_ruby_file) { File.join(lookup_cases_dir, "normal-file-hierarchy", "hello.txt") }
  let(:git_remote) { "https://github.com/dazuma/toys.git" }
  let(:git_commit) { "main" }
  let(:git_directory_path) { "toys-core/test-data/lookup-cases/config-items" }
  let(:git_file_path) { "toys-core/test-data/lookup-cases/config-items/.toys.rb" }
  let(:git_path_with_data) { "toys-core/test-data/lookup-cases/data-finder" }

  # Records the arguments it is asked to resolve, and answers with a path in
  # this repo, so that git sources resolve without touching the network.
  let(:git_cache_calls) { [] }
  let(:git_cache) {
    calls = git_cache_calls
    repo_root = File.dirname(File.dirname(__dir__))
    cache = Object.new
    cache.define_singleton_method(:get) do |remote, path:, commit: nil, update: false|
      calls << {remote: remote, path: path, commit: commit, update: update}
      File.join(repo_root, path)
    end
    cache
  }

  # The gem fixtures use toys-core itself, whose gem directory is this source
  # tree, so that gem paths resolve to real files. Activation is recorded
  # rather than performed, because the gem is already loaded.
  let(:gem_name) { "toys-core" }
  let(:gem_version) { Gem.loaded_specs["toys-core"].version }
  let(:gem_toys_dir) { "test-data/lookup-cases" }
  let(:gem_directory_path) { "test-data/lookup-cases/config-items" }
  let(:gem_file_path) { "test-data/lookup-cases/config-items/.toys.rb" }
  let(:gem_path_with_data) { "test-data/lookup-cases/data-finder" }
  let(:gems_util_calls) { [] }
  let(:gems_util) {
    calls = gems_util_calls
    util = Object.new
    util.define_singleton_method(:activate) do |name, *versions|
      calls << {name: name, versions: versions}
    end
    util
  }

  let(:my_proc) { proc { :a } }
  let(:my_proc2) { proc { :b } }
  let(:my_class) { MyToolClass }
  let(:my_class2) { MyNestedToolClass }
  let(:data_dir_name) { ".data" }
  let(:custom_source_name) { "mysource" }
  let(:priority) { -1 }

  # Resolves a root at the standard test priority.
  def resolve_root(spec, git_cache: nil, gems_util: nil)
    Toys::SourceInfo.resolve(spec, priority: priority, git_cache: git_cache, gems_util: gems_util)
  end

  # Asserts the origin kind, and for git and gem origins the fields fixed when
  # the source spec was resolved. The path is the origin path of the *root*
  # source, which does not change as children descend below it.
  def assert_local_origin(source_info)
    assert_instance_of(Toys::SourceInfo::Origin::Local, source_info.origin)
  end

  def assert_block_origin(source_info)
    assert_instance_of(Toys::SourceInfo::Origin::Block, source_info.origin)
  end

  def assert_git_origin(source_info, path)
    origin = source_info.origin
    assert_instance_of(Toys::SourceInfo::Origin::Git, origin)
    assert_equal(git_remote, origin.remote)
    assert_equal(git_commit, origin.commit)
    assert_equal(path, origin.path)
  end

  def assert_gem_origin(source_info, path)
    origin = source_info.origin
    assert_instance_of(Toys::SourceInfo::Origin::Gem, origin)
    assert_equal(gem_name, origin.name)
    assert_equal(gem_version, origin.version)
    assert_equal(path, origin.path)
  end

  describe "resolving a root" do
    it "resolves a path spec pointing to a directory" do
      si = resolve_root(Toys::SourceSpec.path(directory_path, context_directory: directory_path))
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_equal(directory_path, si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_local_origin(si)
      assert_equal(directory_path, si.source_name)
    end

    it "resolves a path spec pointing to a file" do
      si = resolve_root(Toys::SourceSpec.path(file_path, context_directory: directory_path))
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_equal(directory_path, si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_local_origin(si)
      assert_equal(file_path, si.source_name)
    end

    it "resolves a block spec" do
      si = resolve_root(Toys::SourceSpec.block(source_name: custom_source_name, &my_proc))
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_proc, si.source)
      assert_equal(:proc, si.source_type)
      assert_nil(si.source_path)
      assert_equal(my_proc, si.source_proc)
      assert_block_origin(si)
      assert_equal(custom_source_name, si.source_name)
    end

    it "resolves a git spec pointing to a directory" do
      spec = Toys::SourceSpec.git(git_remote, path: git_directory_path, commit: git_commit)
      si = resolve_root(spec, git_cache: git_cache)
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_git_origin(si, git_directory_path)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "resolves a gem spec pointing to a directory" do
      spec = Toys::SourceSpec.gem(gem_name, path: "config-items", toys_dir: gem_toys_dir)
      si = resolve_root(spec, gems_util: gems_util)
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_gem_origin(si, gem_directory_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_directory_path})",
                   si.source_name)
    end

    it "passes the gem version requirements through to activation" do
      spec = Toys::SourceSpec.gem(gem_name, version: "~> 0.1", toys_dir: gem_toys_dir)
      resolve_root(spec, gems_util: gems_util)
      assert_equal([{name: gem_name, versions: ["~> 0.1"]}], gems_util_calls)
    end

    it "errors when resolving a path spec with a nonexistent path" do
      assert_raises(Toys::ToolSourceError) do
        resolve_root(Toys::SourceSpec.path(bad_path))
      end
    end

    it "errors when neither a priority nor a parent is given" do
      assert_raises(::ArgumentError) do
        Toys::SourceInfo.resolve(Toys::SourceSpec.path(directory_path))
      end
    end

    it "errors when given something that is not a source spec" do
      assert_raises(::ArgumentError) do
        Toys::SourceInfo.resolve(directory_path, priority: priority)
      end
    end
  end

  describe "resolving a path child" do
    it "resolves a path spec under a path parent" do
      parent = resolve_root(Toys::SourceSpec.path(path_with_data, context_directory: lookup_cases_dir))
      si = Toys::SourceInfo.resolve(Toys::SourceSpec.path(file_path), parent: parent)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(lookup_cases_dir, si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_local_origin(si)
      assert_equal(file_path, si.source_name)
    end

    it "resolves a path spec under a block parent" do
      parent = resolve_root(Toys::SourceSpec.block(source_name: custom_source_name, &my_proc))
      si = Toys::SourceInfo.resolve(Toys::SourceSpec.path(file_path), parent: parent)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_local_origin(si)
      assert_equal(file_path, si.source_name)
    end

    it "errors when resolving when the parent is a git source" do
      spec = Toys::SourceSpec.git(git_remote, path: git_path_with_data, commit: git_commit)
      parent = resolve_root(spec, git_cache: git_cache)
      error = assert_raises(Toys::ToolSourceError) do
        Toys::SourceInfo.resolve(Toys::SourceSpec.path(file_path), parent: parent)
      end
      assert_equal("Git source #{parent.source_name} tried to load from the local file system",
                   error.message)
    end

    it "errors when resolving when the parent is a gem source" do
      spec = Toys::SourceSpec.gem(gem_name, path: "data-finder", toys_dir: gem_toys_dir)
      parent = resolve_root(spec, gems_util: gems_util)
      error = assert_raises(Toys::ToolSourceError) do
        Toys::SourceInfo.resolve(Toys::SourceSpec.path(file_path), parent: parent)
      end
      assert_equal("Gem source #{parent.source_name} tried to load from the local file system",
                   error.message)
    end

    it "errors when resolving a spec that carries relative paths" do
      parent = resolve_root(Toys::SourceSpec.path(path_with_data))
      spec = Toys::SourceSpec.path(directory_path, relative_paths: [".toys.rb"])
      assert_raises(::ArgumentError) do
        Toys::SourceInfo.resolve(spec, parent: parent)
      end
    end
  end

  describe "resolving a git child" do
    it "resolves a git spec under a path parent" do
      parent = resolve_root(Toys::SourceSpec.path(path_with_data, context_directory: lookup_cases_dir))
      spec = Toys::SourceSpec.git(git_remote, path: git_directory_path, commit: git_commit)
      si = Toys::SourceInfo.resolve(spec, parent: parent, git_cache: git_cache)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(lookup_cases_dir, si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_git_origin(si, git_directory_path)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "resolves a git spec under a git parent" do
      parent_spec = Toys::SourceSpec.git(git_remote, path: git_path_with_data, commit: git_commit)
      parent = resolve_root(parent_spec, git_cache: git_cache)
      spec = Toys::SourceSpec.git(git_remote, path: git_directory_path, commit: git_commit)
      si = Toys::SourceInfo.resolve(spec, parent: parent, git_cache: git_cache)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_git_origin(si, git_directory_path)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "resolves a git spec under a gem parent, dropping the gem fields" do
      parent_spec = Toys::SourceSpec.gem(gem_name, path: "data-finder", toys_dir: gem_toys_dir)
      parent = resolve_root(parent_spec, gems_util: gems_util)
      spec = Toys::SourceSpec.git(git_remote, path: git_directory_path, commit: git_commit)
      si = Toys::SourceInfo.resolve(spec, parent: parent, git_cache: git_cache)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_git_origin(si, git_directory_path)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "resolves a git spec under a block parent" do
      parent = resolve_root(Toys::SourceSpec.block(source_name: custom_source_name, &my_proc))
      spec = Toys::SourceSpec.git(git_remote, path: git_directory_path, commit: git_commit)
      si = Toys::SourceInfo.resolve(spec, parent: parent, git_cache: git_cache)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_git_origin(si, git_directory_path)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end
  end

  describe "resolving a gem child" do
    it "resolves a gem spec under a path parent" do
      parent = resolve_root(Toys::SourceSpec.path(path_with_data, context_directory: lookup_cases_dir))
      spec = Toys::SourceSpec.gem(gem_name, path: "config-items", toys_dir: gem_toys_dir)
      si = Toys::SourceInfo.resolve(spec, parent: parent, gems_util: gems_util)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(lookup_cases_dir, si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_gem_origin(si, gem_directory_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_directory_path})",
                   si.source_name)
    end

    it "resolves a gem spec under a git parent, dropping the git fields" do
      parent_spec = Toys::SourceSpec.git(git_remote, path: git_path_with_data, commit: git_commit)
      parent = resolve_root(parent_spec, git_cache: git_cache)
      spec = Toys::SourceSpec.gem(gem_name, path: "config-items", toys_dir: gem_toys_dir)
      si = Toys::SourceInfo.resolve(spec, parent: parent, gems_util: gems_util)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_gem_origin(si, gem_directory_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_directory_path})",
                   si.source_name)
    end

    it "resolves a gem spec under a gem parent" do
      parent_spec = Toys::SourceSpec.gem(gem_name, path: "data-finder", toys_dir: gem_toys_dir)
      parent = resolve_root(parent_spec, gems_util: gems_util)
      spec = Toys::SourceSpec.gem(gem_name, path: "config-items", toys_dir: gem_toys_dir)
      si = Toys::SourceInfo.resolve(spec, parent: parent, gems_util: gems_util)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_gem_origin(si, gem_directory_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_directory_path})",
                   si.source_name)
    end

    it "resolves a gem spec under a block parent" do
      parent = resolve_root(Toys::SourceSpec.block(source_name: custom_source_name, &my_proc))
      spec = Toys::SourceSpec.gem(gem_name, path: "config-items", toys_dir: gem_toys_dir)
      si = Toys::SourceInfo.resolve(spec, parent: parent, gems_util: gems_util)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_gem_origin(si, gem_directory_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_directory_path})",
                   si.source_name)
    end
  end

  describe "resolving a block child" do
    it "errors, because block sources are always roots" do
      parent = resolve_root(Toys::SourceSpec.path(directory_path))
      assert_raises(::ArgumentError) do
        Toys::SourceInfo.resolve(Toys::SourceSpec.block(&my_proc), parent: parent)
      end
    end
  end

  describe "child inheritance rules" do
    it "takes the priority from the parent, ignoring an explicit priority" do
      parent = resolve_root(Toys::SourceSpec.path(directory_path))
      si = Toys::SourceInfo.resolve(Toys::SourceSpec.path(file_path), parent: parent, priority: 100)
      assert_equal(priority, si.priority)
    end

    it "takes the context directory from the spec, overriding the parent" do
      parent = resolve_root(Toys::SourceSpec.path(path_with_data, context_directory: lookup_cases_dir))
      spec = Toys::SourceSpec.path(file_path, context_directory: "/somewhere/else")
      si = Toys::SourceInfo.resolve(spec, parent: parent)
      assert_expanded_path("/somewhere/else", si.context_directory)
    end

    it "takes the context directory from a git spec, overriding the parent" do
      parent = resolve_root(Toys::SourceSpec.path(path_with_data, context_directory: lookup_cases_dir))
      spec = Toys::SourceSpec.git(git_remote, path: git_directory_path, commit: git_commit,
                                  context_directory: "/somewhere/else")
      si = Toys::SourceInfo.resolve(spec, parent: parent, git_cache: git_cache)
      assert_expanded_path("/somewhere/else", si.context_directory)
    end

    it "takes the context directory from a gem spec, overriding the parent" do
      parent = resolve_root(Toys::SourceSpec.path(path_with_data, context_directory: lookup_cases_dir))
      spec = Toys::SourceSpec.gem(gem_name, path: "config-items", toys_dir: gem_toys_dir,
                                  context_directory: "/somewhere/else")
      si = Toys::SourceInfo.resolve(spec, parent: parent, gems_util: gems_util)
      assert_expanded_path("/somewhere/else", si.context_directory)
    end

    it "inherits the context directory when the spec does not give one" do
      parent = resolve_root(Toys::SourceSpec.path(path_with_data, context_directory: lookup_cases_dir))
      si = Toys::SourceInfo.resolve(Toys::SourceSpec.path(file_path), parent: parent)
      assert_equal(lookup_cases_dir, si.context_directory)
    end

    it "inherits the git remote when the spec does not give one" do
      parent_spec = Toys::SourceSpec.git(git_remote, path: git_path_with_data, commit: git_commit)
      parent = resolve_root(parent_spec, git_cache: git_cache)
      spec = Toys::SourceSpec.git(nil, path: git_directory_path, commit: git_commit)
      si = Toys::SourceInfo.resolve(spec, parent: parent, git_cache: git_cache)
      assert_equal(git_remote, si.origin.remote)
    end

    it "inherits the git commit when the spec does not give one" do
      parent_spec = Toys::SourceSpec.git(git_remote, path: git_path_with_data, commit: git_commit)
      parent = resolve_root(parent_spec, git_cache: git_cache)
      spec = Toys::SourceSpec.git(nil, path: git_directory_path)
      si = Toys::SourceInfo.resolve(spec, parent: parent, git_cache: git_cache)
      assert_equal(git_commit, si.origin.commit)
    end

    it "falls back to HEAD when neither the spec nor the parent gives a commit" do
      spec = Toys::SourceSpec.git(git_remote, path: git_directory_path)
      si = resolve_root(spec, git_cache: git_cache)
      assert_equal("HEAD", si.origin.commit)
    end

    it "errors when a git spec has no remote and no parent" do
      error = assert_raises(Toys::ToolSourceError) do
        resolve_root(Toys::SourceSpec.git(nil, path: git_directory_path), git_cache: git_cache)
      end
      assert_equal("Git remote not specified", error.message)
    end

    it "errors when a git spec has no remote and the parent has none either" do
      parent = resolve_root(Toys::SourceSpec.path(directory_path))
      error = assert_raises(Toys::ToolSourceError) do
        Toys::SourceInfo.resolve(Toys::SourceSpec.git(nil), parent: parent, git_cache: git_cache)
      end
      assert_equal("Git remote not specified", error.message)
    end
  end

  describe "origin identity" do
    it "shares the parent origin object with a relative child" do
      spec = Toys::SourceSpec.git(git_remote, path: git_directory_path, commit: git_commit)
      parent = resolve_root(spec, git_cache: git_cache)
      si = parent.relative_child(".toys.rb")
      assert_same(parent.origin, si.origin)
    end

    it "shares the parent origin object with a proc child" do
      spec = Toys::SourceSpec.gem(gem_name, path: "config-items/.toys.rb", toys_dir: gem_toys_dir)
      parent = resolve_root(spec, gems_util: gems_util)
      si = parent.proc_child(my_proc)
      assert_same(parent.origin, si.origin)
    end

    it "shares the parent origin object with a subclass child" do
      parent = resolve_root(Toys::SourceSpec.path(file_path))
      si = parent.subclass_child(my_class)
      assert_same(parent.origin, si.origin)
    end

    it "gives a resolved child its own origin rather than the parent one" do
      parent_spec = Toys::SourceSpec.git(git_remote, path: git_path_with_data, commit: git_commit)
      parent = resolve_root(parent_spec, git_cache: git_cache)
      spec = Toys::SourceSpec.git(git_remote, path: git_directory_path, commit: git_commit)
      si = Toys::SourceInfo.resolve(spec, parent: parent, git_cache: git_cache)
      refute_same(parent.origin, si.origin)
      assert_equal(git_path_with_data, parent.origin.path)
      assert_equal(git_directory_path, si.origin.path)
    end

    it "keeps the origin path fixed while the source path descends" do
      spec = Toys::SourceSpec.git(git_remote, path: git_directory_path, commit: git_commit)
      parent = resolve_root(spec, git_cache: git_cache)
      si = parent.relative_child(".toys.rb")
      assert_equal(git_directory_path, si.origin.path)
      assert_equal(file_path, si.source_path)
    end

    it "accumulates the relative path across multiple levels of children" do
      spec = Toys::SourceSpec.git(git_remote, path: git_path_with_data, commit: git_commit)
      parent = resolve_root(spec, git_cache: git_cache)
      si = parent.relative_child("ns-1").relative_child("ns-1a")
      child_git_path = File.join(git_path_with_data, "ns-1", "ns-1a")
      assert_git_origin(si, git_path_with_data)
      assert_equal(File.join(path_with_data, "ns-1", "ns-1a"), si.source_path)
      assert_equal("git(remote=#{git_remote} path=#{child_git_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "does not expose the derivation of the source path" do
      si = resolve_root(Toys::SourceSpec.path(directory_path))
      refute_respond_to(si, :relative_path)
      refute_respond_to(si, :initial_path)
    end

    it "no longer exposes the flattened git and gem readers" do
      si = resolve_root(Toys::SourceSpec.path(directory_path))
      [:git_remote, :git_path, :git_commit, :gem_name, :gem_version, :gem_path].each do |reader|
        refute_respond_to(si, reader)
      end
    end
  end

  describe "#relative_child" do
    it "creates a relative child of a file system root" do
      parent = resolve_root(Toys::SourceSpec.path(directory_path, context_directory: lookup_cases_dir))
      si = parent.relative_child(".toys.rb")
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(lookup_cases_dir, si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_local_origin(si)
      assert_equal(file_path, si.source_name)
    end

    it "creates a relative child of a git root" do
      spec = Toys::SourceSpec.git(git_remote, path: git_directory_path, commit: git_commit)
      parent = resolve_root(spec, git_cache: git_cache)
      si = parent.relative_child(".toys.rb")
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_git_origin(si, git_directory_path)
      assert_equal("git(remote=#{git_remote} path=#{git_file_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "creates a relative child of a git root covering the entire repository" do
      spec = Toys::SourceSpec.git(git_remote, commit: git_commit)
      parent = resolve_root(spec, git_cache: git_cache)
      assert_git_origin(parent, "")
      assert_equal("git(remote=#{git_remote} path= commit=#{git_commit})", parent.source_name)
      si = parent.relative_child("toys-core")
      assert_equal(:directory, si.source_type)
      assert_git_origin(si, "")
      assert_equal("git(remote=#{git_remote} path=toys-core commit=#{git_commit})",
                   si.source_name)
    end

    it "creates a relative child of a gem root" do
      spec = Toys::SourceSpec.gem(gem_name, path: "config-items", toys_dir: gem_toys_dir)
      parent = resolve_root(spec, gems_util: gems_util)
      si = parent.relative_child(".toys.rb")
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_gem_origin(si, gem_directory_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_file_path})",
                   si.source_name)
    end

    it "errors when attempting to create a relative child of a file" do
      parent = resolve_root(Toys::SourceSpec.path(file_path))
      assert_raises(::ArgumentError) do
        parent.relative_child(".toys.rb")
      end
    end

    it "errors when attempting to create a relative child of a proc" do
      parent = resolve_root(Toys::SourceSpec.block(source_name: custom_source_name, &my_proc))
      assert_raises(::ArgumentError) do
        parent.relative_child(".toys.rb")
      end
    end
  end

  describe "#proc_child" do
    it "creates a proc child of a file system root" do
      parent = resolve_root(Toys::SourceSpec.path(file_path, context_directory: directory_path))
      si = parent.proc_child(my_proc)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(directory_path, si.context_directory)
      assert_equal(my_proc, si.source)
      assert_equal(:proc, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_equal(my_proc, si.source_proc)
      assert_local_origin(si)
      assert_equal(file_path, si.source_name)
    end

    it "creates a proc child of a git root" do
      spec = Toys::SourceSpec.git(git_remote, path: git_file_path, commit: git_commit)
      parent = resolve_root(spec, git_cache: git_cache)
      si = parent.proc_child(my_proc)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_proc, si.source)
      assert_equal(:proc, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_equal(my_proc, si.source_proc)
      assert_git_origin(si, git_file_path)
      assert_equal("git(remote=#{git_remote} path=#{git_file_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "creates a proc child of a gem root" do
      spec = Toys::SourceSpec.gem(gem_name, path: "config-items/.toys.rb", toys_dir: gem_toys_dir)
      parent = resolve_root(spec, gems_util: gems_util)
      si = parent.proc_child(my_proc)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_proc, si.source)
      assert_equal(:proc, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_equal(my_proc, si.source_proc)
      assert_gem_origin(si, gem_file_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_file_path})",
                   si.source_name)
    end

    it "creates a proc child of a proc root" do
      parent = resolve_root(Toys::SourceSpec.block(source_name: custom_source_name, &my_proc))
      si = parent.proc_child(my_proc2)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_proc2, si.source)
      assert_equal(:proc, si.source_type)
      assert_nil(si.source_path)
      assert_equal(my_proc2, si.source_proc)
      assert_block_origin(si)
      assert_equal(custom_source_name, si.source_name)
    end
  end

  describe "#subclass_child" do
    it "creates a subclass child of a file system root" do
      parent = resolve_root(Toys::SourceSpec.path(file_path, context_directory: directory_path))
      si = parent.subclass_child(my_class)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(directory_path, si.context_directory)
      assert_equal(my_class, si.source)
      assert_equal(:subclass, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(my_class, si.source_subclass)
      assert_local_origin(si)
      assert_equal("#{file_path} (class MyToolClass)", si.source_name)
    end

    it "creates a subclass child of a git root" do
      spec = Toys::SourceSpec.git(git_remote, path: git_file_path, commit: git_commit)
      parent = resolve_root(spec, git_cache: git_cache)
      si = parent.subclass_child(my_class)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_class, si.source)
      assert_equal(:subclass, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(my_class, si.source_subclass)
      assert_git_origin(si, git_file_path)
      assert_equal("git(remote=#{git_remote} path=#{git_file_path} commit=#{git_commit}) " \
                   "(class MyToolClass)",
                   si.source_name)
    end

    it "creates a subclass child of a gem root" do
      spec = Toys::SourceSpec.gem(gem_name, path: "config-items/.toys.rb", toys_dir: gem_toys_dir)
      parent = resolve_root(spec, gems_util: gems_util)
      si = parent.subclass_child(my_class)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_class, si.source)
      assert_equal(:subclass, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(my_class, si.source_subclass)
      assert_gem_origin(si, gem_file_path)
      assert_equal("gem(name=#{gem_name} version=#{gem_version} path=#{gem_file_path}) " \
                   "(class MyToolClass)",
                   si.source_name)
    end

    it "creates a subclass child of a subclass source" do
      root = resolve_root(Toys::SourceSpec.path(file_path, context_directory: directory_path))
      parent = root.subclass_child(my_class)
      si = parent.subclass_child(my_class2)
      assert_equal(root, si.root)
      assert_equal(parent, si.parent)
      assert_equal(priority, si.priority)
      assert_equal(directory_path, si.context_directory)
      assert_equal(my_class2, si.source)
      assert_equal(:subclass, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_equal(my_class2, si.source_subclass)
      assert_equal("#{file_path} (class MyToolClass::MyNestedToolClass)", si.source_name)
    end

    it "honors an explicit source name" do
      parent = resolve_root(Toys::SourceSpec.path(file_path))
      si = parent.subclass_child(my_class, source_name: custom_source_name)
      assert_equal(custom_source_name, si.source_name)
    end

    it "errors when attempting to create a subclass child of a directory" do
      parent = resolve_root(Toys::SourceSpec.path(directory_path))
      assert_raises(::ArgumentError) do
        parent.subclass_child(my_class)
      end
    end

    it "errors when attempting to create a subclass child of a proc" do
      parent = resolve_root(Toys::SourceSpec.block(source_name: custom_source_name, &my_proc))
      assert_raises(::ArgumentError) do
        parent.subclass_child(my_class)
      end
    end
  end

  it "looks up data from a root" do
    si = resolve_root(Toys::SourceSpec.path(path_with_data))
    path = si.find_data("foo/root.txt")
    assert_equal(File.join(path_with_data, data_dir_name, "foo", "root.txt"), path)
  end

  describe "#index_child" do
    it "finds the index file in a directory" do
      si = resolve_root(Toys::SourceSpec.path(config_items_dir))
      child = si.index_child
      assert_equal(File.join(config_items_dir, ".toys.rb"), child.source_path)
      assert_equal(:file, child.source_type)
    end

    it "returns nil when the directory has no index file" do
      si = resolve_root(Toys::SourceSpec.path(File.join(lib_dirs_path, "ns")))
      assert_nil(si.index_child)
    end

    it "errors on a source that is not a directory" do
      si = resolve_root(Toys::SourceSpec.path(file_path))
      assert_raises(::ArgumentError) do
        si.index_child
      end
    end
  end

  describe "#find_lib_paths" do
    it "returns nothing for a directory with no lib directory" do
      si = resolve_root(Toys::SourceSpec.path(config_items_dir))
      assert_empty(si.find_lib_paths)
    end

    it "returns nothing for a file source" do
      si = resolve_root(Toys::SourceSpec.path(file_path))
      assert_empty(si.find_lib_paths)
    end

    it "finds the lib directory of a directory source" do
      si = resolve_root(Toys::SourceSpec.path(lib_dirs_path))
      assert_equal([File.join(lib_dirs_path, ".lib")], si.find_lib_paths)
    end

    it "orders a source ahead of its ancestors" do
      si = resolve_root(Toys::SourceSpec.path(lib_dirs_path)).relative_child("ns")
      assert_equal([File.join(lib_dirs_path, "ns", ".lib"), File.join(lib_dirs_path, ".lib")],
                   si.find_lib_paths)
    end
  end

  describe "#find_preload_files" do
    it "returns nothing for a directory with no preloads" do
      si = resolve_root(Toys::SourceSpec.path(config_items_dir))
      assert_empty(si.find_preload_files)
    end

    it "returns nothing for a file source" do
      si = resolve_root(Toys::SourceSpec.path(file_path))
      assert_empty(si.find_preload_files)
    end

    it "finds a standalone preload file" do
      si = resolve_root(Toys::SourceSpec.path(File.join(preloads_path, "ns-2")))
      assert_equal([File.join(preloads_path, "ns-2", ".preload.rb")], si.find_preload_files)
    end

    it "finds sorted ruby files in a preload directory" do
      si = resolve_root(Toys::SourceSpec.path(File.join(preloads_path, "ns-1", "ns-1a")))
      preload_dir = File.join(preloads_path, "ns-1", "ns-1a", ".preload")
      assert_equal([File.join(preload_dir, "preloaded1.rb"), File.join(preload_dir, "preloaded2.rb")],
                   si.find_preload_files)
    end

    it "does not include preloads from ancestors" do
      si = resolve_root(Toys::SourceSpec.path(File.join(preloads_path, "ns-1"))).relative_child("ns-1a")
      refute_includes(si.find_preload_files, File.join(preloads_path, "ns-1", ".preload.rb"))
    end
  end

  describe "resolution errors" do
    it "raises ToolSourceError for an unreadable path" do
      error = assert_raises(Toys::ToolSourceError) do
        Toys::SourceInfo.check_path(bad_path, false)
      end
      assert_equal("Cannot read: #{bad_path}", error.message)
    end

    it "raises ToolSourceError for a non-ruby file" do
      error = assert_raises(Toys::ToolSourceError) do
        Toys::SourceInfo.check_path(non_ruby_file, false)
      end
      assert_equal("File is not a ruby file: #{non_ruby_file}", error.message)
    end

    # No path is readable-but-neither-file-nor-directory on every platform.
    # File::NULL comes closest, but Windows expands it to the device path
    # "//./NUL", which Ruby 2.7 reports as a directory and which later Rubies
    # name differently in the message. Stub the two predicates so this checks
    # the branch itself rather than a platform quirk.
    it "raises ToolSourceError for a path that is neither a file nor a directory" do
      expanded = File.expand_path(File::NULL)
      error = File.stub(:file?, false) do
        File.stub(:directory?, false) do
          assert_raises(Toys::ToolSourceError) do
            Toys::SourceInfo.check_path(File::NULL, false)
          end
        end
      end
      assert_equal("Not a ruby file or directory: #{expanded}", error.message)
    end

    it "raises ToolSourceError when a gem cannot be activated" do
      failing_gems_util = Object.new
      failing_gems_util.define_singleton_method(:activate) do |*_args|
        raise Toys::Utils::Gems::ActivationFailedError, "activation went wrong"
      end
      error = assert_raises(Toys::ToolSourceError) do
        Toys::SourceInfo.resolve_gem_info(failing_gems_util, gem_name, [], nil, nil)
      end
      assert_equal("activation went wrong", error.message)
    end

    it "raises ToolSourceError when an activated gem cannot be found" do
      error = assert_raises(Toys::ToolSourceError) do
        Toys::SourceInfo.resolve_gem_info(gems_util, "nonexistent-gem", [], nil, nil)
      end
      assert_equal("Unable to find gem nonexistent-gem", error.message)
    end

    it "raises ToolSourceError when a git repo cannot be accessed" do
      failing_git_cache = Object.new
      failing_git_cache.define_singleton_method(:get) do |*_args, **_opts|
        raise Toys::Utils::GitCache::Error, "repo went wrong"
      end
      error = assert_raises(Toys::ToolSourceError) do
        Toys::SourceInfo.resolve_git_info(failing_git_cache, git_remote, nil, nil, false)
      end
      assert_equal("Unable to access git repo #{git_remote}: repo went wrong", error.message)
    end
  end
end
