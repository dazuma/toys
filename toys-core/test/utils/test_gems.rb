# frozen_string_literal: true

require "helper"
require "bundler"
require "fileutils"
require "stringio"
require "timeout"
require "tmpdir"
require "toys/utils/exec"
require "toys/utils/gems"

describe Toys::Utils::Gems do
  let(:gem_base_dir) { File.dirname(File.dirname(__dir__)) }
  let(:gem_gemfile_path) { File.join(gem_base_dir, "Gemfile") }
  let(:gems_cases_dir) { File.join(gem_base_dir, "test-data", "gems-cases") }
  let(:exec_service) { Toys::Utils::Exec.new }

  # A minimal stand-in for a Gem::Specification. Both name and version must be
  # set: a bare Gem::Specification.new leaves version nil, and the generated
  # gem line would then read "'= '".
  def fake_spec(name, version)
    spec = Gem::Specification.new
    spec.name = name
    spec.version = version
    spec
  end

  # Point BUNDLE_GEMFILE at a sentinel path that is not the gemfile under test,
  # so the on_conflict paths are reached deterministically rather than relying
  # on BUNDLE_GEMFILE happening to be set ambiently. If that ambient invariant
  # ever failed, these tests would fall through into real bundler setup.
  def with_conflicting_bundle_gemfile
    old_path = ENV["BUNDLE_GEMFILE"]
    Dir.mktmpdir do |dir|
      gemfile_path = File.join(dir, "Gemfile")
      File.write(gemfile_path, "source \"https://rubygems.org\"\n")
      sentinel = File.join(dir, "sentinel-Gemfile")
      ENV["BUNDLE_GEMFILE"] = sentinel
      begin
        yield gemfile_path, sentinel
      ensure
        ENV["BUNDLE_GEMFILE"] = old_path
      end
    end
  end

  describe ".find_gemfile" do
    it "searches default gemfile name list" do
      names = Toys::Utils::Gems::DEFAULT_GEMFILE_NAMES
      assert_equal([".gems.rb", "gems.rb", "Gemfile"], names)
      names.each_with_index do |expected, index|
        Dir.mktmpdir do |dir|
          names[index..].each { |name| File.write(File.join(dir, name), "") }
          assert_equal(File.join(dir, expected), Toys::Utils::Gems.find_gemfile(dir))
        end
      end
    end

    it "searches a custom gemfile name list" do
      Dir.mktmpdir do |dir|
        # A custom list that skips gems.rb entirely: the one case the loop above
        # cannot express.
        custom_names = [".gems.rb", "Gemfile"]
        File.write(File.join(dir, "gems.rb"), "")
        File.write(File.join(dir, "Gemfile"), "")
        assert_equal(File.join(dir, "Gemfile"),
                     Toys::Utils::Gems.find_gemfile(dir, gemfile_names: custom_names))
        assert_nil(Toys::Utils::Gems.find_gemfile(dir, gemfile_names: []))
      end
    end

    it "handles edge cases" do
      Dir.mktmpdir do |dir|
        assert_nil(Toys::Utils::Gems.find_gemfile(dir))
        # Degenerate: Array("") is [""], so File.join(dir, "") is the directory
        # itself with a trailing slash, which is not a file.
        assert_nil(Toys::Utils::Gems.find_gemfile(dir, gemfile_names: ""))
        # A directory named Gemfile is not a file
        Dir.mkdir(File.join(dir, "Gemfile"))
        assert_nil(Toys::Utils::Gems.find_gemfile(dir))
      end
    end
  end

  describe "#find_lockfile_path" do
    it "locates the lockfile next to the gemfile" do
      gems = Toys::Utils::Gems.new
      # These two mirror Bundler.default_lockfile.
      assert_equal("/a/gems.locked", gems.send(:find_lockfile_path, "/a/gems.rb"))
      assert_equal("/a/Gemfile.lock", gems.send(:find_lockfile_path, "/a/Gemfile"))
      # This one does not: bundler's discovery never yields .gems.rb, so this
      # row is toys-only policy.
      assert_equal("/a/.gems.rb.lock", gems.send(:find_lockfile_path, "/a/.gems.rb"))
    end
  end

  describe "#custom_lib_paths" do
    it "maps toys and toys-core only when TOYS_DEV is set" do
      old_dev = ENV["TOYS_DEV"]
      begin
        # Build a fresh Gems after each change: custom_lib_paths memoizes.
        ENV["TOYS_DEV"] = nil
        assert_empty(Toys::Utils::Gems.new.send(:custom_lib_paths))
        ENV["TOYS_DEV"] = "true"
        paths = Toys::Utils::Gems.new.send(:custom_lib_paths)
        assert_equal(["toys", "toys-core"], paths.keys.sort)
        # This encodes *this repo's* layout, where CORE_LIB_PATH is
        # <repo>/toys-core/lib. For an installed gem the two would differ.
        assert_equal(File.dirname(Toys::CORE_LIB_PATH), paths["toys-core"])
        assert(File.directory?(paths["toys-core"]))
        assert(File.directory?(paths["toys"]))
        # The switch is truthiness, not == "true".
        ENV["TOYS_DEV"] = ""
        refute_empty(Toys::Utils::Gems.new.send(:custom_lib_paths))
      ensure
        ENV["TOYS_DEV"] = old_dev
      end
    end
  end

  describe "#modified_gemfile_content" do
    it "appends sorted gem pins after the original content" do
      # Deliberately out of order, so sort_by is not the identity here.
      specs = [fake_spec("zzz", "1.0"), fake_spec("aaa", "2.0"), fake_spec("minitest", "3.0")]
      Dir.mktmpdir do |dir|
        path = File.join(dir, "Gemfile")
        original = "source \"https://rubygems.org\"\ngem \"highline\"\n"
        File.write(path, original)
        content = Toys::Utils::Gems.new.send(:modified_gemfile_content, path,
                                             loaded_gems: specs, omit_gem_names: [], lib_paths: {})
        assert_equal(original, content[0])
        assert_equal("toys_loaded_gems = [\"aaa\", \"minitest\", \"zzz\"]", content[1])
        assert_equal("dependencies.delete_if { |dep| toys_loaded_gems.include?(dep.name) }", content[2])
        assert_equal("gem \"aaa\", '= 2.0'", content[3])
        assert_equal("gem \"minitest\", '= 3.0'", content[4])
        assert_equal("gem \"zzz\", '= 1.0'", content[5])
        assert_equal(specs.size + 3, content.size)
      end
    end

    it "drops gems named in omit_gem_names without mutating the input" do
      specs = [fake_spec("pathname", "1.0"), fake_spec("minitest", "2.0")].freeze
      Dir.mktmpdir do |dir|
        path = File.join(dir, "Gemfile")
        File.write(path, "source \"https://rubygems.org\"\n")
        content = Toys::Utils::Gems.new.send(:modified_gemfile_content, path,
                                             loaded_gems: specs, omit_gem_names: ["pathname"],
                                             lib_paths: {})
        assert_equal("toys_loaded_gems = [\"minitest\"]", content[1])
        refute(content.any? { |line| line.start_with?("gem \"pathname\"") })
        assert_equal("gem \"minitest\", '= 2.0'", content[3])
        assert_equal(specs.size + 2, content.size)
      end
    end

    it "falls back to its own custom_lib_paths when lib_paths is not given" do
      old_dev = ENV["TOYS_DEV"]
      begin
        ENV["TOYS_DEV"] = "true"
        specs = [fake_spec("toys-core", "1.0"), fake_spec("minitest", "2.0")]
        Dir.mktmpdir do |dir|
          path = File.join(dir, "Gemfile")
          File.write(path, "source \"https://rubygems.org\"\n")
          content = Toys::Utils::Gems.new.send(:modified_gemfile_content, path,
                                               loaded_gems: specs, omit_gem_names: [])
          expected_path = File.dirname(Toys::CORE_LIB_PATH)
          assert_includes(content, "gem \"toys-core\", '= 1.0', path: #{expected_path.inspect}")
          assert_includes(content, "gem \"minitest\", '= 2.0'")
        end
      ensure
        ENV["TOYS_DEV"] = old_dev
      end
    end
  end

  describe "#check_gemfile_gem_compatibility" do
    it "raises only for a requirement the running toys version fails" do
      gems = Toys::Utils::Gems.new
      Dir.mktmpdir do |dir|
        path = File.join(dir, "Gemfile")
        File.write(path, "source \"https://rubygems.org\"\ngem \"toys-core\", \"= 0.0.1\"\n")
        builder = Bundler::Dsl.new
        begin
          builder.eval_gemfile(path)
          err = assert_raises(Toys::Utils::Gems::IncompatibleToysError) do
            gems.send(:check_gemfile_gem_compatibility, builder, "toys-core")
          end
          assert_match(/incompatible with the current toys version/, err.message)
          # An absent dependency is silent.
          gems.send(:check_gemfile_gem_compatibility, builder, "toys")
        ensure
          Bundler.reset!
        end
      end
      Dir.mktmpdir do |dir|
        path = File.join(dir, "Gemfile")
        File.write(path, "source \"https://rubygems.org\"\n" \
                         "gem \"toys-core\", \"= #{Toys::Core::VERSION}\"\n")
        builder = Bundler::Dsl.new
        begin
          builder.eval_gemfile(path)
          gems.send(:check_gemfile_gem_compatibility, builder, "toys-core")
        ensure
          Bundler.reset!
        end
      end
    end
  end

  describe "#create_modified_gemfile" do
    it "writes a uniquely named gemfile beside the original and copies the lockfile" do
      gems = Toys::Utils::Gems.new
      Dir.mktmpdir do |dir|
        original = "source \"https://rubygems.org\"\ngem \"nonesuch-unrelated\"\n"
        path = File.join(dir, "Gemfile")
        File.write(path, original)
        File.write("#{path}.lock", "LOCK CONTENT\n")
        modified_path = gems.send(:create_modified_gemfile, path)
        # Deliberately beside the user's gemfile, not in a tmpdir, so relative
        # path: and gemspec directives still resolve.
        assert_equal(dir, File.dirname(modified_path))
        assert_match(/\A\.toys-tmp-gemfile-\d{14}-[0-9a-z]{1,10}\z/, File.basename(modified_path))
        written = File.read(modified_path)
        assert(written.start_with?(original))
        # puts does not add a second newline to a string already ending in one.
        refute(written.start_with?("#{original}\n"))
        assert_equal("LOCK CONTENT\n", File.read("#{modified_path}.lock"))
      end
      Dir.mktmpdir do |dir|
        path = File.join(dir, "gems.rb")
        File.write(path, "source \"https://rubygems.org\"\n")
        File.write(File.join(dir, "gems.locked"), "LOCK CONTENT\n")
        modified_path = gems.send(:create_modified_gemfile, path)
        # find_lockfile_path's gems.locked branch fires for the source but never
        # for the destination, whose name can never be gems.rb.
        assert_equal("LOCK CONTENT\n", File.read("#{modified_path}.lock"))
      end
    end

    it "rewrites pinned dependencies, keeping unrelated ones and losing group metadata" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "Gemfile")
        File.write(path, <<~GEMFILE)
          source "https://rubygems.org"
          group :development do
            gem "minitest", "= 1.0", require: false
          end
          gem "nonesuch-unrelated"
        GEMFILE
        modified_path = Toys::Utils::Gems.new.send(:create_modified_gemfile, path)
        builder = Bundler::Dsl.new
        begin
          builder.eval_gemfile(modified_path)
          deps = builder.dependencies
          # The user's "= 1.0" constraint is deleted and the loaded version wins.
          dep = deps.find { |d| d.name == "minitest" }
          refute_nil(dep)
          assert_equal("= #{Gem.loaded_specs['minitest'].version}", dep.requirement.to_s)
          # The re-added gem loses its group and its require: false. This pins
          # current behavior; whether it is correct is issue 03's question.
          assert_equal([:default], dep.groups)
          assert_nil(dep.autorequire)
          # Unrelated dependencies survive, and come before the re-added gems.
          assert_equal("nonesuch-unrelated", deps.first.name)
        ensure
          Bundler.reset!
        end
      end
    end
  end

  describe "#bundle (no bundler required)" do
    it "raises GemfileNotFoundError when no gemfile is found" do
      Dir.mktmpdir do |dir|
        err = assert_raises(Toys::Utils::Gems::GemfileNotFoundError) do
          Toys::Utils::Gems.new.bundle(search_dirs: dir)
        end
        assert_equal("Gemfile not found", err.message)
        assert_raises(Toys::Utils::Gems::GemfileNotFoundError) do
          Toys::Utils::Gems.new.bundle(search_dirs: [dir, dir])
        end
      end
    end

    it "raises on a conflicting bundle when on_conflict is :error" do
      with_conflicting_bundle_gemfile do |gemfile_path, sentinel|
        output = StringIO.new
        gems = Toys::Utils::Gems.new(on_conflict: :error, output: output)
        err = assert_raises(Toys::Utils::Gems::AlreadyBundledError) do
          gems.bundle(gemfile_path: gemfile_path)
        end
        assert_equal("Could not set up bundle because another is already set up", err.message)
        assert_empty(output.string)
        assert_equal(sentinel, ENV["BUNDLE_GEMFILE"])
      end
    end

    it "warns and returns false on a conflicting bundle when on_conflict is :warn" do
      with_conflicting_bundle_gemfile do |gemfile_path, sentinel|
        output = StringIO.new
        gems = Toys::Utils::Gems.new(on_conflict: :warn, output: output)
        assert_equal(false, gems.bundle(gemfile_path: gemfile_path))
        assert_equal("Warning: could not set up bundle because another is already set up.\n",
                     output.string)
        assert_equal(sentinel, ENV["BUNDLE_GEMFILE"])
      end
    end

    it "silently returns false on a conflicting bundle when on_conflict is :ignore" do
      with_conflicting_bundle_gemfile do |gemfile_path, sentinel|
        output = StringIO.new
        gems = Toys::Utils::Gems.new(on_conflict: :ignore, output: output)
        assert_equal(false, gems.bundle(gemfile_path: gemfile_path))
        assert_empty(output.string)
        assert_equal(sentinel, ENV["BUNDLE_GEMFILE"])
      end
    end
  end

  # Note the skip here is retained as a backstop, so that a future integration
  # test added in a new describe block does not hit the network. The describes
  # below install the same skip in a before hook, which additionally prevents
  # the "gem list" shellouts that run before setup_case is reached.
  def setup_case(name, tmp_vendor: true, timeout: 60, &block)
    skip "Skipped integration test" unless ::ENV["TOYS_TEST_INTEGRATION"]
    Bundler.with_unbundled_env do
      Dir.chdir(File.join(gems_cases_dir, name)) do
        old_path = ENV["BUNDLE_PATH"]
        if tmp_vendor
          ENV["BUNDLE_PATH"] = "tmp/vendor"
          FileUtils.rm_rf("tmp/vendor")
        end
        begin
          Timeout.timeout(timeout, &block)
        ensure
          if tmp_vendor
            ENV["BUNDLE_PATH"] = old_path
            FileUtils.rm_rf("tmp/vendor")
          end
        end
      end
    end
  end

  def run_script(name = "run_test.rb", *args)
    exec_service.exec_ruby(["-I#{Toys::CORE_LIB_PATH}", name, *args],
                           out: :capture, err: :capture, in: :null)
  end

  describe "#bundle" do
    before do
      skip "Skipped integration test" unless ::ENV["TOYS_TEST_INTEGRATION"]
    end

    def clean_files_for_multi_tests
      files = ["Gemfile", "gems.rb", ".gems.rb", "Gemfile.lock", "gems.locked", ".gems.rb.lock"]
      files.each { |file| FileUtils.rm_f(file) }
    end

    it "sets up a bundle without toys" do
      setup_case("bundle-without-toys") do
        FileUtils.rm_f("Gemfile.lock")
        result = run_script
        assert(result.success?)
        assert_match(/result: :\w+/, result.captured_out)
        result = run_script
        assert(result.success?)
        assert_includes(result.captured_out, "result: :setup")
      end
    end

    it "sets up a bundle twice" do
      setup_case("bundle-repeated") do
        FileUtils.rm_f("Gemfile.lock")
        result = run_script
        assert(result.success?)
        assert_match(/result: :\w+/, result.captured_out)
        assert_includes(result.captured_out, "result2: :setup")
      end
    end

    it "errors when setting up a bundle with BUNDLE_GEMFILE already set to something else" do
      old_gemfile_path = ENV["BUNDLE_GEMFILE"]
      setup_case("bundle-without-toys") do
        FileUtils.rm_f("Gemfile.lock")
        ENV["BUNDLE_GEMFILE"] = gem_gemfile_path
        result = run_script
        refute(result.success?)
        assert_includes(result.captured_err, "Could not set up bundle because another is already set up")
      ensure
        ENV["BUNDLE_GEMFILE"] = old_gemfile_path
      end
    end

    it "sets up a bundle with compatible toys" do
      setup_case("bundle-with-compatible-toys") do
        FileUtils.rm_f("Gemfile.lock")
        result = run_script
        assert(result.success?)
        assert_match(/result: :\w+/, result.captured_out)
        result = run_script
        assert(result.success?)
        assert_includes(result.captured_out, "result: :setup")
      end
    end

    it "fails to set up a bundle with incompatible toys" do
      setup_case("bundle-with-incompatible-toys") do
        FileUtils.rm_f("Gemfile.lock")
        result = run_script
        refute(result.success?)
        assert_match(/Toys::Utils::Gems::IncompatibleToysError/, result.captured_err)
        refute_match(/Unexpected BUNDLE_GEMFILE/, result.captured_out)
        refute_match(/should-not-get-here/, result.captured_out)
      end
    end

    it "sets up a bundle installing to a local directory" do
      setup_case("bundle-with-vendored-path", tmp_vendor: false) do
        FileUtils.rm_f("Gemfile.lock")
        FileUtils.rm_rf("vendor")
        result = run_script
        assert(result.success?)
        assert_match(/result: :\w+/, result.captured_out)
        result = run_script
        assert(result.success?)
        assert_includes(result.captured_out, "result: :setup")
      end
    end

    it "preserves the original Gemfile.lock" do
      setup_case("bundle-without-toys", timeout: 120) do
        exec_service.exec(["bundle", "install"], out: :null, err: :null)
        FileUtils.cp("Gemfile.lock.orig", "Gemfile.lock")
        result = run_script
        assert(result.success?)
        cur_lockfile = File.read("Gemfile.lock")
        orig_lockfile = File.read("Gemfile.lock.orig")
        assert_equal(orig_lockfile, cur_lockfile)
      end
    end

    it "chooses gems.rb over Gemfile" do
      setup_case("bundle-with-multiple-gemfiles") do
        clean_files_for_multi_tests
        FileUtils.cp("gemfile1.rb", "gems.rb")
        FileUtils.cp("gemfile2.rb", "Gemfile")
        result = run_script
        assert(result.success?)
      end
      setup_case("bundle-with-multiple-gemfiles") do
        clean_files_for_multi_tests
        FileUtils.cp("gemfile2.rb", "gems.rb")
        FileUtils.cp("gemfile1.rb", "Gemfile")
        result = run_script
        refute(result.success?)
      end
    end

    it "chooses .gems.rb over gems.rb" do
      setup_case("bundle-with-multiple-gemfiles") do
        clean_files_for_multi_tests
        FileUtils.cp("gemfile1.rb", ".gems.rb")
        FileUtils.cp("gemfile2.rb", "gems.rb")
        result = run_script
        assert(result.success?)
      end
      setup_case("bundle-with-multiple-gemfiles") do
        clean_files_for_multi_tests
        FileUtils.cp("gemfile2.rb", ".gems.rb")
        FileUtils.cp("gemfile1.rb", "gems.rb")
        result = run_script
        refute(result.success?)
      end
    end

    it "sets up a bundle requiring installation of a direct dependency" do
      skip "Skipped test on JRuby or TruffleRuby" if Toys::Compat.jruby? || Toys::Compat.truffleruby?
      if exec_service.capture(["gem", "list", "highline"]).include?("2.0.2")
        skip "Skipped test because highline 2.0.2 is already installed"
      end
      setup_case("bundle-without-toys") do
        FileUtils.rm_f("Gemfile.lock")
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        assert_match(/Bundle (complete|updated)!/, result.captured_out)
        FileUtils.rm_rf("tmp/vendor")
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        assert_match(/Bundle (complete|updated)!/, result.captured_out)
        result = run_script
        assert(result.success?)
        refute_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
      end
    end

    it "sets up a bundle requiring installation of a transitive dependency via a gemspec" do
      skip "Skipped test on JRuby or TruffleRuby" if Toys::Compat.jruby? || Toys::Compat.truffleruby?
      if exec_service.capture(["gem", "list", "highline"]).include?("2.0.1")
        skip "Skipped test because highline 2.0.1 is already installed"
      end
      setup_case("bundle-using-gemspec") do
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        assert_match(/Bundle (complete|updated)!/, result.captured_out)
        FileUtils.rm_rf("tmp/vendor")
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        assert_match(/Bundle (complete|updated)!/, result.captured_out)
        result = run_script
        assert(result.success?)
        refute_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
      end
    end

    it "updates the bundle if install fails due to conflicts" do
      skip "Skipped test on JRuby or TruffleRuby" if Toys::Compat.jruby? || Toys::Compat.truffleruby?
      if exec_service.capture(["gem", "list", "rubocop"]).include?("0.81.0")
        skip "Skipped test because rubocop 0.81.0 is already installed"
      end
      setup_case("bundle-update-required") do
        FileUtils.rm_f("Gemfile.lock")
        FileUtils.cp("Gemfile.lock.orig", "Gemfile.lock")
        result = run_script
        assert(result.success?)
        assert_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
        result = run_script
        assert(result.success?)
        refute_match(/Your bundle requires additional gems\. Install\?/, result.captured_out)
      end
    end

    it "preserves the versions of default gems" do
      skip "Skipped test on JRuby or TruffleRuby" if Toys::Compat.jruby? || Toys::Compat.truffleruby?
      setup_case("bundle-with-default-gems") do
        result = run_script
        assert(result.success?)
      end
    end
  end

  describe "#activate" do
    before do
      skip "Skipped integration test" unless ::ENV["TOYS_TEST_INTEGRATION"]
    end

    it "installs and activates a gem" do
      setup_case("activate-highline") do
        exec_service.exec(["gem", "uninstall", "highline", "--version=2.0.1"], out: :null)
        result = run_script
        assert(result.success?)
        assert_match(/Gem needed: .* Install\?/, result.captured_out)
        assert_includes(result.captured_out, "result: :installed")
        result = run_script
        assert(result.success?)
        refute_match(/Gem needed: .* Install\?/, result.captured_out)
        assert_includes(result.captured_out, "result: :activated")
      end
    end

    it "handles re-activation" do
      setup_case("activate-repeated") do
        result = run_script
        assert(result.success?)
        assert_match(/result: :\w+/, result.captured_out)
        assert_includes(result.captured_out, "result2: false")
      end
    end
  end
end
