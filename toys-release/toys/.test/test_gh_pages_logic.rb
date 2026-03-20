# frozen_string_literal: true

require_relative "helper"
require "fileutils"
require "tmpdir"

describe Toys::Release::GhPagesLogic do
  # Path to the real gh-pages ERB templates
  let(:template_dir) { ::File.expand_path("../.data/gh-pages", __dir__) }

  # Build a minimal RepoSettings from an inline hash.
  # +components+ is an array of hashes with keys: name, gh_pages_enabled,
  # gh_pages_directory, gh_pages_version_var.
  def make_repo_settings(repo: "testowner/testrepo", components: [])
    component_list = components.map do |c|
      {
        "name" => c.fetch(:name),
        "gh_pages_enabled" => c.fetch(:gh_pages_enabled, true),
        "gh_pages_directory" => c[:gh_pages_directory],
        "gh_pages_version_var" => c[:gh_pages_version_var],
      }.compact
    end
    Toys::Release::RepoSettings.new(
      "repo" => repo,
      "components" => component_list
    )
  end

  # Yield a temporary directory path, cleaning it up afterward.
  def with_temp_dir
    dir = ::Dir.mktmpdir
    begin
      yield dir
    ensure
      ::FileUtils.remove_entry(dir, true)
    end
  end

  it "errors on construction when no components have gh-pages enabled" do
    settings = make_repo_settings(components: [{name: "mylib", gh_pages_enabled: false}])
    assert_raises(ArgumentError) do
      Toys::Release::GhPagesLogic.new(settings)
    end
  end

  describe "generate_files" do
    # Helpers that always confirm writes so content tests can focus on content
    def always_confirm
      proc { |_dest, _status, _ftype| true }
    end

    def run_generate(logic, dir)
      logic.generate_files(dir, template_dir, &always_confirm)
    end

    def read_file(dir, *path_parts)
      ::File.read(::File.join(dir, *path_parts))
    end

    it "generates redirect content with the correct URL in all three locations" do
      settings = make_repo_settings(
        repo: "myowner/myrepo",
        components: [{name: "mylib", gh_pages_directory: "mylib", gh_pages_version_var: "version_mylib"}]
      )
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        run_generate(logic, dir)
        redirect_url = "https://myowner.github.io/myrepo/mylib/v0"
        content = read_file(dir, "mylib", "index.html")
        assert_includes(content, " href=\"#{redirect_url}\"")
        assert_includes(content, " content=\"0; url=#{redirect_url}\"")
        assert_includes(content, "window.location.replace(\"#{redirect_url}\")")
      end
    end

    it "generates the same redirect content for index.html and latest/index.html" do
      settings = make_repo_settings(
        repo: "myowner/myrepo",
        components: [{name: "mylib", gh_pages_directory: "mylib", gh_pages_version_var: "version_mylib"}]
      )
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        run_generate(logic, dir)
        assert_equal(read_file(dir, "mylib", "index.html"), read_file(dir, "mylib", "latest", "index.html"))
      end
    end

    it "uses the highest existing versioned directory as the redirect target" do
      settings = make_repo_settings(
        repo: "myowner/myrepo",
        components: [{name: "mylib", gh_pages_directory: "mylib", gh_pages_version_var: "version_mylib"}]
      )
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        # Simulate existing versioned doc dirs
        ::FileUtils.mkdir_p(::File.join(dir, "mylib", "v1.2.3"))
        ::FileUtils.mkdir_p(::File.join(dir, "mylib", "v1.10.0"))
        ::FileUtils.mkdir_p(::File.join(dir, "mylib", "v0.9.0"))
        run_generate(logic, dir)
        assert_includes(read_file(dir, "mylib", "index.html"), "/mylib/v1.10.0\"")
      end
    end

    it "generates empty.html placeholder for the v0 index with the component name" do
      settings = make_repo_settings(
        components: [{name: "mylib", gh_pages_directory: "mylib", gh_pages_version_var: "version_mylib"}]
      )
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        run_generate(logic, dir)
        content = read_file(dir, "mylib", "v0", "index.html")
        assert_includes(content, "mylib")
      end
    end

    it "generates an empty .nojekyll file" do
      settings = make_repo_settings(components: [{name: "mylib", gh_pages_directory: "mylib"}])
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        run_generate(logic, dir)
        assert_equal("", read_file(dir, ".nojekyll"))
      end
    end

    it "generates a .gitignore file" do
      settings = make_repo_settings(components: [{name: "mylib", gh_pages_directory: "mylib"}])
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        run_generate(logic, dir)
        assert(::File.file?(::File.join(dir, ".gitignore")))
        refute_empty(read_file(dir, ".gitignore"))
      end
    end

    it "generates a root index.html redirect to the first component when no root component" do
      settings = make_repo_settings(
        repo: "myowner/myrepo",
        components: [
          {name: "alpha", gh_pages_directory: "alpha", gh_pages_version_var: "version_alpha"},
          {name: "beta", gh_pages_directory: "beta", gh_pages_version_var: "version_beta"},
        ]
      )
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        run_generate(logic, dir)
        content = read_file(dir, "index.html")
        assert_includes(content, "myowner.github.io/myrepo/alpha/latest")
      end
    end

    it "does not generate an extra default root redirect when a component has gh_pages_directory '.'" do
      settings = make_repo_settings(
        repo: "myowner/myrepo",
        components: [{name: "mylib", gh_pages_directory: ".", gh_pages_version_var: "version_mylib"}]
      )
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        run_generate(logic, dir)
        # root index.html is the component's own redirect (to its versioned dir),
        # not the generic "redirect to first component's /latest"
        content = read_file(dir, "index.html")
        refute_includes(content, "/latest")
        assert_includes(content, "myowner.github.io/myrepo/v0")
      end
    end

    it "generates 404.html with version var assignment for a single component" do
      settings = make_repo_settings(
        repo: "myowner/myrepo",
        components: [{name: "mylib", gh_pages_directory: "mylib", gh_pages_version_var: "version_mylib"}]
      )
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        run_generate(logic, dir)
        content = read_file(dir, "404.html")
        assert_includes(content, 'var version_mylib = "0"')
      end
    end

    it "generates 404.html that uses the highest existing version" do
      settings = make_repo_settings(
        repo: "myowner/myrepo",
        components: [{name: "mylib", gh_pages_directory: "mylib", gh_pages_version_var: "version_mylib"}]
      )
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        ::FileUtils.mkdir_p(::File.join(dir, "mylib", "v2.0.0"))
        run_generate(logic, dir)
        content = read_file(dir, "404.html")
        assert_includes(content, 'var version_mylib = "2.0.0"')
      end
    end

    it "generates 404.html with all component version vars for multiple components" do
      settings = make_repo_settings(
        repo: "myowner/myrepo",
        components: [
          {name: "alpha", gh_pages_directory: "alpha", gh_pages_version_var: "version_alpha"},
          {name: "beta", gh_pages_directory: "beta", gh_pages_version_var: "version_beta"},
        ]
      )
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        run_generate(logic, dir)
        content = read_file(dir, "404.html")
        assert_includes(content, "version_alpha")
        assert_includes(content, "version_beta")
      end
    end

    it "generates 404.html with a regexp matching the /latest/ path for each component" do
      settings = make_repo_settings(
        repo: "myowner/myrepo",
        components: [{name: "mylib", gh_pages_directory: "mylib", gh_pages_version_var: "version_mylib"}]
      )
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        run_generate(logic, dir)
        content = read_file(dir, "404.html")
        assert_includes(content, "myowner.github.io/myrepo/mylib/latest")
      end
    end

    it "uses the base path (no subdir) for a component with gh_pages_directory '.'" do
      settings = make_repo_settings(
        repo: "myowner/myrepo",
        components: [{name: "mylib", gh_pages_directory: ".", gh_pages_version_var: "version_mylib"}]
      )
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        run_generate(logic, dir)
        # The 404 should reference the base URL (no subdir)
        content = read_file(dir, "404.html")
        assert_includes(content, "myowner.github.io/myrepo/latest")
        refute_includes(content, "myowner.github.io/myrepo/./latest")
      end
    end
  end

  describe "update_version_pages" do
    def make_settings(gh_pages_directory: "mylib", gh_pages_version_var: "version_mylib")
      make_repo_settings(
        repo: "myowner/myrepo",
        components: [{
          name: "mylib",
          gh_pages_directory: gh_pages_directory,
          gh_pages_version_var: gh_pages_version_var,
        }]
      )
    end

    # Build a 404.html in the temp dir that looks like what generate_files produces,
    # so update_version_pages has something realistic to update.
    def write_html404(dir, settings)
      logic = Toys::Release::GhPagesLogic.new(settings)
      logic.generate_files(dir, template_dir) { |_d, _s, _f| true }
    end

    it "updates the version variable in 404.html" do
      settings = make_settings
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        write_html404(dir, settings)
        logic.update_version_pages(dir, settings.component_settings("mylib"), ::Gem::Version.new("1.2.3"))
        content = ::File.read(::File.join(dir, "404.html"))
        assert_includes(content, 'var version_mylib = "1.2.3";')
        refute_includes(content, 'var version_mylib = "0";')
      end
    end

    it "updates all three redirect patterns in index.html" do
      settings = make_settings
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        write_html404(dir, settings)
        logic.update_version_pages(dir, settings.component_settings("mylib"), ::Gem::Version.new("2.0.0"))
        content = ::File.read(::File.join(dir, "mylib", "index.html"))
        expected_url = "https://myowner.github.io/myrepo/mylib/v2.0.0"
        assert_includes(content, " href=\"#{expected_url}\"")
        assert_includes(content, " content=\"0; url=#{expected_url}\"")
        assert_includes(content, "window.location.replace(\"#{expected_url}\")")
      end
    end

    it "updates all three redirect patterns in latest/index.html" do
      settings = make_settings
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        write_html404(dir, settings)
        logic.update_version_pages(dir, settings.component_settings("mylib"), ::Gem::Version.new("2.0.0"))
        content = ::File.read(::File.join(dir, "mylib", "latest", "index.html"))
        expected_url = "https://myowner.github.io/myrepo/mylib/v2.0.0"
        assert_includes(content, " href=\"#{expected_url}\"")
        assert_includes(content, " content=\"0; url=#{expected_url}\"")
        assert_includes(content, "window.location.replace(\"#{expected_url}\")")
      end
    end

    it "uses the base URL (no subdir) for a root component (gh_pages_directory '.')" do
      settings = make_settings(gh_pages_directory: ".", gh_pages_version_var: "version_mylib")
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        write_html404(dir, settings)
        logic.update_version_pages(dir, settings.component_settings("mylib"), ::Gem::Version.new("3.0.0"))
        content = ::File.read(::File.join(dir, "index.html"))
        expected_url = "https://myowner.github.io/myrepo/v3.0.0"
        assert_includes(content, " href=\"#{expected_url}\"")
      end
    end

    it "yields a warning and skips when 404.html is missing" do
      settings = make_settings
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        warnings = []
        logic.update_version_pages(dir, settings.component_settings("mylib"),
                                   ::Gem::Version.new("1.0.0")) { |w| warnings << w }
        assert_equal(1, warnings.grep(/404\.html/).size)
      end
    end

    it "yields a warning and skips when index.html is missing" do
      settings = make_settings
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        write_html404(dir, settings)
        ::File.delete(::File.join(dir, "mylib", "index.html"))
        warnings = []
        logic.update_version_pages(dir, settings.component_settings("mylib"),
                                   ::Gem::Version.new("1.0.0")) { |w| warnings << w }
        assert_equal(1, warnings.size)
        assert_includes(warnings.first, "index.html")
      end
    end

    it "yields a warning and skips when latest/index.html is missing" do
      settings = make_settings
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        write_html404(dir, settings)
        ::File.delete(::File.join(dir, "mylib", "latest", "index.html"))
        warnings = []
        logic.update_version_pages(dir, settings.component_settings("mylib"),
                                   ::Gem::Version.new("1.0.0")) { |w| warnings << w }
        assert_equal(1, warnings.size)
        assert_includes(warnings.first, "latest/index.html")
      end
    end

    it "does not raise when no block is given and a file is missing" do
      settings = make_settings
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        # All files missing, no block — should complete without error
        logic.update_version_pages(dir, settings.component_settings("mylib"), ::Gem::Version.new("1.0.0"))
        pass
      end
    end
  end

  describe "generate_files callback and results" do
    def single_component_settings
      make_repo_settings(
        repo: "myowner/myrepo",
        components: [{name: "mylib", gh_pages_directory: "mylib", gh_pages_version_var: "version_mylib"}]
      )
    end

    it "calls the block with :new and nil ftype for a new file" do
      logic = Toys::Release::GhPagesLogic.new(single_component_settings)
      with_temp_dir do |dir|
        calls = []
        logic.generate_files(dir, template_dir) do |_dest, status, ftype|
          calls << [status, ftype]
          true
        end
        assert(calls.all? { |status, _ftype| status == :new })
        assert(calls.all? { |_status, ftype| ftype.nil? })
      end
    end

    it "returns :wrote outcome when block returns true for a new file" do
      logic = Toys::Release::GhPagesLogic.new(single_component_settings)
      with_temp_dir do |dir|
        results = logic.generate_files(dir, template_dir) { |_d, _s, _f| true }
        assert(results.all? { |r| r[:outcome] == :wrote })
      end
    end

    it "returns :skipped outcome and does not write when block returns false" do
      logic = Toys::Release::GhPagesLogic.new(single_component_settings)
      with_temp_dir do |dir|
        results = logic.generate_files(dir, template_dir) { |_d, _s, _f| false }
        assert(results.all? { |r| r[:outcome] == :skipped })
        refute(::File.exist?(::File.join(dir, "mylib")))
      end
    end

    it "returns :unchanged outcome and does not call block for an existing file with identical content" do
      logic = Toys::Release::GhPagesLogic.new(single_component_settings)
      with_temp_dir do |dir|
        # First pass writes all files
        logic.generate_files(dir, template_dir) { |_d, _s, _f| true }
        # Second pass: unchanged files must not call block
        block_calls = []
        results = logic.generate_files(dir, template_dir) do |dest, _status, _ftype|
          block_calls << dest
          true
        end
        unchanged = results.select { |r| r[:outcome] == :unchanged }
        assert_equal(results.size, unchanged.size, "Expected all outcomes to be :unchanged")
        assert_empty(block_calls, "Block should not be called for unchanged files")
      end
    end

    it "calls the block with :overwrite and ftype 'file' for an existing file with different content" do
      logic = Toys::Release::GhPagesLogic.new(single_component_settings)
      with_temp_dir do |dir|
        nojekyll = ::File.join(dir, ".nojekyll")
        ::FileUtils.mkdir_p(dir)
        ::File.write(nojekyll, "different content")
        overwrite_calls = []
        logic.generate_files(dir, template_dir) do |dest, status, ftype|
          overwrite_calls << [dest, status, ftype] if status == :overwrite
          true
        end
        nojekyll_call = overwrite_calls.find { |dest, _s, _f| dest == ".nojekyll" }
        assert(nojekyll_call, "Expected block to be called with :overwrite for .nojekyll")
        assert_equal(:overwrite, nojekyll_call[1])
        assert_equal("file", nojekyll_call[2])
      end
    end

    it "returns :wrote when block returns true for an overwrite" do
      logic = Toys::Release::GhPagesLogic.new(single_component_settings)
      with_temp_dir do |dir|
        nojekyll = ::File.join(dir, ".nojekyll")
        ::FileUtils.mkdir_p(dir)
        ::File.write(nojekyll, "different content")
        results = logic.generate_files(dir, template_dir) { |_d, _s, _f| true }
        nojekyll_result = results.find { |r| r[:destination] == ".nojekyll" }
        assert_equal(:wrote, nojekyll_result[:outcome])
        assert_equal("", ::File.read(nojekyll))
      end
    end

    it "returns :skipped when block returns false for an overwrite" do
      logic = Toys::Release::GhPagesLogic.new(single_component_settings)
      with_temp_dir do |dir|
        nojekyll = ::File.join(dir, ".nojekyll")
        ::FileUtils.mkdir_p(dir)
        ::File.write(nojekyll, "different content")
        results = logic.generate_files(dir, template_dir) { |_d, _s, _f| false }
        nojekyll_result = results.find { |r| r[:destination] == ".nojekyll" }
        assert_equal(:skipped, nojekyll_result[:outcome])
        assert_equal("different content", ::File.read(nojekyll))
      end
    end

    it "calls the block with :overwrite and the ftype for a non-file at the destination" do
      logic = Toys::Release::GhPagesLogic.new(single_component_settings)
      with_temp_dir do |dir|
        nojekyll = ::File.join(dir, ".nojekyll")
        ::FileUtils.mkdir_p(nojekyll) # make it a directory
        overwrite_calls = []
        logic.generate_files(dir, template_dir) do |dest, status, ftype|
          overwrite_calls << [dest, status, ftype] if status == :overwrite
          true
        end
        nojekyll_call = overwrite_calls.find { |dest, _s, _f| dest == ".nojekyll" }
        assert(nojekyll_call)
        assert_equal("directory", nojekyll_call[2])
      end
    end

    it "includes a result entry for every file, in order" do
      logic = Toys::Release::GhPagesLogic.new(single_component_settings)
      with_temp_dir do |dir|
        results = logic.generate_files(dir, template_dir) { |_d, _s, _f| true }
        # single component with explicit gh_pages_directory generates:
        # v0/index.html, index.html, latest/index.html (component files)
        # .nojekyll, .gitignore, index.html (toplevel: root redirect)
        # 404.html
        assert_equal(7, results.size)
        assert(results.all? { |r| r.key?(:destination) && r.key?(:outcome) })
      end
    end
  end

  describe "cleanup_v0_directories" do
    it "creates the v0 directory if it does not exist" do
      settings = make_repo_settings(components: [{name: "mylib", gh_pages_directory: "mylib"}])
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        logic.cleanup_v0_directories(dir) { |_dir, _children| false }
        assert(::File.directory?(::File.join(dir, "mylib", "v0")))
      end
    end

    it "does not call the block when v0 dir has only index.html" do
      settings = make_repo_settings(components: [{name: "mylib", gh_pages_directory: "mylib"}])
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        v0_dir = ::File.join(dir, "mylib", "v0")
        ::FileUtils.mkdir_p(v0_dir)
        ::File.write(::File.join(v0_dir, "index.html"), "")
        block_called = false
        results = logic.cleanup_v0_directories(dir) do |_d, _c|
          block_called = true
          false
        end
        assert_equal(false, block_called)
        assert_equal(1, results.size)
        assert_equal([], results.first[:children])
        assert_equal(false, results.first[:removed])
      end
    end

    it "does not call the block when v0 dir is empty" do
      settings = make_repo_settings(components: [{name: "mylib", gh_pages_directory: "mylib"}])
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        v0_dir = ::File.join(dir, "mylib", "v0")
        ::FileUtils.mkdir_p(v0_dir)
        block_called = false
        results = logic.cleanup_v0_directories(dir) do |_d, _c|
          block_called = true
          false
        end
        assert_equal(false, block_called)
        assert_equal([], results.first[:children])
        assert_equal(false, results.first[:removed])
      end
    end

    it "calls the block with directory and children when extra files exist" do
      settings = make_repo_settings(components: [{name: "mylib", gh_pages_directory: "mylib"}])
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        v0_dir = ::File.join(dir, "mylib", "v0")
        ::FileUtils.mkdir_p(v0_dir)
        ::File.write(::File.join(v0_dir, "index.html"), "")
        ::File.write(::File.join(v0_dir, "extra.html"), "")
        yielded_dir = nil
        yielded_children = nil
        logic.cleanup_v0_directories(dir) do |d, c|
          yielded_dir = d
          yielded_children = c
          false
        end
        assert_equal("mylib/v0", yielded_dir)
        assert_equal(["extra.html"], yielded_children)
      end
    end

    it "removes extra files when the block returns true" do
      settings = make_repo_settings(components: [{name: "mylib", gh_pages_directory: "mylib"}])
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        v0_dir = ::File.join(dir, "mylib", "v0")
        ::FileUtils.mkdir_p(v0_dir)
        ::File.write(::File.join(v0_dir, "index.html"), "")
        ::File.write(::File.join(v0_dir, "extra.html"), "")
        results = logic.cleanup_v0_directories(dir) { |_d, _c| true }
        assert_equal(true, results.first[:removed])
        assert_equal(["index.html"], ::Dir.children(v0_dir))
      end
    end

    it "keeps extra files when the block returns false" do
      settings = make_repo_settings(components: [{name: "mylib", gh_pages_directory: "mylib"}])
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        v0_dir = ::File.join(dir, "mylib", "v0")
        ::FileUtils.mkdir_p(v0_dir)
        ::File.write(::File.join(v0_dir, "index.html"), "")
        ::File.write(::File.join(v0_dir, "extra.html"), "")
        results = logic.cleanup_v0_directories(dir) { |_d, _c| false }
        assert_equal(false, results.first[:removed])
        assert_equal(2, ::Dir.children(v0_dir).size)
      end
    end

    it "processes multiple enabled components and returns one result per component" do
      settings = make_repo_settings(
        components: [
          {name: "alpha"},
          {name: "beta", gh_pages_enabled: false},
          {name: "gamma"},
        ]
      )
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        results = logic.cleanup_v0_directories(dir) { |_d, _c| false }
        assert_equal(2, results.size)
        assert(::File.directory?(::File.join(dir, "alpha", "v0")))
        assert(::File.directory?(::File.join(dir, "gamma", "v0")))
        refute(::File.exist?(::File.join(dir, "beta")))
      end
    end

    it "includes the v0 directory path in the result" do
      settings = make_repo_settings(components: [{name: "mylib", gh_pages_directory: "mylib"}])
      logic = Toys::Release::GhPagesLogic.new(settings)
      with_temp_dir do |dir|
        results = logic.cleanup_v0_directories(dir)
        assert_equal("mylib/v0", results.first[:directory])
      end
    end
  end
end
