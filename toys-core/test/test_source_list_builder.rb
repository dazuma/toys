# frozen_string_literal: true

require "helper"
require "fileutils"
require "tmpdir"

describe Toys::SourceListBuilder do
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

  # Stand-ins that fail loudly, to prove that copying a source list does not
  # reresolve anything.
  let(:unusable_git_cache) {
    cache = Object.new
    def cache.get(*_args, **_opts)
      raise "git_cache should not have been called"
    end
    cache
  }
  let(:unusable_gems_util) {
    util = Object.new
    def util.activate(*_args)
      raise "gems_util should not have been called"
    end
    util
  }

  let(:builder) { Toys::SourceListBuilder.new(git_cache: git_cache, gems_util: gems_util) }

  describe "#sources" do
    it "starts empty" do
      assert_empty(builder.sources)
    end

    it "returns a copy that does not affect the builder when modified" do
      builder.add_path(toys_file)
      sources = builder.sources
      sources.clear
      assert_equal(1, builder.sources.size)
    end

    it "preserves the order in which sources were added" do
      builder.add_path(toys_file)
      builder.add_path(toys_dir)
      builder.add_path(hierarchy_dir, high_priority: true)
      assert_equal([toys_file, toys_dir, hierarchy_dir], builder.sources.map(&:source_path))
    end
  end

  describe "priority" do
    it "descends for each source added at low priority" do
      builder.add_path(toys_file)
      builder.add_path(toys_dir)
      builder.add_path(hierarchy_dir)
      assert_equal([-1, -2, -3], builder.sources.map(&:priority))
    end

    it "ascends for each source added at high priority" do
      builder.add_path(toys_file, high_priority: true)
      builder.add_path(toys_dir, high_priority: true)
      builder.add_path(hierarchy_dir, high_priority: true)
      assert_equal([1, 2, 3], builder.sources.map(&:priority))
    end

    it "tracks the two ends independently" do
      builder.add_path(toys_file)
      builder.add_path(toys_dir, high_priority: true)
      builder.add_path(hierarchy_dir)
      assert_equal([-1, 1, -2], builder.sources.map(&:priority))
    end

    it "gives every member of a path set the same priority" do
      builder.add_path(hierarchy_dir)
      builder.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      assert_equal([-1, -2, -2], builder.sources.map(&:priority))
    end

    it "consumes a priority for an empty path set" do
      builder.add_path_set(config_items_dir, [])
      builder.add_path(toys_file)
      assert_equal([-2], builder.sources.map(&:priority))
    end

    it "does not consume a priority if a path is bad" do
      assert_raises(Toys::ToolDefinitionError) do
        builder.add_path(bad_path)
      end
      builder.add_path(toys_file)
      assert_equal([-1], builder.sources.map(&:priority))
    end

    it "does not consume a high priority if a path is bad" do
      assert_raises(Toys::ToolDefinitionError) do
        builder.add_path(bad_path, high_priority: true)
      end
      builder.add_path(toys_file, high_priority: true)
      assert_equal([1], builder.sources.map(&:priority))
    end

    it "does not consume a priority if a member of a path set is bad" do
      assert_raises(Toys::ToolDefinitionError) do
        builder.add_path_set(config_items_dir, [".toys", ".nonexistent"])
      end
      builder.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      assert_equal([-1, -1], builder.sources.map(&:priority))
    end

    it "does not consume a priority if a path set root is not a directory" do
      assert_raises(::ArgumentError) do
        builder.add_path_set(toys_file, [])
      end
      builder.add_path(toys_file)
      assert_equal([-1], builder.sources.map(&:priority))
    end
  end

  describe "#add_path" do
    it "adds a file source" do
      builder.add_path(toys_file)
      source = builder.sources.first
      assert_equal(:file, source.source_type)
      assert_equal(toys_file, source.source_path)
      assert_same(source, source.root)
    end

    it "adds a directory source" do
      builder.add_path(toys_dir)
      source = builder.sources.first
      assert_equal(:directory, source.source_type)
      assert_equal(toys_dir, source.source_path)
    end

    it "defaults the context directory to the parent of the path" do
      builder.add_path(toys_file)
      assert_equal(config_items_dir, builder.sources.first.context_directory)
    end

    it "can use the path itself as the context directory" do
      builder.add_path(toys_dir, context_directory: :path)
      assert_equal(toys_dir, builder.sources.first.context_directory)
    end

    it "can take an explicit context directory" do
      builder.add_path(toys_file, context_directory: cases_dir)
      assert_equal(cases_dir, builder.sources.first.context_directory)
    end

    it "can have no context directory" do
      builder.add_path(toys_file, context_directory: nil)
      assert_nil(builder.sources.first.context_directory)
    end

    it "defaults the source name to the path" do
      builder.add_path(toys_file)
      assert_equal(toys_file, builder.sources.first.source_name)
    end

    it "can take a custom source name" do
      builder.add_path(toys_file, source_name: "(my tools)")
      assert_equal("(my tools)", builder.sources.first.source_name)
    end

    it "raises if the path does not exist" do
      error = assert_raises(Toys::ToolDefinitionError) do
        builder.add_path(bad_path)
      end
      assert_equal("Cannot read: #{bad_path}", error.message)
    end

    it "raises if the path is not a ruby file" do
      error = assert_raises(Toys::ToolDefinitionError) do
        builder.add_path(non_ruby_file)
      end
      assert_equal("File is not a ruby file: #{non_ruby_file}", error.message)
    end

    it "returns self" do
      assert_same(builder, builder.add_path(toys_file))
    end
  end

  describe "#add_path_set" do
    it "adds each relative path as a source" do
      builder.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      assert_equal([toys_dir, toys_file], builder.sources.map(&:source_path))
    end

    it "gives every member the root as its ancestor" do
      builder.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      roots = builder.sources.map(&:root)
      assert_equal(1, roots.uniq.size)
      assert_equal(config_items_dir, roots.first.source_path)
    end

    it "accepts a single relative path as a string" do
      builder.add_path_set(config_items_dir, ".toys.rb")
      assert_equal([toys_file], builder.sources.map(&:source_path))
    end

    it "accepts an empty set" do
      builder.add_path_set(config_items_dir, [])
      assert_empty(builder.sources)
    end

    it "defaults the context directory to the root path" do
      builder.add_path_set(config_items_dir, [".toys.rb"])
      assert_equal(config_items_dir, builder.sources.first.context_directory)
    end

    it "names the synthetic root, which the members inherit" do
      builder.add_path_set(config_items_dir, [".toys.rb"], source_name: "(my tools)")
      assert_equal("(my tools)", builder.sources.first.root.source_name)
    end

    it "raises if the root path is not a directory" do
      error = assert_raises(::ArgumentError) do
        builder.add_path_set(toys_file, [])
      end
      assert_includes(error.message, "was not a directory")
    end

    it "raises if a member does not exist" do
      error = assert_raises(Toys::ToolDefinitionError) do
        builder.add_path_set(config_items_dir, [".toys", ".nonexistent"])
      end
      assert_equal("Cannot read: #{File.join(config_items_dir, '.nonexistent')}", error.message)
    end

    it "raises if a member is not a ruby file" do
      error = assert_raises(Toys::ToolDefinitionError) do
        builder.add_path_set(hierarchy_dir, ["hello.txt"])
      end
      assert_equal("File is not a ruby file: #{non_ruby_file}", error.message)
    end

    it "adds no sources at all if one member is bad" do
      assert_raises(Toys::ToolDefinitionError) do
        builder.add_path_set(config_items_dir, [".toys", ".nonexistent"])
      end
      assert_empty(builder.sources)
    end

    it "is unaffected by later mutation of the relative path array" do
      relative_paths = [".toys.rb"]
      builder.add_path_set(config_items_dir, relative_paths)
      relative_paths << ".toys"
      assert_equal([toys_file], builder.sources.map(&:source_path))
    end
  end

  describe "#add_block" do
    it "adds a proc source" do
      my_proc = proc { :hi }
      builder.add_block(&my_proc)
      source = builder.sources.first
      assert_equal(:proc, source.source_type)
      assert_same(my_proc, source.source_proc)
    end

    it "has no context directory by default" do
      builder.add_block { :hi }
      assert_nil(builder.sources.first.context_directory)
    end

    it "can take a context directory and a source name" do
      builder.add_block(context_directory: cases_dir, source_name: "(inline)") { :hi }
      source = builder.sources.first
      assert_equal(cases_dir, source.context_directory)
      assert_equal("(inline)", source.source_name)
    end

    it "returns self" do
      assert_same(builder, builder.add_block { :hi })
    end
  end

  describe "#add_git" do
    it "resolves the source path through the git cache" do
      builder.add_git(git_remote, git_path: "toys-core/test-data/lookup-cases/config-items")
      assert_equal(config_items_dir, builder.sources.first.source_path)
    end

    it "records the git coordinates on the source" do
      builder.add_git(git_remote,
                      git_path: "toys-core/test-data/lookup-cases/config-items/.toys.rb",
                      git_commit: "v1.2.3")
      source = builder.sources.first
      assert_equal(git_remote, source.git_remote)
      assert_equal("toys-core/test-data/lookup-cases/config-items/.toys.rb", source.git_path)
      assert_equal("v1.2.3", source.git_commit)
    end

    it "defaults to the whole repo at HEAD, without updating" do
      builder.add_git(git_remote, git_path: "toys-core/test-data/lookup-cases")
      assert_equal("HEAD", builder.sources.first.git_commit)
      assert_equal([{remote: git_remote, path: "toys-core/test-data/lookup-cases",
                     commit: "HEAD", update: false}],
                   git_cache_calls)
    end

    it "passes the update setting through to the git cache" do
      builder.add_git(git_remote, git_path: "toys-core/test-data/lookup-cases", update: true)
      assert_equal(true, git_cache_calls.first[:update])
    end

    it "returns self" do
      result = builder.add_git(git_remote, git_path: "toys-core/test-data/lookup-cases")
      assert_same(builder, result)
    end
  end

  describe "#add_gem" do
    it "activates the gem and resolves its toys directory" do
      builder.add_gem("toys-core", gem_toys_dir: gem_toys_dir, gem_path: "config-items")
      assert_equal([{name: "toys-core", versions: []}], gems_util_calls)
      assert_equal(config_items_dir, builder.sources.first.source_path)
    end

    it "passes version requirements to the gems utility" do
      builder.add_gem("toys-core", gem_version: [">= 1.0", "< 99"], gem_toys_dir: gem_toys_dir)
      assert_equal([{name: "toys-core", versions: [">= 1.0", "< 99"]}], gems_util_calls)
    end

    it "records the gem coordinates on the source" do
      builder.add_gem("toys-core", gem_toys_dir: gem_toys_dir, gem_path: "config-items/.toys.rb")
      source = builder.sources.first
      assert_equal("toys-core", source.gem_name)
      assert_equal(Gem.loaded_specs["toys-core"].version, source.gem_version)
      assert_equal("test-data/lookup-cases/config-items/.toys.rb", source.gem_path)
    end

    it "uses the whole toys directory when no gem path is given" do
      builder.add_gem("toys-core", gem_toys_dir: gem_toys_dir)
      source = builder.sources.first
      assert_equal(gem_toys_dir, source.gem_path)
      assert_equal(cases_dir, source.source_path)
    end

    it "returns self" do
      assert_same(builder, builder.add_gem("toys-core", gem_toys_dir: gem_toys_dir))
    end
  end

  describe "copying a source list" do
    # Copies with resolvers that would raise, proving that already-resolved
    # sources are carried over rather than resolved a second time.
    def copy_of(original)
      Toys::SourceListBuilder.new(sources: original.sources,
                                  git_cache: unusable_git_cache,
                                  gems_util: unusable_gems_util)
    end

    it "carries over path sources" do
      builder.add_path(toys_dir)
      builder.add_path(toys_file)
      assert_equal([toys_dir, toys_file], copy_of(builder).sources.map(&:source_path))
    end

    it "carries over block sources" do
      builder.add_block(source_name: "test block") { :hi }
      copy = copy_of(builder)
      assert_equal(:proc, copy.sources.first.source_type)
      assert_equal("test block", copy.sources.first.source_name)
    end

    it "carries over path set sources with their shared root" do
      builder.add_path_set(config_items_dir, [".toys", ".toys.rb"])
      copy = copy_of(builder)
      assert_equal([toys_dir, toys_file], copy.sources.map(&:source_path))
      assert_equal(1, copy.sources.map(&:root).uniq.size)
    end

    it "carries over a path set member that has since been deleted" do
      Dir.mktmpdir do |root_path|
        FileUtils.mkdir(File.join(root_path, ".toys"))
        builder.add_path_set(root_path, [".toys"])
        FileUtils.rm_rf(File.join(root_path, ".toys"))
        assert_equal([File.join(root_path, ".toys")], copy_of(builder).sources.map(&:source_path))
      end
    end

    it "carries over git sources without refetching the repo" do
      builder.add_git(git_remote, git_path: "toys-core/test-data/lookup-cases/config-items")
      copy = copy_of(builder)
      assert_equal(config_items_dir, copy.sources.first.source_path)
      assert_equal(git_remote, copy.sources.first.git_remote)
    end

    it "carries over gem sources without reactivating the gem" do
      builder.add_gem("toys-core", gem_toys_dir: gem_toys_dir, gem_path: "config-items")
      copy = copy_of(builder)
      assert_equal(config_items_dir, copy.sources.first.source_path)
      assert_equal("toys-core", copy.sources.first.gem_name)
    end

    it "preserves the priorities of the copied sources" do
      builder.add_path(toys_file)
      builder.add_path(toys_dir)
      builder.add_path(hierarchy_dir, high_priority: true)
      assert_equal([-1, -2, 1], copy_of(builder).sources.map(&:priority))
    end

    it "continues the priority sequence at both ends" do
      builder.add_path(toys_file)
      builder.add_path(hierarchy_dir, high_priority: true)
      copy = copy_of(builder)
      copy.add_path(toys_dir)
      copy.add_path(toys_dir, high_priority: true)
      assert_equal([-1, 1, -2, 2], copy.sources.map(&:priority))
    end

    it "does not modify the original builder" do
      builder.add_path(toys_file)
      copy = copy_of(builder)
      copy.add_path(hierarchy_dir, high_priority: true)
      assert_equal([toys_file], builder.sources.map(&:source_path))
    end

    it "accepts an empty source list" do
      copy = copy_of(builder)
      assert_empty(copy.sources)
      copy.add_path(toys_file)
      assert_equal([-1], copy.sources.map(&:priority))
    end

    it "can be copied again" do
      builder.add_path(toys_file)
      assert_equal([toys_file], copy_of(copy_of(builder)).sources.map(&:source_path))
    end
  end
end
