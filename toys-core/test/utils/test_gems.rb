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
    it "appends the pin table and the mutation code after the original content" do
      # Deliberately out of order, so sort_by is not the identity here.
      specs = [fake_spec("zzz", "1.0"), fake_spec("aaa", "2.0"), fake_spec("minitest", "3.0")]
      Dir.mktmpdir do |dir|
        path = File.join(dir, "Gemfile")
        original = "source \"https://rubygems.org\"\ngem \"highline\"\n"
        File.write(path, original)
        content = Toys::Utils::Gems.new.send(:modified_gemfile_content, path,
                                             loaded_gems: specs, omit_gem_names: [], lib_paths: {})
        assert_equal(original, content[0])
        assert_equal("toys_overridden_gems = []", content[1])
        assert_equal("dependencies.delete_if { |dep| toys_overridden_gems.include?(dep.name) }",
                     content[2])
        # Derived rather than written out, because Hash#inspect spaces its
        # rockets differently before and after Ruby 3.4.
        expected = {"aaa" => "2.0", "minitest" => "3.0", "zzz" => "1.0"}
        assert_equal("toys_pinned_gems = #{expected.inspect}", content[3])
        # Pins the position of the mutation code; what it does is covered by the
        # dependency-semantics tests below.
        assert_equal(Toys::Utils::Gems::PIN_DEPENDENCIES_CODE, content[4])
        # Nothing is source-overridden here, so nothing is redeclared.
        assert_equal(5, content.size)
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
        assert_equal("toys_pinned_gems = #{{'minitest' => '2.0'}.inspect}", content[3])
        refute(content.any? { |line| line.include?("pathname") })
        assert_equal(5, content.size)
      end
    end

    it "redeclares gems whose source is overridden" do
      specs = [fake_spec("toys-core", "1.0"), fake_spec("minitest", "2.0")]
      Dir.mktmpdir do |dir|
        path = File.join(dir, "Gemfile")
        File.write(path, "source \"https://rubygems.org\"\n")
        content = Toys::Utils::Gems.new.send(:modified_gemfile_content, path,
                                             loaded_gems: specs, omit_gem_names: [],
                                             lib_paths: {"toys-core" => "/x/toys-core"})
        assert_equal("toys_overridden_gems = [\"toys-core\"]", content[1])
        # An overridden gem is redeclared, so it must not also be pinned in place.
        assert_equal("toys_pinned_gems = #{{'minitest' => '2.0'}.inspect}", content[3])
        assert_equal("gem \"toys-core\", '= 1.0', path: \"/x/toys-core\", " \
                     "require: false, group: :\"toys.loaded\"",
                     content[5])
        assert_equal(6, content.size)
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
          assert_includes(content,
                          "gem \"toys-core\", '= 1.0', path: #{expected_path.inspect}, " \
                          "require: false, group: :\"toys.loaded\"")
          assert_equal("toys_pinned_gems = #{{'minitest' => '2.0'}.inspect}", content[3])
        end
      ensure
        ENV["TOYS_DEV"] = old_dev
      end
    end
  end

  # These parse the generated gemfile back through Bundler, because the rewrite's
  # contract is about the dependency objects Bundler ends up with, not about the
  # text. One test per rule from the three-way classification: inclusion filters
  # are neutralized, provenance is preserved, require: is preserved.
  describe "modified gemfile dependency semantics" do
    # Mirrors create_modified_gemfile: generate the content, write it beside the
    # original so relative path: sources still resolve, and parse it back.
    def parse_modified_gemfile(dir, source, specs, lib_paths: {})
      path = File.join(dir, "Gemfile")
      File.write(path, source)
      content = Toys::Utils::Gems.new.send(:modified_gemfile_content, path, loaded_gems: specs,
                                           omit_gem_names: [], lib_paths: lib_paths)
      modified_path = File.join(dir, ".toys-tmp-gemfile-test")
      File.open(modified_path, "w") { |file| content.each { |line| file.puts(line) } }
      builder = Bundler::Dsl.new
      Bundler.ui.silence { builder.eval_gemfile(modified_path) }
      builder.dependencies
    ensure
      Bundler.reset!
    end

    it "neutralizes every inclusion filter on a pinned dependency" do
      specs = [fake_spec("highline", "1.0"), fake_spec("rainbow", "2.0"),
               fake_spec("diff-lcs", "3.0"), fake_spec("crack", "4.0")]
      Dir.mktmpdir do |dir|
        deps = parse_modified_gemfile(dir, <<~GEMFILE, specs)
          source "https://rubygems.org"
          group :development do
            gem "highline"
          end
          gem "rainbow", platforms: [:jruby]
          gem "diff-lcs", install_if: -> { false }
          env "TOYS_TEST_VARIABLE_NEVER_SET" do
            gem "crack"
          end
        GEMFILE
        by_name = deps.each_with_object({}) { |dep, hash| hash[dep.name] = dep }
        # The sentinel is added rather than replacing the user's group. :default is
        # deliberately not added: promoting a :development gem into :default would
        # pull it into a bare Bundler.require.
        assert_equal([:development, :"toys.loaded"], by_name["highline"].groups)
        assert_empty(by_name["rainbow"].platforms)
        # Covers install_if:, the env block, and the current-platform filter.
        deps.each { |dep| assert(dep.should_include?, "#{dep.name} was filtered out") }
      end
    end

    it "keeps every pinned dependency in scope for a restricted group request" do
      specs = [fake_spec("highline", "1.0"), fake_spec("rainbow", "2.0"),
               fake_spec("aaa-injected", "3.0")]
      Dir.mktmpdir do |dir|
        deps = parse_modified_gemfile(dir, <<~GEMFILE, specs)
          source "https://rubygems.org"
          group :development do
            gem "highline"
          end
          gem "rainbow"
        GEMFILE
        # Derived from the same method production passes to Bundler.setup, so the
        # tagging and the group request cannot drift apart. Adding only :default
        # would leave "rainbow" and the injected gem out of this request, and
        # bundler would strip them from the load path.
        requested = Toys::Utils::Gems.new.send(:setup_groups, ["development"]).map(&:to_sym)
        deps.each do |dep|
          refute_empty(dep.groups & requested, "#{dep.name} would be excluded from setup")
        end
      end
    end

    it "puts an injected gem in the pinned group only" do
      Dir.mktmpdir do |dir|
        deps = parse_modified_gemfile(dir, "source \"https://rubygems.org\"\n",
                                      [fake_spec("aaa-injected", "1.0")])
        dep = deps.find { |d| d.name == "aaa-injected" }
        # Not :default: toys pinned it for resolution, and a bare Bundler.require
        # should not pick it up.
        assert_equal([:"toys.loaded"], dep.groups)
      end
    end

    it "preserves the source of a pinned dependency" do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, "localgem"))
        deps = parse_modified_gemfile(dir, <<~GEMFILE, [fake_spec("localgem", "9.9.9")])
          source "https://rubygems.org"
          gem "localgem", path: "./localgem"
        GEMFILE
        dep = deps.find { |d| d.name == "localgem" }
        # Assert the source object itself. A rewrite that merely copied a path:
        # key forward would satisfy a weaker assertion but still resolve wrong.
        assert_instance_of(Bundler::Source::Path, dep.source)
        assert_equal(File.join(dir, "localgem"), File.expand_path(dep.source.path.to_s, dir))
        assert_equal("= 9.9.9", dep.requirement.to_s)
      end
    end

    it "preserves the require option of a pinned dependency" do
      specs = [fake_spec("highline", "1.0"), fake_spec("rainbow", "2.0"),
               fake_spec("aaa-injected", "3.0")]
      Dir.mktmpdir do |dir|
        deps = parse_modified_gemfile(dir, <<~GEMFILE, specs)
          source "https://rubygems.org"
          gem "highline", require: false
          gem "rainbow", require: "rainbow/global"
        GEMFILE
        by_name = deps.each_with_object({}) { |dep, hash| hash[dep.name] = dep }
        assert_equal([], by_name["highline"].autorequire)
        assert_equal(["rainbow/global"], by_name["rainbow"].autorequire)
        # A gem toys loaded but the user never declared is pinned for
        # resolution, not requested for loading.
        assert_equal([], by_name["aaa-injected"].autorequire)
      end
    end

    it "pins every declaration when a gem is declared more than once" do
      Dir.mktmpdir do |dir|
        deps = parse_modified_gemfile(dir, <<~GEMFILE, [fake_spec("highline", "1.0")])
          source "https://rubygems.org"
          gem "highline"
          gem "highline"
        GEMFILE
        # Bundler warns about the duplicate but keeps both dependency objects, so
        # a loop that consumed the pin table would leave the second unpinned.
        matches = deps.select { |dep| dep.name == "highline" }
        assert_equal(2, matches.size)
        matches.each { |dep| assert_equal("= 1.0", dep.requirement.to_s) }
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

  describe "#setup_groups" do
    it "adds the pinned group only when specific groups are requested" do
      gems = Toys::Utils::Gems.new
      # An empty request already means every group. Adding the sentinel there
      # would turn it into a request for the pinned gems *only*.
      assert_equal([], gems.send(:setup_groups, []))
      assert_equal(["development", :"toys.loaded"], gems.send(:setup_groups, ["development"]))
    end
  end

  describe "#check_gemfile_source_compatibility" do
    # Gem::Specification computes full_gem_path from the rubygems install dir,
    # which is exactly the "loaded from somewhere else" case; override it to
    # simulate a gem that was loaded from the path the gemfile declares.
    def spec_loaded_from(name, version, gem_path)
      spec = fake_spec(name, version)
      spec.define_singleton_method(:full_gem_path) { gem_path }
      spec
    end

    # Bundler::UI::Silent swallows output. This records it, so a git operation
    # started by the check is visible. Production reaches this code after
    # Bundler.configure, where the UI is live; the earlier tests ran with the
    # default UI and so could not see a fetch being announced.
    def recording_ui
      Class.new(::Bundler::UI::Silent) do
        def messages
          @messages ||= []
        end

        def info(message, *_args, **_opts)
          messages << message
        end
        alias_method :warn, :info
        alias_method :confirm, :info
        alias_method :error, :info
      end.new
    end

    def with_gemfile(source)
      gems = Toys::Utils::Gems.new
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, "localgem"))
        path = File.join(dir, "Gemfile")
        File.write(path, "source \"https://rubygems.org\"\n#{source}")
        builder = Bundler::Dsl.new
        begin
          builder.eval_gemfile(path)
          yield gems, builder, path, dir
        ensure
          Bundler.reset!
        end
      end
    end

    it "raises only when a gem is loaded from somewhere other than its declared path" do
      with_gemfile("gem \"localgem\", path: \"./localgem\"\n") do |gems, builder, path, dir|
        # Loaded from the declared path.
        matching = spec_loaded_from("localgem", "1.0", File.join(dir, "localgem"))
        gems.send(:check_gemfile_source_compatibility, builder, path,
                  loaded_gems: [matching], lib_paths: {})
        # Loaded from the rubygems install dir instead.
        mismatched = spec_loaded_from("localgem", "1.0", File.join(Gem.dir, "gems", "localgem-1.0"))
        err = assert_raises(Toys::Utils::Gems::IncompatibleGemSourceError) do
          gems.send(:check_gemfile_source_compatibility, builder, path,
                    loaded_gems: [mismatched], lib_paths: {})
        end
        assert_match(/localgem/, err.message)
        # Names the directory the gemfile pointed at, not just the gem.
        assert_includes(err.message, File.join(dir, "localgem"))
        # A gem whose lib path toys overrides is exempt: the override exists to
        # overrule the user's declaration.
        gems.send(:check_gemfile_source_compatibility, builder, path,
                  loaded_gems: [mismatched], lib_paths: {"localgem" => "/x/localgem"})
      end
    end

    it "compares source paths through symlinks" do
      with_gemfile("gem \"localgem\", path: \"./localgem-link\"\n") do |gems, builder, path, dir|
        File.symlink(File.join(dir, "localgem"), File.join(dir, "localgem-link"))
        # The gemfile reaches the directory by one name and the loaded gem
        # records the other. Comparing the strings would report a false conflict.
        spec = spec_loaded_from("localgem", "1.0", File.join(dir, "localgem"))
        gems.send(:check_gemfile_source_compatibility, builder, path,
                  loaded_gems: [spec], lib_paths: {})
      end
    end

    it "ignores gems with no declared source and gems that are not loaded" do
      with_gemfile("gem \"localgem\", path: \"./localgem\"\ngem \"highline\"\n") do |gems, builder, path|
        # highline is declared without a source, so where it came from is not
        # something the gemfile asserted.
        elsewhere = File.join(Gem.dir, "gems", "highline-1.0")
        gems.send(:check_gemfile_source_compatibility, builder, path,
                  loaded_gems: [spec_loaded_from("highline", "1.0", elsewhere)], lib_paths: {})
        # localgem is declared with a path but is not loaded at all.
        gems.send(:check_gemfile_source_compatibility, builder, path,
                  loaded_gems: [], lib_paths: {})
      end
    end

    it "ignores gems the rewrite omits from the bundle" do
      with_gemfile("gem \"localgem\", path: \"./localgem\"\n") do |gems, builder, path|
        mismatched = spec_loaded_from("localgem", "1.0", File.join(Gem.dir, "gems", "localgem-1.0"))
        # Positive control: without the omission this is a conflict, so the pass
        # below cannot be succeeding for some unrelated reason.
        assert_raises(Toys::Utils::Gems::IncompatibleGemSourceError) do
          gems.send(:check_gemfile_source_compatibility, builder, path,
                    loaded_gems: [mismatched], omit_gem_names: [], lib_paths: {})
        end
        # One list drives both halves, so they cannot drift apart: a gem the
        # rewrite never pins keeps whatever source the user declared, leaving
        # nothing for toys to contradict. On TruffleRuby the list holds
        # "pathname", whose real gem cannot be installed there.
        omitted = ["localgem"]
        content = gems.send(:modified_gemfile_content, path,
                            loaded_gems: [mismatched], omit_gem_names: omitted, lib_paths: {})
        assert_equal("toys_pinned_gems = {}", content[3])
        gems.send(:check_gemfile_source_compatibility, builder, path,
                  loaded_gems: [mismatched], omit_gem_names: omitted, lib_paths: {})
      end
    end

    it "raises when a git-sourced gem is loaded from outside the git checkout root" do
      with_gemfile("gem \"gitgem\", git: \"https://example.com/nonesuch.git\"\n") do |gems, builder, path|
        # A git checkout lives under Bundler.install_path. This gem came from the
        # rubygems install dir, so the gemfile's git source is not what is loaded.
        elsewhere = File.join(Gem.dir, "gems", "gitgem-1.0")
        err = assert_raises(Toys::Utils::Gems::IncompatibleGemSourceError) do
          gems.send(:check_gemfile_source_compatibility, builder, path,
                    loaded_gems: [spec_loaded_from("gitgem", "1.0", elsewhere)], lib_paths: {})
        end
        assert_match(/gitgem/, err.message)
        # A sibling directory that merely shares the checkout root's prefix is
        # not inside it.
        sibling = "#{Bundler.install_path}-elsewhere#{File::SEPARATOR}gitgem-abc123def456"
        assert_raises(Toys::Utils::Gems::IncompatibleGemSourceError) do
          gems.send(:check_gemfile_source_compatibility, builder, path,
                    loaded_gems: [spec_loaded_from("gitgem", "1.0", sibling)], lib_paths: {})
        end
      end
    end

    it "names a git source in the error without starting a git operation" do
      with_gemfile("gem \"gitgem\", git: \"https://example.com/nonesuch.git\"\n") do |gems, builder, path|
        old_ui = Bundler.ui
        ui = recording_ui
        Bundler.ui = ui
        begin
          elsewhere = File.join(Gem.dir, "gems", "gitgem-1.0")
          err = assert_raises(Toys::Utils::Gems::IncompatibleGemSourceError) do
            gems.send(:check_gemfile_source_compatibility, builder, path,
                      loaded_gems: [spec_loaded_from("gitgem", "1.0", elsewhere)], lib_paths: {})
          end
          # Bundler::Source::Git#to_s resolves a branch, which announces a fetch
          # before the guard rejects it, so the message must not go through it.
          assert_match(%r{https://example\.com/nonesuch\.git}, err.message)
          assert_empty(ui.messages)
        ensure
          Bundler.ui = old_ui
        end
      end
    end

    it "filters credentials out of a git source in the error message" do
      uri = "https://someone:ghp_notarealtoken@example.com/org/repo.git"
      with_gemfile("gem \"gitgem\", git: \"#{uri}\"\n") do |gems, builder, path|
        elsewhere = File.join(Gem.dir, "gems", "gitgem-1.0")
        err = assert_raises(Toys::Utils::Gems::IncompatibleGemSourceError) do
          gems.send(:check_gemfile_source_compatibility, builder, path,
                    loaded_gems: [spec_loaded_from("gitgem", "1.0", elsewhere)], lib_paths: {})
        end
        # Source::Git#uri is the unfiltered URI; bundler renders from a filtered
        # copy it keeps privately. This message reaches a terminal and whatever
        # captures it, so it must be filtered the same way.
        refute_includes(err.message, "ghp_notarealtoken")
        assert_includes(err.message, "https://someone@example.com/org/repo.git")
      end
    end

    it "accepts a git-sourced gem loaded from the git checkout root" do
      with_gemfile("gem \"gitgem\", git: \"https://example.com/nonesuch.git\"\n") do |gems, builder, path|
        # The checkout directory embeds a revision that cannot be resolved here
        # without git operations, so only the root is compared. Nothing about
        # this call may reach the network or the git binary.
        checkout = File.join(Bundler.install_path.to_s, "gitgem-abc123def456")
        gems.send(:check_gemfile_source_compatibility, builder, path,
                  loaded_gems: [spec_loaded_from("gitgem", "1.0", checkout)], lib_paths: {})
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

    it "rewrites pinned dependencies in place, keeping unrelated ones" do
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
          # The user's "= 1.0" constraint is overwritten and the loaded version wins.
          dep = deps.find { |d| d.name == "minitest" }
          refute_nil(dep)
          assert_equal("= #{Gem.loaded_specs['minitest'].version}", dep.requirement.to_s)
          # The declaration is mutated rather than replaced, so the group and the
          # require: false survive, with the sentinel added to force it into setup.
          assert_equal([:development, :"toys.loaded"], dep.groups)
          assert_equal([], dep.autorequire)
          # Both declared dependencies keep their original position; a regression
          # to delete-and-re-add would move minitest to the end.
          names = deps.map(&:name)
          assert_equal(0, names.index("minitest"))
          assert_equal(1, names.index("nonesuch-unrelated"))
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

    it "sets up a gem loaded by toys even when its group is not requested" do
      setup_case("bundle-with-restricted-groups") do
        FileUtils.rm_f("Gemfile.lock")
        result = run_script
        assert(result.success?, result.captured_err)
        assert_match(/result: :\w+/, result.captured_out)
        assert_includes(result.captured_out, "abbrev: loaded")
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

    it "detects a git source conflict through the real entry point" do
      setup_case("bundle-with-conflicting-git-source") do
        result = run_script
        assert(result.success?, result.captured_err)
        assert_match(/^conflict: The bundle lists logger from the git source /, result.captured_out)
        # This drives check_gemfile_compatibility the way production does, with
        # Bundler.configure called, the live Bundler UI, and sources built by the
        # production code. Rendering a git source through bundler announces a
        # fetch before its guard rejects it, and resolving one raises GitError
        # even when a checkout exists -- neither is visible when a test hands the
        # check a Bundler::Dsl it built itself.
        refute_includes(result.captured_out, "Fetching")
        refute_includes(result.captured_err, "Fetching")
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
