# frozen_string_literal: true

require "helper"

describe "minitest template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }

  describe "unit functionality" do
    let(:template) { template_lookup.lookup(:minitest).new }

    it "handles the name field" do
      assert_equal("test", template.name)
      template.name = "hi"
      assert_equal("hi", template.name)
      template.name = nil
      assert_equal("test", template.name)
    end

    it "handles the libs field" do
      assert_equal(["lib"], template.libs)
      template.libs = "src"
      assert_equal(["src"], template.libs)
      template.libs = ["src", "lib"]
      assert_equal(["src", "lib"], template.libs)
      template.libs = nil
      assert_equal(["lib"], template.libs)
    end

    it "handles the files field" do
      assert_equal(["test/**/test*.rb"], template.files)
      template.files = "test/**/*_test.rb"
      assert_equal(["test/**/*_test.rb"], template.files)
      template.files = ["test/**/test*.rb", "spec/**/test*.rb"]
      assert_equal(["test/**/test*.rb", "spec/**/test*.rb"], template.files)
      template.files = nil
      assert_equal(["test/**/test*.rb"], template.files)
    end

    it "handles the gem_version field without bundler" do
      assert_equal(["~> 5.0"], template.gem_version)
      template.gem_version = "~> 5.1"
      assert_equal(["~> 5.1"], template.gem_version)
      template.gem_version = ["~> 5.14.0", "< 6.0"]
      assert_equal(["~> 5.14.0", "< 6.0"], template.gem_version)
      template.gem_version = nil
      assert_equal(["~> 5.0"], template.gem_version)
    end

    it "handles the gem_version field with bundler" do
      template.use_bundler
      assert_equal([], template.gem_version)
      template.gem_version = "~> 5.1"
      assert_equal(["~> 5.1"], template.gem_version)
      template.gem_version = ["~> 5.14.0", "< 6.0"]
      assert_equal(["~> 5.14.0", "< 6.0"], template.gem_version)
      template.gem_version = nil
      assert_equal([], template.gem_version)
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
  end

  describe "integration functionality" do
    let(:cli) { Toys::CLI.new(middleware_stack: [], template_lookup: template_lookup) }
    let(:loader) { cli.loader }
    let(:cases_dir) { File.join(__dir__, "minitest-cases") }

    it "runs passing tests" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "passing/*.rb"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("test"))
      end
      assert_match(/0 failures/, out)
    end

    it "runs failing tests" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "failing/*.rb"
      end
      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("test"))
      end
      assert_match(/1 failure/, out)
    end
  end
end
