# frozen_string_literal: true

require_relative "helper"

require "tmpdir"
require "fileutils"

describe "toys release reserve-gem" do
  include Toys::Testing

  let(:temp_dir) { ::Dir.mktmpdir }
  let(:gem_name) { "my-gem" }
  let(:contact) { "me@example.com" }
  let(:base_cmd) { ["reserve-gem", "-d", temp_dir, "-y", "--dry-run", "-v"] }

  after do
    ::FileUtils.remove_entry(temp_dir)
  end

  it "creates a buildable gem" do
    code = nil
    out, err = capture_subprocess_io do
      code = toys_run_tool(base_cmd + ["my-gem", contact])
    end
    assert_equal(0, code)
    assert_includes(out, "Reserved gem my-gem 0.0.0")
    assert_includes(err, "Gem built to pkg/my-gem-0.0.0.gem")
    assert_includes(err, "Pushed my-gem 0.0.0 (DRY RUN)")
    assert(File.file?("#{temp_dir}/pkg/my-gem-0.0.0.gem"))

    gemspec_content = File.read("#{temp_dir}/my-gem.gemspec")
    readme_content = File.read("#{temp_dir}/README.md")
    entrypoint_content = File.read("#{temp_dir}/lib/my-gem.rb")
    assert_includes(gemspec_content, 'spec.name = "my-gem"')
    assert_includes(gemspec_content, 'spec.version = "0.0.0"')
    assert_includes(readme_content, 'reserve the gem "my-gem"')
    assert_includes(readme_content, "`me@example.com`")
    assert_includes(entrypoint_content, 'Ruby file for gem "my-gem"')
    assert_includes(entrypoint_content, "# me@example.com")
  end

  it "honors --gem-version" do
    code = nil
    out, err = capture_subprocess_io do
      code = toys_run_tool(base_cmd + ["--gem-version=0.0.1", "my-gem", contact])
    end
    assert_equal(0, code)
    assert_includes(out, "Reserved gem my-gem 0.0.1")
    assert_includes(err, "Gem built to pkg/my-gem-0.0.1.gem")
    assert_includes(err, "Pushed my-gem 0.0.1 (DRY RUN)")
    assert(File.file?("#{temp_dir}/pkg/my-gem-0.0.1.gem"))

    gemspec_content = File.read("#{temp_dir}/my-gem.gemspec")
    readme_content = File.read("#{temp_dir}/README.md")
    entrypoint_content = File.read("#{temp_dir}/lib/my-gem.rb")
    assert_includes(gemspec_content, 'spec.name = "my-gem"')
    assert_includes(gemspec_content, 'spec.version = "0.0.1"')
    assert_includes(readme_content, 'reserve the gem "my-gem"')
    assert_includes(readme_content, "`me@example.com`")
    assert_includes(entrypoint_content, 'Ruby file for gem "my-gem"')
    assert_includes(entrypoint_content, "# me@example.com")
  end

  describe "error checks" do
    it "checks for illegal gem name" do
      code = nil
      _out, err = capture_subprocess_io do
        code = toys_run_tool(base_cmd + ["my@gem", contact])
      end
      assert_equal(1, code)
      assert_includes(err, 'Illegal gem name: "my@gem"')
      refute_includes(err, "Generating placeholder gem")
    end

    it "checks for illegal contact" do
      code = nil
      _out, err = capture_subprocess_io do
        code = toys_run_tool(base_cmd + ["my-gem", "\n"])
      end
      assert_equal(1, code)
      assert_includes(err, "Contact info is required")
      refute_includes(err, "Generating placeholder gem")
    end

    it "checks for illegal gem version" do
      code = nil
      _out, err = capture_subprocess_io do
        code = toys_run_tool(base_cmd + ["--gem-version=a.0.0", "my-gem", contact])
      end
      assert_equal(1, code)
      assert_includes(err, "Placeholder gem version must start with 0.")
      refute_includes(err, "Generating placeholder gem")
    end
  end
end
