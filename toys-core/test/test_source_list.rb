# frozen_string_literal: true

require "helper"

describe Toys::SourceList do
  let(:cases_dir) { File.join(File.dirname(__dir__), "test-data", "lookup-cases") }
  let(:config_items_dir) { File.join(cases_dir, "config-items") }
  let(:toys_dir) { File.join(config_items_dir, ".toys") }
  let(:toys_file) { File.join(config_items_dir, ".toys.rb") }
  let(:hierarchy_dir) { File.join(cases_dir, "normal-file-hierarchy") }
  let(:bad_path) { File.join(cases_dir, "doesnotexist") }

  let(:git_remote) { "https://github.com/dazuma/toys.git" }
  let(:gem_toys_dir) { "test-data/lookup-cases" }

  let(:list) { Toys::SourceList.new }

  # The specs a list holds, in the order they were added.
  def specs_of(source_list)
    source_list.each_with_priority.map { |spec, _priority| spec }
  end

  # The priorities a list assigned, in the order the specs were added.
  def priorities_of(source_list)
    source_list.each_with_priority.map { |_spec, priority| priority }
  end

  describe "enumeration" do
    it "starts empty" do
      assert_empty(specs_of(list))
      assert(list.empty?)
      assert_equal(0, list.size)
    end

    it "reports its size as sources are added" do
      list.add(Toys::SourceSpec.path(toys_file))
      refute(list.empty?)
      assert_equal(1, list.size)
      list.add(Toys::SourceSpec.path(config_items_dir, relative_paths: [".toys", ".toys.rb"]))
      assert_equal(2, list.size)
    end

    it "counts a path set as one source, however many members it has" do
      list.add(Toys::SourceSpec.path(config_items_dir, relative_paths: []))
      assert_equal(1, list.size)
      refute(list.empty?)
    end

    it "preserves the order in which sources were added" do
      list.add(Toys::SourceSpec.path(toys_file))
      list.add(Toys::SourceSpec.path(toys_dir))
      list.add(Toys::SourceSpec.path(hierarchy_dir), high_priority: true)
      assert_equal([toys_file, toys_dir, hierarchy_dir], specs_of(list).map(&:path))
    end

    it "yields each spec and priority to a block and returns self" do
      list.add(Toys::SourceSpec.path(toys_file))
      list.add(Toys::SourceSpec.path(toys_dir))
      yielded = []
      result = list.each_with_priority { |spec, priority| yielded << [spec.path, priority] }
      assert_equal([[toys_file, -1], [toys_dir, -2]], yielded)
      assert_same(list, result)
    end

    it "returns an enumerator when given no block" do
      list.add(Toys::SourceSpec.path(toys_file))
      enum = list.each_with_priority
      assert_instance_of(::Enumerator, enum)
      assert_equal([[toys_file, -1]], enum.map { |spec, priority| [spec.path, priority] })
      assert_same(list, enum.each { |spec, priority| [spec, priority] })
    end

    it "does not expose the underlying array" do
      list.add(Toys::SourceSpec.path(toys_file))
      specs_of(list).clear
      assert_equal(1, list.size)
    end
  end

  describe "priority" do
    it "descends for each source added at low priority" do
      list.add(Toys::SourceSpec.path(toys_file))
      list.add(Toys::SourceSpec.path(toys_dir))
      list.add(Toys::SourceSpec.path(hierarchy_dir))
      assert_equal([-1, -2, -3], priorities_of(list))
    end

    it "ascends for each source added at high priority" do
      list.add(Toys::SourceSpec.path(toys_file), high_priority: true)
      list.add(Toys::SourceSpec.path(toys_dir), high_priority: true)
      list.add(Toys::SourceSpec.path(hierarchy_dir), high_priority: true)
      assert_equal([1, 2, 3], priorities_of(list))
    end

    it "tracks the two ends independently" do
      list.add(Toys::SourceSpec.path(toys_file))
      list.add(Toys::SourceSpec.path(toys_dir), high_priority: true)
      list.add(Toys::SourceSpec.path(hierarchy_dir))
      assert_equal([-1, 1, -2], priorities_of(list))
    end

    it "gives a path set a single priority, whatever its member count" do
      list.add(Toys::SourceSpec.path(hierarchy_dir))
      list.add(Toys::SourceSpec.path(config_items_dir, relative_paths: [".toys", ".toys.rb"]))
      list.add(Toys::SourceSpec.path(toys_file))
      assert_equal([-1, -2, -3], priorities_of(list))
    end

    it "assigns a distinct priority to every spec" do
      list.add(Toys::SourceSpec.path(toys_file))
      list.add(Toys::SourceSpec.path(toys_dir), high_priority: true)
      list.add(Toys::SourceSpec.path(config_items_dir, relative_paths: [".toys"]))
      list.add(Toys::SourceSpec.block { :hi })
      list.add(Toys::SourceSpec.git(git_remote))
      list.add(Toys::SourceSpec.gem("toys-core", toys_dir: gem_toys_dir))
      priorities = priorities_of(list)
      assert_equal(priorities.size, priorities.uniq.size)
    end

    it "consumes a priority even for a source that will fail to resolve" do
      list.add(Toys::SourceSpec.path(bad_path))
      list.add(Toys::SourceSpec.path(toys_file))
      assert_equal([-1, -2], priorities_of(list))
    end
  end

  describe "#add" do
    it "holds the spec it was given, unresolved" do
      spec = Toys::SourceSpec.path(toys_file)
      list.add(spec)
      assert_same(spec, specs_of(list).first)
    end

    it "holds a spec whose path does not exist" do
      spec = Toys::SourceSpec.path(bad_path)
      list.add(spec)
      assert_same(spec, specs_of(list).first)
    end

    it "holds specs of every kind" do
      list.add(Toys::SourceSpec.path(toys_file))
      list.add(Toys::SourceSpec.block { :hi })
      list.add(Toys::SourceSpec.git(git_remote))
      list.add(Toys::SourceSpec.gem("toys-core"))
      assert_equal([Toys::SourceSpec::Path, Toys::SourceSpec::Block,
                    Toys::SourceSpec::Git, Toys::SourceSpec::Gem],
                   specs_of(list).map(&:class))
    end

    it "rejects an object that is not a source spec" do
      error = assert_raises(ArgumentError) { list.add("not a spec") }
      assert_equal("Illegal source spec: \"not a spec\"", error.message)
    end

    it "rejects nil" do
      assert_raises(ArgumentError) { list.add(nil) }
    end

    it "consumes no priority when a spec is rejected" do
      assert_raises(ArgumentError) { list.add(:nonsense) }
      list.add(Toys::SourceSpec.path(toys_file))
      assert_equal([-1], priorities_of(list))
    end

    it "returns self" do
      assert_same(list, list.add(Toys::SourceSpec.path(toys_file)))
    end
  end

  describe "copying a source list" do
    it "carries over the specs" do
      list.add(Toys::SourceSpec.path(toys_dir))
      list.add(Toys::SourceSpec.path(toys_file))
      assert_equal(specs_of(list), specs_of(list.dup))
    end

    it "carries over specs of every kind" do
      list.add(Toys::SourceSpec.block(source_name: "test block") { :hi })
      list.add(Toys::SourceSpec.git(git_remote, path: "toys-core"))
      list.add(Toys::SourceSpec.gem("toys-core", toys_dir: gem_toys_dir))
      assert_equal(specs_of(list), specs_of(list.dup))
    end

    it "preserves the priorities of the copied sources" do
      list.add(Toys::SourceSpec.path(toys_file))
      list.add(Toys::SourceSpec.path(toys_dir))
      list.add(Toys::SourceSpec.path(hierarchy_dir), high_priority: true)
      assert_equal([-1, -2, 1], priorities_of(list.dup))
    end

    it "continues the priority sequence at both ends" do
      list.add(Toys::SourceSpec.path(toys_file))
      list.add(Toys::SourceSpec.path(hierarchy_dir), high_priority: true)
      copy = list.dup
      copy.add(Toys::SourceSpec.path(toys_dir))
      copy.add(Toys::SourceSpec.path(toys_dir), high_priority: true)
      assert_equal([-1, 1, -2, 2], priorities_of(copy))
    end

    it "does not modify the original list" do
      list.add(Toys::SourceSpec.path(toys_file))
      copy = list.dup
      copy.add(Toys::SourceSpec.path(hierarchy_dir), high_priority: true)
      assert_equal([toys_file], specs_of(list).map(&:path))
    end

    it "is not modified by later additions to the original list" do
      list.add(Toys::SourceSpec.path(toys_file))
      copy = list.dup
      list.add(Toys::SourceSpec.path(hierarchy_dir), high_priority: true)
      assert_equal([toys_file], specs_of(copy).map(&:path))
    end

    it "accepts an empty source list" do
      copy = list.dup
      assert_empty(specs_of(copy))
      copy.add(Toys::SourceSpec.path(toys_file))
      assert_equal([-1], priorities_of(copy))
    end

    it "can be copied again" do
      list.add(Toys::SourceSpec.path(toys_file))
      assert_equal([toys_file], specs_of(list.dup.dup).map(&:path))
    end

    it "can be copied with clone" do
      list.add(Toys::SourceSpec.path(toys_file))
      copy = list.clone
      copy.add(Toys::SourceSpec.path(toys_dir))
      assert_equal([toys_file, toys_dir], specs_of(copy).map(&:path))
      assert_equal([toys_file], specs_of(list).map(&:path))
    end
  end
end
