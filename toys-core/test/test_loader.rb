# frozen_string_literal: true

require "helper"
require "fileutils"
require "tmpdir"
require "toys/utils/git_cache"

describe Toys::Loader do
  # Each test gets its own temp directory, so no test can see git cache state
  # left behind by another.
  let(:tmp_dir) { Dir.mktmpdir("toys_loader_git_cache_test") }
  let(:git_cache_dir) { File.join(tmp_dir, "cache") }
  let(:git_cache) { Toys::Utils::GitCache.new(cache_dir: git_cache_dir) }
  let(:source_list) { Toys::SourceList.new }
  let(:loader) {
    Toys::Loader.new(source_list,
                     tool_name_splitter: Toys::ToolNameSplitter.new(":"),
                     git_cache: git_cache)
  }
  let(:cases_dir) { File.join(File.dirname(__dir__), "test-data", "lookup-cases") }
  let(:git_remote) { "https://github.com/dazuma/toys.git" }
  let(:git_commit) { "main" }

  def wrappable(str)
    Toys::WrappableString.new(str)
  end

  after do
    # Cached sources are made read-only, so restore write access before
    # removing the temp directory. Removal also races with the maintenance
    # process that git spawns detached after a fetch, in two ways. It can
    # write new pack files into a directory that rm_rf has already emptied,
    # which leaves the tree in place without raising anything. It can also
    # delete an objects directory between the moment chmod_R lists it and the
    # moment it descends into it, which raises out of the traversal because
    # `force` covers only the chmod of each entry, not the walk. So swallow
    # the walk errors, and retry until the tree is really gone.
    5.times do
      begin
        FileUtils.chmod_R("u+w", tmp_dir, force: true)
      rescue SystemCallError
        # Fall through to the removal attempt, then try again.
      end
      FileUtils.rm_rf(tmp_dir)
      break unless File.exist?(tmp_dir)
      sleep(0.1)
    end
  end

  describe "empty" do
    it "still has a root tool" do
      tool, _remaining = loader.lookup([])
      refute_nil(tool)
    end

    it "gives the root tool a source root at the lowest priority" do
      tool, _remaining = loader.lookup([])
      # ToolDefinition#priority reads through to the source root, so it raises
      # rather than returning a priority if the root is missing.
      assert_equal(-999_999, tool.priority)
      refute_nil(tool.source_root)
      assert_same(tool.source_root, tool.source_root.root)
      assert_equal(tool.priority, tool.source_root.priority)
    end

    it "gives a tool created at a priority with no starting source a source root" do
      tool = loader.activate_tool(["tool-1"], 0)
      assert_equal(0, tool.priority)
      refute_nil(tool.source_root)
      assert_equal(0, tool.source_root.priority)
    end
  end

  describe "starting sources" do
    it "allows multiple starting sources sharing a priority via a common root" do
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "config-items"),
                                            relative_paths: [".toys", ".toys.rb"],
                                            context_directory: :path))
      # Both members share the synthetic root source.
      # SourceList guarantees that every priority maps to exactly one root,
      # which is why the loader can index roots by priority without checking.
      tool1, _remaining = loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool1.desc.to_s)
      tool2, _remaining = loader.lookup(["tool-2"])
      assert_equal("directory tool-2 short description", tool2.desc.to_s)
    end

    it "gives each tool the root of the starting source at its priority" do
      set_root = File.join(cases_dir, "config-items")
      hierarchy_root = File.join(cases_dir, "normal-file-hierarchy")
      source_list.add(Toys::SourceSpec.path(set_root, relative_paths: [".toys", ".toys.rb"], context_directory: :path))
      # Added at lower priority, so the path set still wins for shared names.
      source_list.add(Toys::SourceSpec.path(hierarchy_root))

      # Both members of the path set resolve to the synthetic root, even
      # though they are different files at the same priority.
      tool1, _remaining = loader.lookup(["tool-1"])
      assert_equal(set_root, tool1.source_root.source_path)
      tool2, _remaining = loader.lookup(["tool-2"])
      assert_equal(set_root, tool2.source_root.source_path)
      assert_same(tool1.source_root, tool2.source_root)

      # tool-3 exists only in the hierarchy, so it carries the other root.
      tool3, _remaining = loader.lookup(["tool-3"])
      assert_equal(hierarchy_root, tool3.source_root.source_path)
    end
  end

  describe "configuration block" do
    it "loads tools" do
      spec = Toys::SourceSpec.block(source_name: "test block") do
        tool "tool-1" do
          desc "block tool-1 description"
        end
      end
      source_list.add(spec)
      tool, remaining = loader.lookup(["tool-1"])
      assert_equal("block tool-1 description", tool.desc.to_s)
      assert_equal(true, tool.definition_finished?)
      assert_equal("test block", tool.source_info.source_name)
      assert_equal([], remaining)
    end

    it "loads multiple blocks" do
      spec = Toys::SourceSpec.block(source_name: "test block 1") do
        tool "tool-1" do
          desc "block 1 tool-1 description"
        end
      end
      source_list.add(spec)
      spec = Toys::SourceSpec.block(source_name: "test block 2") do
        tool "tool-1" do
          desc "block 2 tool-1 description"
        end
        tool "tool-2" do
          desc "block 2 tool-2 description"
        end
      end
      source_list.add(spec)
      tool, remaining = loader.lookup(["tool-1"])
      assert_equal("block 1 tool-1 description", tool.desc.to_s)
      assert_equal(true, tool.definition_finished?)
      assert_equal("test block 1", tool.source_info.source_name)
      assert_equal([], remaining)
      tool, remaining = loader.lookup(["tool-2"])
      assert_equal("block 2 tool-2 description", tool.desc.to_s)
      assert_equal(true, tool.definition_finished?)
      assert_equal("test block 2", tool.source_info.source_name)
      assert_equal([], remaining)
    end
  end

  describe "tool names" do
    it "raises if there's an asterisk in the name when defining a tool" do
      spec = Toys::SourceSpec.block(source_name: "test block 1") do
        tool "tool*1" do
          desc "whoops"
        end
      end
      source_list.add(spec)
      error = assert_raises(Toys::ContextualError) do
        loader.lookup([])
      end
      cause = error.cause
      assert_instance_of(Toys::ToolDefinitionError, cause)
      assert_match(/Illegal characters in name "tool\*1"/, cause.message)
    end

    it "doesn't raise if looking up a name with an asterisk" do
      spec = Toys::SourceSpec.block(source_name: "test block 1") do
        tool "tool-1" do
          desc "block 1 tool-1 description"
        end
      end
      source_list.add(spec)
      tool, remaining = loader.lookup(["tool*1"])
      assert_equal([], tool.full_name)
      assert_equal(["tool*1"], remaining)
    end
  end

  describe "path with config items" do
    before do
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "config-items", ".toys")))
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "config-items", ".toys.rb")))
    end

    it "finds a tool directly defined in a config file" do
      tool, remaining = loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal(true, tool.definition_finished?)
      assert_equal([], remaining)
    end

    it "finds a subtool directly defined in a config file" do
      tool, remaining = loader.lookup(["namespace-1", "tool-1-1"])
      assert_equal("file tool-1-1 short description", tool.desc.to_s)
      assert_equal(["namespace-1", "tool-1-1"], tool.full_name)
      assert_equal([], remaining)
    end

    it "finds a namespace directly defined in a config file" do
      tool, remaining = loader.lookup(["namespace-1"])
      assert_equal("file namespace-1 short description", tool.desc.to_s)
      assert_equal(["namespace-1"], tool.full_name)
      assert_equal([], remaining)
    end

    it "finds a tool defined in a file in a config directory" do
      tool, remaining = loader.lookup(["tool-2"])
      assert_equal("directory tool-2 short description", tool.desc.to_s)
      assert_equal([], remaining)
    end

    it "finds the nearest namespace directly defined if a query doesn't match" do
      tool, remaining = loader.lookup(["namespace-1", "tool-blah"])
      assert_equal("file namespace-1 short description", tool.desc.to_s)
      assert_equal(["namespace-1"], tool.full_name)
      assert_equal(["tool-blah"], remaining)
    end

    it "finds the root if a query has no toplevel match" do
      tool, remaining = loader.lookup(["tool-blah"])
      assert_equal([], tool.full_name)
      assert_nil(tool.simple_name)
      assert_equal(["tool-blah"], remaining)
    end
  end

  describe "config from git sources" do
    before do
      skip "Skipped integration test" unless ENV["TOYS_TEST_INTEGRATION"]
      source_list.add(Toys::SourceSpec.git(git_remote, commit: git_commit,
                                           path: "toys-core/test-data/lookup-cases/config-items/.toys"))
      source_list.add(Toys::SourceSpec.git(git_remote, commit: git_commit,
                                           path: "toys-core/test-data/lookup-cases/config-items/.toys.rb"))
    end

    it "finds a tool directly defined in a config file" do
      tool, remaining = loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal(true, tool.definition_finished?)
      assert_equal([], remaining)
    end

    it "finds a subtool directly defined in a config file" do
      tool, remaining = loader.lookup(["namespace-1", "tool-1-1"])
      assert_equal("file tool-1-1 short description", tool.desc.to_s)
      assert_equal(["namespace-1", "tool-1-1"], tool.full_name)
      assert_equal([], remaining)
    end

    it "finds a namespace directly defined in a config file" do
      tool, remaining = loader.lookup(["namespace-1"])
      assert_equal("file namespace-1 short description", tool.desc.to_s)
      assert_equal(["namespace-1"], tool.full_name)
      assert_equal([], remaining)
    end

    it "finds a tool defined in a file in a config directory" do
      tool, remaining = loader.lookup(["tool-2"])
      assert_equal("directory tool-2 short description", tool.desc.to_s)
      assert_equal([], remaining)
    end
  end

  describe "config from gem sources" do
    let(:gem_toys_dir) { "test-data/lookup-cases/config-items" }

    before do
      # Using directories in the local toys-core source in git, which is
      # referenced as a gem in the bundle.
      # These directories aren't part of the released gem.
      source_list.add(Toys::SourceSpec.gem("toys-core", path: ".toys", toys_dir: gem_toys_dir))
      source_list.add(Toys::SourceSpec.gem("toys-core", path: ".toys.rb", toys_dir: gem_toys_dir))
    end

    it "finds a tool directly defined in a config file" do
      tool, remaining = loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal(true, tool.definition_finished?)
      assert_equal([], remaining)
      assert_match(%r{^gem\(name=toys-core version=\S+ path=#{gem_toys_dir}/\.toys\.rb\)},
                   tool.source_info.source_name)
    end

    it "finds a subtool directly defined in a config file" do
      tool, remaining = loader.lookup(["namespace-1", "tool-1-1"])
      assert_equal("file tool-1-1 short description", tool.desc.to_s)
      assert_equal(["namespace-1", "tool-1-1"], tool.full_name)
      assert_equal([], remaining)
      assert_match(%r{^gem\(name=toys-core version=\S+ path=#{gem_toys_dir}/\.toys\.rb\)},
                   tool.source_info.source_name)
    end

    it "finds a namespace directly defined in a config file" do
      tool, remaining = loader.lookup(["namespace-1"])
      assert_equal("file namespace-1 short description", tool.desc.to_s)
      assert_equal(["namespace-1"], tool.full_name)
      assert_equal([], remaining)
      assert_match(%r{^gem\(name=toys-core version=\S+ path=#{gem_toys_dir}/\.toys\.rb\)},
                   tool.source_info.source_name)
    end

    it "finds a tool defined in a file in a config directory" do
      tool, remaining = loader.lookup(["tool-2"])
      assert_equal("directory tool-2 short description", tool.desc.to_s)
      assert_equal([], remaining)
      assert_match(%r{^gem\(name=toys-core version=\S+ path=#{gem_toys_dir}/\.toys/tool-2\.rb\)},
                   tool.source_info.source_name)
    end
  end

  describe "config path with some hierarchical files" do
    before do
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "normal-file-hierarchy")))
    end

    it "finds a tool directly defined" do
      tool, remaining = loader.lookup(["tool-1"])
      assert_equal("normal tool-1 short description", tool.desc.to_s)
      assert_equal([], remaining)
      assert_equal(cases_dir, tool.source_info.context_directory)
    end

    it "finds a subtool directly defined" do
      tool, remaining = loader.lookup(["namespace-1", "tool-1-3"])
      assert_equal("normal tool-1-3 short description", tool.desc.to_s)
      assert_equal(["namespace-1", "tool-1-3"], tool.full_name)
      assert_equal([], remaining)
      assert_equal(cases_dir, tool.source_info.context_directory)
    end

    it "finds a namespace directly defined" do
      tool, remaining = loader.lookup(["namespace-1"])
      assert_equal(false, tool.runnable?)
      assert_equal(["namespace-1"], tool.full_name)
      assert_equal([], remaining)
    end

    it "finds the nearest namespace directly defined if a query doesn't match" do
      tool, remaining = loader.lookup(["namespace-1", "tool-blah"])
      assert_equal(false, tool.runnable?)
      assert_equal(["namespace-1"], tool.full_name)
      assert_equal(["tool-blah"], remaining)
    end

    it "finds the root if a query has no toplevel match" do
      tool, remaining = loader.lookup(["tool-blah"])
      assert_equal([], tool.full_name)
      assert_nil(tool.simple_name)
      assert_equal(["tool-blah"], remaining)
    end

    it "does not load unnecessary files" do
      loader.lookup(["namespace-1", "tool-1-3"])
      assert_equal(true, loader.tool_defined?(["namespace-1", "tool-1-3"]))
      assert_equal(true, loader.tool_defined?(["namespace-1"]))
      assert_equal(false, loader.tool_defined?(["namespace-1", "tool-1-1"]))
      assert_equal(false, loader.tool_defined?(["tool-1"]))
      loader.lookup(["tool-1"])
      assert_equal(true, loader.tool_defined?(["tool-1"]))
      assert_equal(false, loader.tool_defined?(["namespace-1", "tool-1-1"]))
    end

    it "loads all descendants of a namespace query" do
      loader.lookup([])
      assert_equal(true, loader.tool_defined?(["namespace-1", "tool-1-3"]))
      assert_equal(true, loader.tool_defined?(["tool-1"]))
    end
  end

  describe "extra delimiters" do
    let(:delimiters_loader) {
      Toys::Loader.new(source_list,
                       tool_name_splitter: Toys::ToolNameSplitter.new(".:"),
                       git_cache: git_cache)
    }

    before do
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "normal-file-hierarchy")))
    end

    it "recognizes only specified delimiters" do
      tool, remaining = delimiters_loader.lookup(["namespace-1/tool-1-3"])
      assert_equal([], tool.full_name)
      assert_nil(tool.simple_name)
      assert_equal(["namespace-1/tool-1-3"], remaining)
    end

    it "finds a subtool using a specified delimiter" do
      tool, remaining = delimiters_loader.lookup(["namespace-1.tool-1-3"])
      assert_equal("normal tool-1-3 short description", tool.desc.to_s)
      assert_equal(["namespace-1", "tool-1-3"], tool.full_name)
      assert_equal([], remaining)
    end

    it "finds a subtool using whitespace as a delimiter" do
      tool, remaining = delimiters_loader.lookup(["namespace-1\ttool-1-3"])
      assert_equal("normal tool-1-3 short description", tool.desc.to_s)
      assert_equal(["namespace-1", "tool-1-3"], tool.full_name)
      assert_equal([], remaining)
    end

    it "finds the nearest namespace if a query doesn't match" do
      tool, remaining = delimiters_loader.lookup(["namespace-1.tool-blah"])
      assert_equal(false, tool.runnable?)
      assert_equal(["namespace-1"], tool.full_name)
      assert_equal(["tool-blah"], remaining)
    end

    it "finds a subtool if a delimiter isn't used" do
      tool, remaining = delimiters_loader.lookup(["namespace-1", "tool-1-3"])
      assert_equal("normal tool-1-3 short description", tool.desc.to_s)
      assert_equal(["namespace-1", "tool-1-3"], tool.full_name)
      assert_equal([], remaining)
    end
  end

  describe "priority between definitions" do
    it "chooses from the earlier path" do
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "config-items", ".toys")))
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "config-items", ".toys.rb")))
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "normal-file-hierarchy")))

      tool, _remaining = loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal(-2, tool.priority)
    end

    it "honors the high-priority flag" do
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "config-items", ".toys")))
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "config-items", ".toys.rb")))
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "normal-file-hierarchy")), high_priority: true)

      tool, _remaining = loader.lookup(["tool-1"])
      assert_equal("normal tool-1 short description", tool.desc.to_s)
      assert_equal(1, tool.priority)
    end

    it "loads a set at the same priority" do
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "config-items"),
                                            relative_paths: [".toys", ".toys.rb"],
                                            context_directory: :path))

      tool1, _remaining = loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool1.desc.to_s)
      assert_equal(-1, tool1.priority)

      tool2, _remaining = loader.lookup(["tool-2"])
      assert_equal("directory tool-2 short description", tool2.desc.to_s)
      assert_equal(-1, tool2.priority)
    end

    it "loads a set at high priority" do
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "config-items"),
                                            relative_paths: [".toys", ".toys.rb"],
                                            context_directory: :path),
                      high_priority: true)

      tool1, _remaining = loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool1.desc.to_s)
      assert_equal(1, tool1.priority)

      tool2, _remaining = loader.lookup(["tool-2"])
      assert_equal("directory tool-2 short description", tool2.desc.to_s)
      assert_equal(1, tool2.priority)
    end

    it "raises at load time if a member of a set does not exist" do
      root_path = File.join(cases_dir, "config-items")
      source_list.add(Toys::SourceSpec.path(root_path, relative_paths: [".toys", ".nonexistent"],
                                            context_directory: :path))
      error = assert_raises(Toys::SourceResolutionError) do
        loader.lookup(["tool-1"])
      end
      assert_equal("Cannot read: #{File.join(root_path, '.nonexistent')}", error.message)
    end

    it "raises at load time if a member of a set is not a ruby file" do
      root_path = File.join(cases_dir, "normal-file-hierarchy")
      source_list.add(Toys::SourceSpec.path(root_path, relative_paths: ["hello.txt"],
                                            context_directory: :path))
      error = assert_raises(Toys::SourceResolutionError) do
        loader.lookup(["tool-1"])
      end
      assert_equal("File is not a ruby file: #{File.join(root_path, 'hello.txt')}", error.message)
    end

    it "loads no member of a set if another member is bad" do
      root_path = File.join(cases_dir, "config-items")
      source_list.add(Toys::SourceSpec.path(root_path, relative_paths: [".toys", ".nonexistent"],
                                            context_directory: :path))
      assert_equal(1, source_list.size)
      assert_raises(Toys::SourceResolutionError) do
        loader.lookup(["tool-2"])
      end
      # The good member defines tool-2, and was not loaded either.
      refute(loader.tool_defined?(["tool-2"]))
    end

    it "raises at load time if the root of a path set is not a directory" do
      root_path = File.join(cases_dir, "config-items", ".toys.rb")
      source_list.add(Toys::SourceSpec.path(root_path, relative_paths: [], context_directory: :path))
      error = assert_raises(Toys::SourceResolutionError) do
        loader.lookup(["tool-1"])
      end
      assert_equal("Root of a source path set is not a directory: #{root_path}", error.message)
    end
  end

  describe "stop_loading_at_priority" do
    it "cuts off lower priorities" do
      spec = Toys::SourceSpec.block(source_name: "test block 1") do
        tool "tool-1" do
          desc "block 1 tool-1 description"
        end
      end
      source_list.add(spec)
      spec = Toys::SourceSpec.block(source_name: "test block 2") do
        tool "tool-2" do
          desc "block 2 tool-2 description"
        end
      end
      source_list.add(spec)
      assert(loader.stop_loading_at_priority(-1))
      tool1, remaining1 = loader.lookup(["tool-1"])
      assert_equal(-1, tool1.priority)
      assert_empty(remaining1)
      tool2, remaining2 = loader.lookup(["tool-2"])
      refute_equal(-2, tool2.priority)
      refute_empty(remaining2)
    end

    it "returns false if a lower priority has already been loaded" do
      spec = Toys::SourceSpec.block(source_name: "test block 1") do
        tool "tool-1" do
          desc "block 1 tool-1 description"
        end
      end
      source_list.add(spec)
      spec = Toys::SourceSpec.block(source_name: "test block 2") do
        tool "tool-2" do
          desc "block 2 tool-2 description"
        end
      end
      source_list.add(spec)
      tool2, remaining2 = loader.lookup(["tool-2"])
      assert_equal(-2, tool2.priority)
      assert_empty(remaining2)
      refute(loader.stop_loading_at_priority(-1))
    end
  end

  describe "includes with absolute path loads" do
    let(:includes_cases_dir) { File.join(cases_dir, "items-with-includes") }

    before do
      source_list.add(Toys::SourceSpec.path(File.join(includes_cases_dir, "absolutes.rb")))
    end

    it "gets an item from a root-level directory include" do
      tool, _remaining = loader.lookup(["tool-2"])
      assert_equal("directory tool-2 short description", tool.desc.to_s)
    end

    it "gets an item from a root-level file include" do
      tool, _remaining = loader.lookup(["namespace-1", "tool-1-1"])
      assert_equal("file tool-1-1 short description", tool.desc.to_s)
      assert_equal(includes_cases_dir, tool.source_info.context_directory)
    end

    it "gets an item from non-root-level include" do
      tool, _remaining = loader.lookup(["namespace-0", "namespace-1", "tool-1-1"])
      assert_equal("normal tool-1-1 short description", tool.desc.to_s)
      assert_equal(includes_cases_dir, tool.source_info.context_directory)
    end

    it "does not load an include if not needed" do
      loader.lookup(["namespace-1", "tool-1-1"])
      assert_equal(true, loader.tool_defined?(["namespace-1", "tool-1-1"]))
      assert_equal(false, loader.tool_defined?(["namespace-0", "tool-1"]))
      loader.lookup(["namespace-0", "tool-1"])
      assert_equal(true, loader.tool_defined?(["namespace-0", "tool-1"]))
    end

    it "loads includes that are descendants of a namespace query" do
      assert_equal(false, loader.tool_defined?(["namespace-0", "namespace-1", "tool-1-1"]))
      loader.lookup(["namespace-0"])
      assert_equal(true, loader.tool_defined?(["namespace-0", "namespace-1", "tool-1-1"]))
    end
  end

  describe "includes with github loads" do
    let(:includes_cases_dir) { File.join(cases_dir, "items-with-includes") }

    before do
      skip "Skipped integration test" unless ENV["TOYS_TEST_INTEGRATION"]
      source_list.add(Toys::SourceSpec.path(File.join(includes_cases_dir, "github.rb")))
    end

    it "gets an item from a root-level directory include" do
      tool, _remaining = loader.lookup(["tool-2"])
      assert_equal("directory tool-2 short description", tool.desc.to_s)
    end

    it "gets an item from a root-level file include" do
      tool, _remaining = loader.lookup(["namespace-1", "tool-1-1"])
      assert_equal("file tool-1-1 short description", tool.desc.to_s)
      assert_equal(includes_cases_dir, tool.source_info.context_directory)
    end

    it "gets an item from non-root-level include" do
      tool, _remaining = loader.lookup(["namespace-0", "namespace-1", "tool-1-1"])
      assert_equal("normal tool-1-1 short description", tool.desc.to_s)
      assert_equal(includes_cases_dir, tool.source_info.context_directory)
    end

    it "does not load an include if not needed" do
      loader.lookup(["namespace-1", "tool-1-1"])
      assert_equal(true, loader.tool_defined?(["namespace-1", "tool-1-1"]))
      assert_equal(false, loader.tool_defined?(["namespace-0", "tool-1"]))
      loader.lookup(["namespace-0", "tool-1"])
      assert_equal(true, loader.tool_defined?(["namespace-0", "tool-1"]))
    end

    it "loads includes that are descendants of a namespace query" do
      assert_equal(false, loader.tool_defined?(["namespace-0", "namespace-1", "tool-1-1"]))
      loader.lookup(["namespace-0"])
      assert_equal(true, loader.tool_defined?(["namespace-0", "namespace-1", "tool-1-1"]))
    end
  end

  describe "preloads" do
    before do
      $toys_preload_ns1 = nil
      $toys_preload_ns2 = nil
      $toys_preload_ns1a_preloaded1 = nil
      $toys_preload_ns1a_preloaded2 = nil
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "preloads")))
    end

    it "finds a simple preload file" do
      assert_nil($toys_preload_ns2)
      loader.lookup(["ns-2", "foo"])
      assert_equal(:hi, $toys_preload_ns2)
    end

    it "finds nested preload files" do
      assert_nil($toys_preload_ns1)
      assert_nil($toys_preload_ns1a_preloaded1)
      assert_nil($toys_preload_ns1a_preloaded2)
      loader.lookup(["ns-1", "ns-1a", "foo"])
      assert_equal(:hi, $toys_preload_ns1)
      assert_equal(:hi, $toys_preload_ns1a_preloaded1)
      assert_equal(:hi, $toys_preload_ns1a_preloaded2)
    end
  end

  describe "with data directory" do
    before do
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "data-finder")))
    end

    it "finds data during loading" do
      loader.lookup(["ns-1", "foo"])
    end

    it "overrides data during loading" do
      loader.lookup(["ns-1", "ns-1a", "foo"])
    end

    it "finds parent data during loading" do
      loader.lookup(["ns-1", "ns-1b", "foo"])
    end

    it "finds root data during loading" do
      loader.lookup(["ns-4", "foo"])
    end

    it "reports lack of data during loading" do
      loader.lookup(["ns-3", "foo"])
    end
  end

  describe "context directory" do
    let(:custom_dir) { "/path/to/dir" }

    it "can be set" do
      dir = custom_dir
      spec = Toys::SourceSpec.block(source_name: "test block") do
        desc "a description"
        tool "ns1" do
          set_context_directory(dir)
          desc "a description"
          tool "tool1" do
            desc "a description"
          end
        end
      end
      source_list.add(spec)
      tool, _remaining = loader.lookup([])
      assert_nil(tool.source_info.context_directory)
      assert_nil(tool.context_directory)
      tool, _remaining = loader.lookup(["ns1"])
      assert_nil(tool.source_info.context_directory)
      assert_equal(custom_dir, tool.context_directory)
      tool, _remaining = loader.lookup(["ns1", "tool1"])
      assert_nil(tool.source_info.context_directory)
      assert_equal(custom_dir, tool.context_directory)
    end
  end

  describe "subtool list" do
    let(:subtools_loader) {
      spec = Toys::SourceSpec.block(source_name: "test block") do
        tool "ns3" do
          tool "tool1" do
            def run; end
          end
          tool "tool4" do
            desc "hi"
          end
          def run; end
        end
        tool "ns2" do
          tool "tool3" do
            def run; end
          end
          tool "_tool2" do
            def run; end
          end
        end
        tool "_ns1" do
          tool "tool2" do
            def run; end
          end
          tool "tool1" do
            def run; end
          end
          def run; end
        end
      end
      source_list.add(spec)
      loader
    }

    it "loads a list" do
      subtools = subtools_loader.list_subtools([])
      assert_equal(1, subtools.size)
      assert_equal(["ns3"], subtools[0].full_name)
    end

    it "loads a sublist" do
      subtools = subtools_loader.list_subtools(["ns3"])
      assert_equal([["ns3", "tool1"]], subtools.map(&:full_name))
    end

    it "loads a sublist of a hidden" do
      subtools = subtools_loader.list_subtools(["_ns1"])
      assert_equal([["_ns1", "tool1"], ["_ns1", "tool2"]], subtools.map(&:full_name))
    end

    it "loads a list including non-runnable" do
      subtools = subtools_loader.list_subtools([], include_namespaces: true)
      assert_equal(2, subtools.size)
      assert_equal(["ns2"], subtools[0].full_name)
      assert_equal(["ns3"], subtools[1].full_name)
    end

    it "loads a list with recursion" do
      subtools = subtools_loader.list_subtools([], recursive: true)
      assert_equal(3, subtools.size)
      assert_equal(["ns2", "tool3"], subtools[0].full_name)
      assert_equal(["ns3"], subtools[1].full_name)
      assert_equal(["ns3", "tool1"], subtools[2].full_name)
    end

    it "loads a list with recursion including non-runnable" do
      subtools = subtools_loader.list_subtools([], recursive: true, include_non_runnable: true)
      assert_equal(4, subtools.size)
      assert_equal(["ns2", "tool3"], subtools[0].full_name)
      assert_equal(["ns3"], subtools[1].full_name)
      assert_equal(["ns3", "tool1"], subtools[2].full_name)
      assert_equal(["ns3", "tool4"], subtools[3].full_name)
    end

    it "loads a list including hidden" do
      subtools = subtools_loader.list_subtools([], include_hidden: true)
      assert_equal(2, subtools.size)
      assert_equal(["_ns1"], subtools[0].full_name)
      assert_equal(["ns3"], subtools[1].full_name)
    end

    it "loads a list including namespaces with recursion" do
      subtools = subtools_loader.list_subtools([], recursive: true, include_namespaces: true)
      assert_equal(4, subtools.size)
      assert_equal(["ns2"], subtools[0].full_name)
      assert_equal(["ns2", "tool3"], subtools[1].full_name)
      assert_equal(["ns3"], subtools[2].full_name)
      assert_equal(["ns3", "tool1"], subtools[3].full_name)
    end
  end

  describe "has_subtools?" do
    it "returns true when runnable subtools exist" do
      spec = Toys::SourceSpec.block do
        tool "ns1" do
          tool "child" do
            def run; end
          end
        end
      end
      source_list.add(spec)
      assert(loader.has_subtools?(["ns1"]))
    end

    it "returns true when only non-runnable subtools exist" do
      spec = Toys::SourceSpec.block do
        tool "ns1" do
          tool "child" do
            desc "not runnable"
          end
        end
      end
      source_list.add(spec)
      assert(loader.has_subtools?(["ns1"]))
    end

    it "returns true when only hidden subtools exist" do
      spec = Toys::SourceSpec.block do
        tool "ns1" do
          tool "_hidden" do
            def run; end
          end
        end
      end
      source_list.add(spec)
      assert(loader.has_subtools?(["ns1"]))
    end

    it "returns false when no subtools exist" do
      spec = Toys::SourceSpec.block do
        tool "ns1" do
          tool "child" do
            def run; end
          end
        end
      end
      source_list.add(spec)
      refute(loader.has_subtools?(["ns1", "child"]))
    end

    it "returns false for an empty loader" do
      refute(loader.has_subtools?([]))
    end

    it "triggers lazy loading from a path source" do
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "normal-file-hierarchy")))
      refute(loader.tool_defined?(["namespace-1", "tool-1-1"]))
      assert(loader.has_subtools?(["namespace-1"]))
      assert(loader.tool_defined?(["namespace-1", "tool-1-1"]))
    end
  end

  describe "concurrency" do
    it "serializes loading" do
      spec = Toys::SourceSpec.block(source_name: "test block") do
        sleep(0.1)
        tool "tool-1" do
          desc "block tool-1 description"
        end
      end
      source_list.add(spec)
      # Construct the loader on this thread. Minitest memoizes `let` values
      # without synchronization, so if the threads below were the first to
      # reference it, they could race and end up with two separate loaders.
      test_loader = loader
      tool1 = tool2 = nil
      thread1 = Thread.new do
        tool1, _remaining = test_loader.lookup(["tool-1"])
      end
      thread2 = Thread.new do
        tool2, _remaining = test_loader.lookup(["tool-1"])
      end
      thread1.join
      thread2.join
      assert_equal("block tool-1 description", tool1.desc.to_s)
      assert_same(tool2, tool1)
    end
  end

  describe "deferred resolution" do
    let(:gem_toys_dir) { "test-data/lookup-cases/config-items" }
    let(:gems_util_calls) { [] }
    let(:gems_util) {
      calls = gems_util_calls
      util = Object.new
      util.define_singleton_method(:activate) { |name, *versions| calls << [name, versions] }
      util
    }
    let(:deferring_loader) {
      Toys::Loader.new(source_list, git_cache: git_cache, gems_util: gems_util)
    }

    it "resolves nothing while the loader is being constructed" do
      source_list.add(Toys::SourceSpec.path(File.join(cases_dir, "doesnotexist")))
      source_list.add(Toys::SourceSpec.gem("toys-core", path: ".toys", toys_dir: gem_toys_dir))
      deferring_loader
      assert_empty(gems_util_calls)
    end

    it "resolves a level exactly once across repeated lookups" do
      source_list.add(Toys::SourceSpec.gem("toys-core", path: ".toys", toys_dir: gem_toys_dir))
      3.times { deferring_loader.lookup(["tool-2"]) }
      assert_equal([["toys-core", []]], gems_util_calls)
    end

    it "reports a source failure at first lookup rather than at construction" do
      bad_path = File.join(cases_dir, "doesnotexist")
      source_list.add(Toys::SourceSpec.path(bad_path))
      error = assert_raises(Toys::SourceResolutionError) { deferring_loader.lookup(["tool-1"]) }
      assert_equal("Cannot read: #{bad_path}", error.message)
    end

    it "never resolves a level truncated away by a higher-priority source" do
      spec = Toys::SourceSpec.block(source_name: "truncator") do
        truncate_load_path!
      end
      source_list.add(spec)
      source_list.add(Toys::SourceSpec.gem("toys-core", path: ".toys", toys_dir: gem_toys_dir))
      deferring_loader.lookup(["tool-2"])
      assert_empty(gems_util_calls)
    end
  end

  describe "middleware stack" do
    let(:default_middleware) {
      [
        Toys::Middleware.spec(:set_default_descriptions),
        Toys::Middleware.spec(:show_help, help_flags: true, fallback_execution: true),
      ]
    }
    let(:middleware_lookup) { Toys::ModuleLookup.new.add_path("toys/standard_middleware") }
    let(:middleware_source_list) { Toys::SourceList.new }
    let(:middleware_loader) {
      Toys::Loader.new(middleware_source_list,
                       middleware_lookup: middleware_lookup,
                       middleware_stack: default_middleware)
    }

    it "builds default middleware" do
      spec = Toys::SourceSpec.block(source_name: "test block") do
        tool "tool-1" do
          desc "hello"
        end
      end
      middleware_source_list.add(spec)
      tool, _remaining = middleware_loader.lookup(["tool-1"])
      built_middleware = tool.built_middleware
      assert_equal(2, built_middleware.size)
      assert_instance_of(Toys::StandardMiddleware::SetDefaultDescriptions, built_middleware[0])
      assert_instance_of(Toys::StandardMiddleware::ShowHelp, built_middleware[1])
    end

    it "gets middleware stack from parent" do
      spec = Toys::SourceSpec.block(source_name: "test block") do
        tool "tool-1" do
          desc "hello"
          current_tool.subtool_middleware_stack.add(:add_verbosity_flags)
          tool "tool-2" do
            desc "hello"
          end
        end
      end
      middleware_source_list.add(spec)
      tool, _remaining = middleware_loader.lookup(["tool-1", "tool-2"])
      built_middleware = tool.built_middleware
      assert_equal(3, built_middleware.size)
      assert_instance_of(Toys::StandardMiddleware::AddVerbosityFlags, built_middleware[0])
      assert_instance_of(Toys::StandardMiddleware::SetDefaultDescriptions, built_middleware[1])
      assert_instance_of(Toys::StandardMiddleware::ShowHelp, built_middleware[2])
    end
  end
end
