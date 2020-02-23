# frozen_string_literal: true

require "helper"

describe "rspec template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }

  describe "unit functionality" do
    let(:template) { template_lookup.lookup(:rspec).new }

    it "handles the name field" do
      assert_equal("spec", template.name)
      template.name = "hi"
      assert_equal("hi", template.name)
      template.name = nil
      assert_equal("spec", template.name)
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

    it "handles the gem_version field without bundler" do
      assert_equal(["~> 3.1"], template.gem_version)
      template.gem_version = "~> 5.1"
      assert_equal(["~> 5.1"], template.gem_version)
      template.gem_version = ["~> 5.14.0", "< 6.0"]
      assert_equal(["~> 5.14.0", "< 6.0"], template.gem_version)
      template.gem_version = nil
      assert_equal(["~> 3.1"], template.gem_version)
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

    it "executes a successful spec" do
      cases_dir = File.join(__dir__, "rspec-cases")
      loader.add_block do
        expand :rspec, libs: File.join(cases_dir, "lib1"),
                       pattern: File.join(cases_dir, "spec", "*_spec.rb")
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("spec"))
      end
      assert_match(/1 example, 0 failures/, out)
    end

    it "executes an unsuccessful spec" do
      cases_dir = File.join(__dir__, "rspec-cases")
      loader.add_block do
        expand :rspec, libs: File.join(cases_dir, "lib2"),
                       pattern: File.join(cases_dir, "spec", "*_spec.rb")
      end
      out, _err = capture_subprocess_io do
        refute_equal(0, cli.run("spec"))
      end
      assert_match(/1 example, 1 failure/, out)
    end
  end
end
