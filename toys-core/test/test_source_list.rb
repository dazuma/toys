# frozen_string_literal: true

require "helper"
require "fileutils"
require "tmpdir"

describe Toys::SourceList do
  let(:cases_dir) { File.join(File.dirname(__dir__), "test-data", "lookup-cases") }
  let(:config_items_dir) { File.join(cases_dir, "config-items") }
  let(:toys_dir) { File.join(config_items_dir, ".toys") }
  let(:toys_file) { File.join(config_items_dir, ".toys.rb") }
  let(:hierarchy_dir) { File.join(cases_dir, "normal-file-hierarchy") }
  let(:bad_path) { File.join(cases_dir, "doesnotexist") }
  let(:non_ruby_file) { File.join(hierarchy_dir, "hello.txt") }

  let(:git_remote) { "https://github.com/dazuma/toys.git" }
  let(:gem_toys_dir) { "test-data/lookup-cases" }

  # Records the arguments it is asked to resolve, and answers with a path in
  # this repo, so git sources resolve without touching the network.
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

  # Records activations. The gem fixtures use toys-core itself, whose gem
  # directory is this source tree, so it is already loaded and need not be
  # actually activated.
  let(:gems_util_calls) { [] }
  let(:gems_util) {
    calls = gems_util_calls
    util = Object.new
    util.define_singleton_method(:activate) do |name, *versions|
      calls << {name: name, versions: versions}
    end
    util
  }

  let(:list) { Toys::SourceList.new(git_cache: git_cache, gems_util: gems_util) }

  describe "enumeration" do
    it "starts empty" do
      assert_empty(list.to_a)
      assert(list.empty?)
      assert_equal(0, list.size)
    end

    it "reports its size as sources are added" do
      list.add_path(toys_file)
      refute(list.empty?)
      assert_equal(1, list.size)
      list.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      assert_equal(3, list.size)
    end

    it "preserves the order in which sources were added" do
      list.add_path(toys_file)
      list.add_path(toys_dir)
      list.add_path(hierarchy_dir, high_priority: true)
      assert_equal([toys_file, toys_dir, hierarchy_dir], list.to_a.map(&:source_path))
    end

    it "yields each source to a block and returns self" do
      list.add_path(toys_file)
      list.add_path(toys_dir)
      yielded = []
      result = list.each { |source| yielded << source.source_path }
      assert_equal([toys_file, toys_dir], yielded)
      assert_same(list, result)
    end

    it "does not expose the underlying array" do
      list.add_path(toys_file)
      refute_same(list.to_a, list.to_a)
      list.to_a.clear
      assert_equal(1, list.size)
      assert_same(list, list.each { |source| source })
    end

    it "returns an enumerator when given no block" do
      list.add_path(toys_file)
      enum = list.each
      assert_instance_of(::Enumerator, enum)
      assert_equal([toys_file], enum.map(&:source_path))
      assert_same(list, enum.each { |source| source })
    end

    it "supports Enumerable methods" do
      list.add_path(toys_file)
      list.add_path(toys_dir)
      assert_kind_of(::Enumerable, list)
      assert_equal(2, list.count)
      dirs = list.select { |source| source.source_type == :directory }
      assert_equal([toys_dir], dirs.map(&:source_path))
    end
  end

  describe "resolvers" do
    it "exposes the ones it was constructed with" do
      assert_same(git_cache, list.git_cache)
      assert_same(gems_util, list.gems_util)
    end

    it "defaults both to nil, meaning the process-wide defaults" do
      plain = Toys::SourceList.new
      assert_nil(plain.git_cache)
      assert_nil(plain.gems_util)
    end
  end

  describe "the root-per-priority invariant" do
    # The Loader relies on this: it maps priority to root without checking for
    # collisions. Derive it from the list rather than asserting a fixed shape,
    # so that new ways of adding sources are covered automatically.
    def assert_one_root_per_priority(source_list)
      by_priority = source_list.group_by(&:priority)
      refute_empty(by_priority)
      # Guard against passing vacuously: at least one priority must actually be
      # shared, or there is no collision for the invariant to rule out.
      assert(by_priority.any? { |_priority, sources| sources.size > 1 },
             "no priority is shared by more than one source, so nothing is proven")
      by_priority.each do |priority, sources|
        roots = sources.map(&:root).uniq
        assert_equal(1, roots.size, "priority #{priority} has #{roots.size} distinct roots")
      end
    end

    it "holds across every kind of source" do
      list.add_path(toys_file)
      list.add_path(toys_dir, high_priority: true)
      list.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      list.add_block { :hi }
      list.add_git(git_remote, git_path: "toys-core/test-data/lookup-cases/config-items")
      list.add_gem("toys-core", gem_toys_dir: gem_toys_dir, gem_path: "config-items")
      assert_one_root_per_priority(list)
    end

    it "holds after copying and adding more" do
      list.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      copy = list.dup
      copy.add_path_set(config_items_dir, [".toys"], high_priority: true)
      copy.add_path(toys_file)
      assert_one_root_per_priority(copy)
    end
  end

  describe "priority" do
    it "descends for each source added at low priority" do
      list.add_path(toys_file)
      list.add_path(toys_dir)
      list.add_path(hierarchy_dir)
      assert_equal([-1, -2, -3], list.to_a.map(&:priority))
    end

    it "ascends for each source added at high priority" do
      list.add_path(toys_file, high_priority: true)
      list.add_path(toys_dir, high_priority: true)
      list.add_path(hierarchy_dir, high_priority: true)
      assert_equal([1, 2, 3], list.to_a.map(&:priority))
    end

    it "tracks the two ends independently" do
      list.add_path(toys_file)
      list.add_path(toys_dir, high_priority: true)
      list.add_path(hierarchy_dir)
      assert_equal([-1, 1, -2], list.to_a.map(&:priority))
    end

    it "gives every member of a path set the same priority" do
      list.add_path(hierarchy_dir)
      list.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      assert_equal([-1, -2, -2], list.to_a.map(&:priority))
    end

    it "consumes a priority for an empty path set" do
      list.add_path_set(config_items_dir, [])
      list.add_path(toys_file)
      assert_equal([-2], list.to_a.map(&:priority))
    end

    it "does not consume a priority if a path is bad" do
      assert_raises(Toys::ToolDefinitionError) do
        list.add_path(bad_path)
      end
      list.add_path(toys_file)
      assert_equal([-1], list.to_a.map(&:priority))
    end

    it "does not consume a high priority if a path is bad" do
      assert_raises(Toys::ToolDefinitionError) do
        list.add_path(bad_path, high_priority: true)
      end
      list.add_path(toys_file, high_priority: true)
      assert_equal([1], list.to_a.map(&:priority))
    end

    it "does not consume a priority if a member of a path set is bad" do
      assert_raises(Toys::ToolDefinitionError) do
        list.add_path_set(config_items_dir, [".toys", ".nonexistent"])
      end
      list.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      assert_equal([-1, -1], list.to_a.map(&:priority))
    end

    it "does not consume a priority if a path set root is not a directory" do
      assert_raises(::ArgumentError) do
        list.add_path_set(toys_file, [])
      end
      list.add_path(toys_file)
      assert_equal([-1], list.to_a.map(&:priority))
    end
  end

  describe "#add_path" do
    it "adds a file source" do
      list.add_path(toys_file)
      source = list.to_a.first
      assert_equal(:file, source.source_type)
      assert_equal(toys_file, source.source_path)
      assert_same(source, source.root)
    end

    it "adds a directory source" do
      list.add_path(toys_dir)
      source = list.to_a.first
      assert_equal(:directory, source.source_type)
      assert_equal(toys_dir, source.source_path)
    end

    it "defaults the context directory to the parent of the path" do
      list.add_path(toys_file)
      assert_equal(config_items_dir, list.to_a.first.context_directory)
    end

    it "can use the path itself as the context directory" do
      list.add_path(toys_dir, context_directory: :path)
      assert_equal(toys_dir, list.to_a.first.context_directory)
    end

    it "can take an explicit context directory" do
      list.add_path(toys_file, context_directory: cases_dir)
      assert_equal(cases_dir, list.to_a.first.context_directory)
    end

    it "can have no context directory" do
      list.add_path(toys_file, context_directory: nil)
      assert_nil(list.to_a.first.context_directory)
    end

    it "defaults the source name to the path" do
      list.add_path(toys_file)
      assert_equal(toys_file, list.to_a.first.source_name)
    end

    it "can take a custom source name" do
      list.add_path(toys_file, source_name: "(my tools)")
      assert_equal("(my tools)", list.to_a.first.source_name)
    end

    it "raises if the path does not exist" do
      error = assert_raises(Toys::ToolDefinitionError) do
        list.add_path(bad_path)
      end
      assert_equal("Cannot read: #{bad_path}", error.message)
    end

    it "raises if the path is not a ruby file" do
      error = assert_raises(Toys::ToolDefinitionError) do
        list.add_path(non_ruby_file)
      end
      assert_equal("File is not a ruby file: #{non_ruby_file}", error.message)
    end

    it "returns self" do
      assert_same(list, list.add_path(toys_file))
    end
  end

  describe "#add_path_set" do
    it "adds each relative path as a source" do
      list.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      assert_equal([toys_dir, toys_file], list.to_a.map(&:source_path))
    end

    it "gives every member the root as its ancestor" do
      list.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      roots = list.to_a.map(&:root)
      assert_equal(1, roots.uniq.size)
      assert_equal(config_items_dir, roots.first.source_path)
    end

    it "accepts a single relative path as a string" do
      list.add_path_set(config_items_dir, ".toys.rb")
      assert_equal([toys_file], list.to_a.map(&:source_path))
    end

    it "accepts an empty set" do
      list.add_path_set(config_items_dir, [])
      assert_empty(list.to_a)
    end

    it "defaults the context directory to the root path" do
      list.add_path_set(config_items_dir, [".toys.rb"])
      assert_equal(config_items_dir, list.to_a.first.context_directory)
    end

    it "names the synthetic root, which the members inherit" do
      list.add_path_set(config_items_dir, [".toys.rb"], source_name: "(my tools)")
      assert_equal("(my tools)", list.to_a.first.root.source_name)
    end

    it "raises if the root path is not a directory" do
      error = assert_raises(::ArgumentError) do
        list.add_path_set(toys_file, [])
      end
      assert_includes(error.message, "was not a directory")
    end

    it "raises if a member does not exist" do
      error = assert_raises(Toys::ToolDefinitionError) do
        list.add_path_set(config_items_dir, [".toys", ".nonexistent"])
      end
      assert_equal("Cannot read: #{File.join(config_items_dir, '.nonexistent')}", error.message)
    end

    it "raises if a member is not a ruby file" do
      error = assert_raises(Toys::ToolDefinitionError) do
        list.add_path_set(hierarchy_dir, ["hello.txt"])
      end
      assert_equal("File is not a ruby file: #{non_ruby_file}", error.message)
    end

    it "adds no sources at all if one member is bad" do
      assert_raises(Toys::ToolDefinitionError) do
        list.add_path_set(config_items_dir, [".toys", ".nonexistent"])
      end
      assert_empty(list.to_a)
    end

    it "is unaffected by later mutation of the relative path array" do
      relative_paths = [".toys.rb"]
      list.add_path_set(config_items_dir, relative_paths)
      relative_paths << ".toys"
      assert_equal([toys_file], list.to_a.map(&:source_path))
    end
  end

  describe "#add_block" do
    it "adds a proc source" do
      my_proc = proc { :hi }
      list.add_block(&my_proc)
      source = list.to_a.first
      assert_equal(:proc, source.source_type)
      assert_same(my_proc, source.source_proc)
    end

    it "has no context directory by default" do
      list.add_block { :hi }
      assert_nil(list.to_a.first.context_directory)
    end

    it "can take a context directory and a source name" do
      list.add_block(context_directory: cases_dir, source_name: "(inline)") { :hi }
      source = list.to_a.first
      assert_equal(cases_dir, source.context_directory)
      assert_equal("(inline)", source.source_name)
    end

    it "returns self" do
      assert_same(list, list.add_block { :hi })
    end
  end

  describe "#add_git" do
    it "resolves the source path through the git cache" do
      list.add_git(git_remote, git_path: "toys-core/test-data/lookup-cases/config-items")
      assert_equal(config_items_dir, list.to_a.first.source_path)
    end

    it "records the git coordinates on the source" do
      list.add_git(git_remote,
                   git_path: "toys-core/test-data/lookup-cases/config-items/.toys.rb",
                   git_commit: "v1.2.3")
      source = list.to_a.first
      assert_equal(git_remote, source.git_remote)
      assert_equal("toys-core/test-data/lookup-cases/config-items/.toys.rb", source.git_path)
      assert_equal("v1.2.3", source.git_commit)
    end

    it "defaults to the whole repo at HEAD, without updating" do
      list.add_git(git_remote, git_path: "toys-core/test-data/lookup-cases")
      assert_equal("HEAD", list.to_a.first.git_commit)
      assert_equal([{remote: git_remote, path: "toys-core/test-data/lookup-cases",
                     commit: "HEAD", update: false}],
                   git_cache_calls)
    end

    it "passes the update setting through to the git cache" do
      list.add_git(git_remote, git_path: "toys-core/test-data/lookup-cases", update: true)
      assert_equal(true, git_cache_calls.first[:update])
    end

    it "returns self" do
      result = list.add_git(git_remote, git_path: "toys-core/test-data/lookup-cases")
      assert_same(list, result)
    end
  end

  describe "#add_gem" do
    it "activates the gem and resolves its toys directory" do
      list.add_gem("toys-core", gem_toys_dir: gem_toys_dir, gem_path: "config-items")
      assert_equal([{name: "toys-core", versions: []}], gems_util_calls)
      assert_equal(config_items_dir, list.to_a.first.source_path)
    end

    it "passes version requirements to the gems utility" do
      list.add_gem("toys-core", gem_version: [">= 1.0", "< 99"], gem_toys_dir: gem_toys_dir)
      assert_equal([{name: "toys-core", versions: [">= 1.0", "< 99"]}], gems_util_calls)
    end

    it "records the gem coordinates on the source" do
      list.add_gem("toys-core", gem_toys_dir: gem_toys_dir, gem_path: "config-items/.toys.rb")
      source = list.to_a.first
      assert_equal("toys-core", source.gem_name)
      assert_equal(Gem.loaded_specs["toys-core"].version, source.gem_version)
      assert_equal("test-data/lookup-cases/config-items/.toys.rb", source.gem_path)
    end

    it "uses the whole toys directory when no gem path is given" do
      list.add_gem("toys-core", gem_toys_dir: gem_toys_dir)
      source = list.to_a.first
      assert_equal(gem_toys_dir, source.gem_path)
      assert_equal(cases_dir, source.source_path)
    end

    it "returns self" do
      assert_same(list, list.add_gem("toys-core", gem_toys_dir: gem_toys_dir))
    end
  end

  describe "copying a source list" do
    # Copying carries already-resolved sources over rather than resolving them
    # a second time, so the resolver call logs must not grow.
    def copy_of(original)
      git_calls_before = git_cache_calls.size
      gem_calls_before = gems_util_calls.size
      copy = original.dup
      assert_equal(git_calls_before, git_cache_calls.size, "copying refetched a git source")
      assert_equal(gem_calls_before, gems_util_calls.size, "copying reactivated a gem")
      copy
    end

    it "carries over path sources" do
      list.add_path(toys_dir)
      list.add_path(toys_file)
      assert_equal([toys_dir, toys_file], copy_of(list).to_a.map(&:source_path))
    end

    it "carries over block sources" do
      list.add_block(source_name: "test block") { :hi }
      copy = copy_of(list)
      assert_equal(:proc, copy.to_a.first.source_type)
      assert_equal("test block", copy.to_a.first.source_name)
    end

    it "carries over path set sources with their shared root" do
      list.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      copy = copy_of(list)
      assert_equal([toys_dir, toys_file], copy.to_a.map(&:source_path))
      assert_equal(1, copy.to_a.map(&:root).uniq.size)
    end

    it "carries over a path set member that has since been deleted" do
      Dir.mktmpdir do |root_path|
        FileUtils.mkdir(File.join(root_path, ".toys"))
        list.add_path_set(root_path, [".toys"])
        FileUtils.rm_rf(File.join(root_path, ".toys"))
        assert_equal([File.join(root_path, ".toys")], copy_of(list).to_a.map(&:source_path))
      end
    end

    it "carries over git sources without refetching the repo" do
      list.add_git(git_remote, git_path: "toys-core/test-data/lookup-cases/config-items")
      copy = copy_of(list)
      assert_equal(config_items_dir, copy.to_a.first.source_path)
      assert_equal(git_remote, copy.to_a.first.git_remote)
    end

    it "carries over gem sources without reactivating the gem" do
      list.add_gem("toys-core", gem_toys_dir: gem_toys_dir, gem_path: "config-items")
      copy = copy_of(list)
      assert_equal(config_items_dir, copy.to_a.first.source_path)
      assert_equal("toys-core", copy.to_a.first.gem_name)
    end

    it "carries over the resolvers" do
      copy = copy_of(list)
      assert_same(git_cache, copy.git_cache)
      assert_same(gems_util, copy.gems_util)
    end

    it "preserves the priorities of the copied sources" do
      list.add_path(toys_file)
      list.add_path(toys_dir)
      list.add_path(hierarchy_dir, high_priority: true)
      assert_equal([-1, -2, 1], copy_of(list).to_a.map(&:priority))
    end

    it "continues the priority sequence at both ends" do
      list.add_path(toys_file)
      list.add_path(hierarchy_dir, high_priority: true)
      copy = copy_of(list)
      copy.add_path(toys_dir)
      copy.add_path(toys_dir, high_priority: true)
      assert_equal([-1, 1, -2, 2], copy.to_a.map(&:priority))
    end

    it "does not modify the original list" do
      list.add_path(toys_file)
      copy = copy_of(list)
      copy.add_path(hierarchy_dir, high_priority: true)
      assert_equal([toys_file], list.to_a.map(&:source_path))
    end

    it "is not modified by later additions to the original list" do
      list.add_path(toys_file)
      copy = copy_of(list)
      list.add_path(hierarchy_dir, high_priority: true)
      assert_equal([toys_file], copy.to_a.map(&:source_path))
    end

    it "accepts an empty source list" do
      copy = copy_of(list)
      assert_empty(copy.to_a)
      copy.add_path(toys_file)
      assert_equal([-1], copy.to_a.map(&:priority))
    end

    it "can be copied again" do
      list.add_path(toys_file)
      assert_equal([toys_file], copy_of(copy_of(list)).to_a.map(&:source_path))
    end

    it "can be copied with clone" do
      list.add_path(toys_file)
      copy = list.clone
      copy.add_path(toys_dir)
      assert_equal([toys_file, toys_dir], copy.to_a.map(&:source_path))
      assert_equal([toys_file], list.to_a.map(&:source_path))
    end
  end
end
