# frozen_string_literal: true

require "helper"

describe "clean template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }

  describe "unit functionality" do
    let(:template_class) { template_lookup.lookup(:clean) }
    let(:template) { template_class.new }

    it "handles the name field" do
      assert_equal("clean", template.name)
      template.name = "hi"
      assert_equal("hi", template.name)
      template.name = nil
      assert_equal("clean", template.name)
    end

    it "handles the paths field" do
      assert_equal([], template.paths)
      template.paths = "/path/to/somewhere"
      assert_equal(["/path/to/somewhere"], template.paths)
      template.paths = nil
      assert_equal([], template.paths)
    end

    it "handles the preserve field" do
      assert_equal([], template.preserve)
      template.preserve = "/path/to/somewhere"
      assert_equal(["/path/to/somewhere"], template.preserve)
      template.preserve = nil
      assert_equal([], template.preserve)
    end

    it "handles the context_directory field" do
      assert_nil(template.context_directory)
      template.context_directory = "/path/to/somewhere"
      assert_equal("/path/to/somewhere", template.context_directory)
      template.context_directory = nil
      assert_nil(template.context_directory)
    end

    it "honors constructor args" do
      template = template_class.new name: "hi",
                                    paths: "/path/to/somewhere",
                                    preserve: "/path/to/keep",
                                    context_directory: "/path/to/context"
      assert_equal("hi", template.name)
      assert_equal(["/path/to/somewhere"], template.paths)
      assert_equal(["/path/to/keep"], template.preserve)
      assert_equal("/path/to/context", template.context_directory)
    end
  end

  describe "integration functionality" do
    let(:cli) { Toys::CLI.new(middleware_stack: [], template_lookup: template_lookup) }
    let(:loader) { cli.loader }
    let(:workspace_dir) { File.join(File.dirname(__dir__), "test-data", "clean-workspace") }

    def clean_workspace
      Dir.foreach(workspace_dir) do |child|
        unless [".", "..", ".gitkeep"].include?(child)
          FileUtils.rm_rf(File.join(workspace_dir, child))
        end
      end
    end

    before { clean_workspace }
    after { clean_workspace }

    it "cleans a pattern" do
      dir = workspace_dir
      FileUtils.touch(File.join(dir, "foo.txt"))
      FileUtils.touch(File.join(dir, "bar.yml"))
      loader.add_block do
        set_context_directory dir
        expand :clean, paths: "*.txt"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("clean"))
      end
      assert_equal("Cleaned: foo.txt\n", out)
      assert(File.exist?(File.join(dir, "bar.yml")))
      refute(File.exist?(File.join(dir, "foo.txt")))
    end

    it "honors --dry-run" do
      dir = workspace_dir
      FileUtils.touch(File.join(dir, "foo.txt"))
      FileUtils.touch(File.join(dir, "bar.yml"))
      loader.add_block do
        set_context_directory dir
        expand :clean, paths: "*.txt"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("clean", "--dry-run"))
      end
      assert_equal("Cleaned: foo.txt\n", out)
      assert(File.exist?(File.join(dir, "bar.yml")))
      assert(File.exist?(File.join(dir, "foo.txt")))
    end

    it "cleans gitignore" do
      dir = workspace_dir
      FileUtils.touch(File.join(dir, "foo.txt"))
      FileUtils.touch(File.join(dir, "Gemfile.lock"))
      FileUtils.mkdir(File.join(dir, "tmp"))
      FileUtils.touch(File.join(dir, "tmp", "bar.txt"))
      FileUtils.mkdir(File.join(dir, "hello"))
      FileUtils.touch(File.join(dir, "hello", "baz.txt"))
      FileUtils.touch(File.join(dir, "hello", "Gemfile.lock"))
      loader.add_block do
        set_context_directory dir
        expand :clean, paths: :gitignore
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("clean"))
      end
      expected_output = <<~STR
        Cleaned: Gemfile.lock
        Cleaned: hello/Gemfile.lock
        Cleaned: tmp/bar.txt
        Cleaned: tmp
      STR
      assert_equal(expected_output, out)
      assert(File.exist?(File.join(dir, "foo.txt")))
      assert(File.exist?(File.join(dir, "hello", "baz.txt")))
      refute(File.exist?(File.join(dir, "Gemfile.lock")))
      refute(File.exist?(File.join(dir, "tmp")))
      refute(File.exist?(File.join(dir, "hello", "Gemfile.lock")))
    end

    it "cleans a pattern but preserves matching files" do
      dir = workspace_dir
      FileUtils.touch(File.join(dir, "foo.txt"))
      FileUtils.touch(File.join(dir, "bar.txt"))
      FileUtils.touch(File.join(dir, "baz.yml"))
      loader.add_block do
        set_context_directory dir
        expand :clean, paths: "*.txt", preserve: "bar.*"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("clean"))
      end
      assert_equal("Cleaned: foo.txt\n", out)
      refute(File.exist?(File.join(dir, "foo.txt")))
      assert(File.exist?(File.join(dir, "bar.txt")))
      assert(File.exist?(File.join(dir, "baz.yml")))
    end

    it "cleans a directory but preserves certain contents" do
      dir = workspace_dir
      FileUtils.mkdir(File.join(dir, "subdir"))
      FileUtils.touch(File.join(dir, "foo.txt"))
      FileUtils.touch(File.join(dir, "subdir", "bar.txt"))
      FileUtils.touch(File.join(dir, "subdir", "baz.yml"))
      loader.add_block do
        set_context_directory dir
        expand :clean, paths: "subdir", preserve: "subdir/bar.*"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("clean"))
      end
      assert_equal("Cleaned: subdir/baz.yml\n", out)
      assert(File.exist?(File.join(dir, "foo.txt")))
      assert(File.exist?(File.join(dir, "subdir", "bar.txt")))
      refute(File.exist?(File.join(dir, "subdir", "baz.yml")))
    end

    it "cleans gitignore but preserves some files" do
      dir = workspace_dir
      FileUtils.touch(File.join(dir, "foo.txt"))
      FileUtils.touch(File.join(dir, "Gemfile.lock"))
      FileUtils.mkdir(File.join(dir, "tmp"))
      FileUtils.touch(File.join(dir, "tmp", "bar.txt"))
      FileUtils.mkdir(File.join(dir, "hello"))
      FileUtils.touch(File.join(dir, "hello", "baz.txt"))
      FileUtils.touch(File.join(dir, "hello", "Gemfile.lock"))
      loader.add_block do
        set_context_directory dir
        expand :clean, paths: :gitignore, preserve: ["**/bar.txt", "hello"]
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("clean"))
      end
      assert_equal("Cleaned: Gemfile.lock\n", out)
      refute(File.exist?(File.join(dir, "Gemfile.lock")))
      assert(File.exist?(File.join(dir, "tmp")))
      assert(File.exist?(File.join(dir, "tmp", "bar.txt")))
      assert(File.exist?(File.join(dir, "hello", "Gemfile.lock")))
    end

    it "honors context_directory argument" do
      dir = workspace_dir
      FileUtils.touch(File.join(dir, "foo.txt"))
      FileUtils.touch(File.join(dir, "bar.yml"))
      loader.add_block do
        expand :clean, paths: "*.txt", context_directory: dir
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("clean"))
      end
      assert_equal("Cleaned: foo.txt\n", out)
      assert(File.exist?(File.join(dir, "bar.yml")))
      refute(File.exist?(File.join(dir, "foo.txt")))
    end
  end
end
