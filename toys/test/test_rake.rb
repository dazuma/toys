# frozen_string_literal: true

require "helper"

describe "rake template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }

  describe "unit functionality" do
    let(:template_class) { template_lookup.lookup(:rake) }
    let(:template) { template_class.new }

    it "handles the gem_version field" do
      assert_equal([], template.gem_version)
      template.gem_version = "~> 13.0"
      assert_equal(["~> 13.0"], template.gem_version)
      template.gem_version = ["~> 12.1.0", "< 13.0"]
      assert_equal(["~> 12.1.0", "< 13.0"], template.gem_version)
      template.gem_version = nil
      assert_equal([], template.gem_version)
    end

    it "handles the rakefile_path field" do
      assert_equal("Rakefile", template.rakefile_path)
      template.rakefile_path = "another/Rakefile"
      assert_equal("another/Rakefile", template.rakefile_path)
      template.rakefile_path = nil
      assert_equal("Rakefile", template.rakefile_path)
    end

    it "handles the only_described field" do
      assert_equal(false, template.only_described)
      template.only_described = true
      assert_equal(true, template.only_described)
    end

    it "handles the use_flags field" do
      assert_equal(false, template.use_flags)
      template.use_flags = true
      assert_equal(true, template.use_flags)
    end

    it "handles the bundler_settings field via the bundler writer" do
      assert_equal(false, template.bundler_settings)
      template.bundler = true
      assert_equal({}, template.bundler_settings)
      template.bundler = {groups: ["production"]}
      assert_equal({groups: ["production"]}, template.bundler_settings)
      template.bundler = false
      assert_equal(false, template.bundler_settings)
    end

    it "handles the bundler_settings field via use_bundler" do
      assert_equal(false, template.bundler_settings)
      template.use_bundler
      assert_equal({}, template.bundler_settings)
      template.use_bundler(groups: ["production"])
      assert_equal({groups: ["production"]}, template.bundler_settings)
    end

    it "handles the context_directory field" do
      assert_nil(template.context_directory)
      template.context_directory = "/path/to/somewhere"
      assert_equal("/path/to/somewhere", template.context_directory)
      template.context_directory = nil
      assert_nil(template.context_directory)
    end

    it "honors constructor args" do
      template = template_class.new gem_version: "~> 5.1",
                                    rakefile_path: "Rakefile1",
                                    only_described: true,
                                    use_flags: true,
                                    context_directory: "/path/to/context"
      assert_equal(["~> 5.1"], template.gem_version)
      assert_equal("Rakefile1", template.rakefile_path)
      assert_equal(true, template.only_described)
      assert_equal(true, template.use_flags)
      assert_equal("/path/to/context", template.context_directory)
    end
  end

  describe "integration functionality" do
    let(:cli) { Toys::CLI.new(middleware_stack: [], template_lookup: template_lookup) }
    let(:loader) { cli.loader }

    it "creates tools" do
      loader.add_block do
        expand :rake, rakefile_path: File.join(__dir__, "rakefiles/Rakefile1")
      end
      tool, remaining = loader.lookup(["foo1", "bar"])
      assert_equal(["foo1"], tool.full_name)
      assert_equal("Foo1 description", tool.desc.to_s)
      assert_equal(["bar"], remaining)
      tool, remaining = loader.lookup(["ns1", "foo2", "bar"])
      assert_equal(["ns1", "foo2"], tool.full_name)
      assert_equal("Foo2 description", tool.desc.to_s)
      assert_equal(["bar"], remaining)
    end

    it "does not replace existing tools" do
      loader.add_block do
        tool "foo1" do
          desc "Real foo1 description"
        end
        expand :rake, rakefile_path: File.join(__dir__, "rakefiles/Rakefile1")
      end
      tool, remaining = loader.lookup(["foo1", "bar"])
      assert_equal(["foo1"], tool.full_name)
      assert_equal("Real foo1 description", tool.desc.to_s)
      assert_equal(["bar"], remaining)
      tool, remaining = loader.lookup(["ns1", "foo2", "bar"])
      assert_equal(["ns1", "foo2"], tool.full_name)
      assert_equal("Foo2 description", tool.desc.to_s)
      assert_equal(["bar"], remaining)
    end

    it "creates tools from multiple rakefiles" do
      loader.add_block do
        expand :rake, rakefile_path: File.join(__dir__, "rakefiles/Rakefile2")
      end
      loader.add_block do
        expand :rake, rakefile_path: File.join(__dir__, "rakefiles/Rakefile1")
      end
      tool, remaining = loader.lookup(["foo1", "bar"])
      assert_equal(["foo1"], tool.full_name)
      assert_equal("Foo1 description from 2", tool.desc.to_s)
      assert_equal(["bar"], remaining)
      tool, remaining = loader.lookup(["ns1", "foo2", "bar"])
      assert_equal(["ns1", "foo2"], tool.full_name)
      assert_equal("Foo2 description", tool.desc.to_s)
      assert_equal(["bar"], remaining)
    end

    it "executes tools honoring rake dependencies" do
      rakefile_path = File.join(__dir__, "rakefiles/Rakefile2")
      loader.add_block do
        expand :rake, rakefile_path: rakefile_path
      end
      assert_output("executing bar1 from 2\nexecuting foo1 from 2\n") do
        cli.run("foo1")
      end
    end

    it "creates and executes a tool with arguments" do
      rakefile_path = File.join(__dir__, "rakefiles/Rakefile3")
      loader.add_block do
        expand :rake, rakefile_path: rakefile_path
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(2, tool.optional_args.size)
      assert(tool.flags.empty?)
      assert_equal(:one_two, tool.optional_args[0].key)
      assert_equal(:three, tool.optional_args[1].key)
      assert_output("executing foo\n\"hello\"\nnil\n") do
        cli.run("foo", "hello")
      end
    end

    it "creates and executes a tool with flags for arguments" do
      rakefile_path = File.join(__dir__, "rakefiles/Rakefile3")
      loader.add_block do
        expand :rake, rakefile_path: rakefile_path, use_flags: true
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(2, tool.flags.size)
      assert(tool.optional_args.empty?)
      assert_equal(:one_two, tool.flags[0].key)
      assert_equal(:three, tool.flags[1].key)
      assert_output("executing foo\n\"hi\"\n\"there\"\n") do
        cli.run("foo", "--one_two=hi", "--three", "there")
      end
    end

    it "allows dashes in flags" do
      rakefile_path = File.join(__dir__, "rakefiles/Rakefile3")
      loader.add_block do
        expand :rake, rakefile_path: rakefile_path, use_flags: true
      end
      assert_output("executing foo\n\"hello\"\nnil\n") do
        cli.run("foo", "--one-two=hello")
      end
    end

    it "creates tools without a description by default" do
      rakefile_path = File.join(__dir__, "rakefiles/Rakefile3")
      loader.add_block do
        expand :rake, rakefile_path: rakefile_path
      end
      tool, remaining = loader.lookup(["bar"])
      assert_equal(["bar"], tool.full_name)
      assert_equal([], remaining)
    end

    it "does not creates tools without a description if requested" do
      rakefile_path = File.join(__dir__, "rakefiles/Rakefile3")
      loader.add_block do
        expand :rake, rakefile_path: rakefile_path, only_described: true
      end
      tool, remaining = loader.lookup(["bar"])
      assert_equal([], tool.full_name)
      assert_equal(["bar"], remaining)
    end

    it "searches up the directory tree for rakefiles" do
      base_dir = __dir__
      Dir.chdir(File.join(base_dir, "rake-dirs", "dir1", "dir2")) do
        loader.add_path(File.join(base_dir, "rake-dirs", ".toys.rb"))
        tool, remaining = loader.lookup(["foo1", "bar"])
        assert_equal(["foo1"], tool.full_name)
        assert_equal(["bar"], remaining)
        rakefile_path = File.join(base_dir, "rake-dirs", "dir1", "Rakefile")
        expected_comments = [
          "Foo1 description", "",
          "Defined as a Rake task in #{rakefile_path}"
        ]
        assert_equal(expected_comments, tool.long_desc.map(&:to_s))
      end
    end

    it "sets the current working directory to the Rakefile directory" do
      base_dir = __dir__
      Dir.chdir(File.join(base_dir, "rake-dirs", "dir1", "dir2")) do
        loader.add_path(File.join(base_dir, "rake-dirs", ".toys.rb"))
        assert_output("Found = true\n") do
          cli.run("foo1")
        end
      end
    end

    it "honors context_directory argument" do
      basedir = __dir__
      subdir = File.join(basedir, "rake-dirs", "dir1", "dir2")
      loader.add_block do
        set_context_directory subdir
        expand :rake, context_directory: basedir
      end
      Dir.chdir(subdir) do
        loader.lookup(["foo1", "bar"])
      end
    end
  end
end
