# frozen_string_literal: true

require "helper"

describe Toys::SourceSpec do
  let(:my_proc) { proc { :a } }
  let(:my_proc2) { proc { :b } }

  describe "path" do
    it "creates a Path spec with defaults" do
      spec = Toys::SourceSpec.path("/path/to/source")
      assert_instance_of(Toys::SourceSpec::Path, spec)
      assert_expanded_path("/path/to/source", spec.path)
      assert_nil(spec.relative_paths)
      assert_nil(spec.context_directory)
      assert_nil(spec.source_name)
    end

    it "creates a Path spec with all attributes" do
      spec = Toys::SourceSpec.path("/path/to/source",
                                   relative_paths: [".toys", ".toys.rb"],
                                   context_directory: "/my/context",
                                   source_name: "mysource")
      assert_expanded_path("/path/to/source", spec.path)
      assert_equal([".toys", ".toys.rb"], spec.relative_paths)
      assert_expanded_path("/my/context", spec.context_directory)
      assert_equal("mysource", spec.source_name)
    end

    it "normalizes a single relative path to an array" do
      spec = Toys::SourceSpec.path("/path/to/source", relative_paths: ".toys")
      assert_equal([".toys"], spec.relative_paths)
    end

    it "distinguishes nil relative paths from an empty array" do
      assert_nil(Toys::SourceSpec.path("/path").relative_paths)
      assert_equal([], Toys::SourceSpec.path("/path", relative_paths: []).relative_paths)
    end

    it "copies and freezes the relative paths" do
      paths = [".toys"]
      spec = Toys::SourceSpec.path("/path/to/source", relative_paths: paths)
      paths << ".toys.rb"
      assert_equal([".toys"], spec.relative_paths)
      assert_predicate(spec.relative_paths, :frozen?)
    end

    it "accepts a string or nil as a context directory" do
      assert_expanded_path("/c", Toys::SourceSpec.path("/p", context_directory: "/c").context_directory)
      assert_nil(Toys::SourceSpec.path("/p", context_directory: nil).context_directory)
    end

    it "rejects an unrecognized context directory" do
      assert_raises(ArgumentError) do
        Toys::SourceSpec.path("/p", context_directory: :whatever)
      end
      assert_raises(ArgumentError) do
        Toys::SourceSpec.path("/p", context_directory: 12_345)
      end
    end

    # The symbolic forms are interpreted by the high level CLI methods rather
    # than by specs, so a path spec must reject them just as the other kinds do.
    it "rejects :parent and :path as a context directory" do
      error = assert_raises(ArgumentError) do
        Toys::SourceSpec.path("/p", context_directory: :parent)
      end
      assert_equal("Illegal context_directory value: :parent", error.message)
      assert_raises(ArgumentError) do
        Toys::SourceSpec.path("/p", context_directory: :path)
      end
    end

    it "creates a frozen object" do
      assert_predicate(Toys::SourceSpec.path("/p"), :frozen?)
    end
  end

  describe "git" do
    it "creates a Git spec with defaults" do
      spec = Toys::SourceSpec.git("https://example.com/repo.git")
      assert_instance_of(Toys::SourceSpec::Git, spec)
      assert_equal("https://example.com/repo.git", spec.remote)
      assert_nil(spec.path)
      assert_nil(spec.commit)
      assert_equal(false, spec.update)
      assert_nil(spec.context_directory)
      assert_nil(spec.source_name)
    end

    it "creates a Git spec with all attributes" do
      spec = Toys::SourceSpec.git("https://example.com/repo.git",
                                  path: "toys",
                                  commit: "main",
                                  update: true,
                                  context_directory: "/my/context",
                                  source_name: "mysource")
      assert_equal("toys", spec.path)
      assert_equal("main", spec.commit)
      assert_equal(true, spec.update)
      assert_expanded_path("/my/context", spec.context_directory)
      assert_equal("mysource", spec.source_name)
    end

    it "allows a nil remote, which means inherit from the parent" do
      spec = Toys::SourceSpec.git(nil)
      assert_nil(spec.remote)
    end

    it "rejects :parent and :path as a context directory" do
      assert_raises(ArgumentError) do
        Toys::SourceSpec.git("https://example.com/repo.git", context_directory: :parent)
      end
      assert_raises(ArgumentError) do
        Toys::SourceSpec.git("https://example.com/repo.git", context_directory: :path)
      end
    end

    it "does not accept relative paths" do
      assert_raises(ArgumentError) do
        Toys::SourceSpec.git("https://example.com/repo.git", relative_paths: [".toys"])
      end
    end

    it "creates a frozen object" do
      assert_predicate(Toys::SourceSpec.git("https://example.com/repo.git"), :frozen?)
    end
  end

  describe "gem" do
    it "creates a Gem spec with defaults" do
      spec = Toys::SourceSpec.gem("mygem")
      assert_instance_of(Toys::SourceSpec::Gem, spec)
      assert_equal("mygem", spec.name)
      assert_equal([], spec.version)
      assert_nil(spec.path)
      assert_nil(spec.toys_dir)
      assert_nil(spec.context_directory)
      assert_nil(spec.source_name)
    end

    it "creates a Gem spec with all attributes" do
      spec = Toys::SourceSpec.gem("mygem",
                                  version: ["~> 1.0", "< 1.5"],
                                  path: "subdir",
                                  toys_dir: "mytoys",
                                  context_directory: "/my/context",
                                  source_name: "mysource")
      assert_equal(["~> 1.0", "< 1.5"], spec.version)
      assert_equal("subdir", spec.path)
      assert_equal("mytoys", spec.toys_dir)
      assert_expanded_path("/my/context", spec.context_directory)
      assert_equal("mysource", spec.source_name)
    end

    it "normalizes a single version to an array" do
      spec = Toys::SourceSpec.gem("mygem", version: "~> 1.0")
      assert_equal(["~> 1.0"], spec.version)
    end

    it "copies and freezes the version array" do
      versions = ["~> 1.0"]
      spec = Toys::SourceSpec.gem("mygem", version: versions)
      versions << "< 1.5"
      assert_equal(["~> 1.0"], spec.version)
      assert_predicate(spec.version, :frozen?)
    end

    it "rejects :parent and :path as a context directory" do
      assert_raises(ArgumentError) do
        Toys::SourceSpec.gem("mygem", context_directory: :parent)
      end
      assert_raises(ArgumentError) do
        Toys::SourceSpec.gem("mygem", context_directory: :path)
      end
    end

    it "does not accept relative paths" do
      assert_raises(ArgumentError) do
        Toys::SourceSpec.gem("mygem", relative_paths: [".toys"])
      end
    end

    it "creates a frozen object" do
      assert_predicate(Toys::SourceSpec.gem("mygem"), :frozen?)
    end
  end

  describe "block" do
    it "creates a Block spec with defaults" do
      spec = Toys::SourceSpec.block(&my_proc)
      assert_instance_of(Toys::SourceSpec::Block, spec)
      assert_same(my_proc, spec.block)
      assert_nil(spec.context_directory)
      assert_nil(spec.source_name)
    end

    it "creates a Block spec with all attributes" do
      spec = Toys::SourceSpec.block(context_directory: "/my/context", source_name: "mysource", &my_proc)
      assert_same(my_proc, spec.block)
      assert_expanded_path("/my/context", spec.context_directory)
      assert_equal("mysource", spec.source_name)
    end

    it "rejects :parent and :path as a context directory" do
      assert_raises(ArgumentError) do
        Toys::SourceSpec.block(context_directory: :parent, &my_proc)
      end
      assert_raises(ArgumentError) do
        Toys::SourceSpec.block(context_directory: :path, &my_proc)
      end
    end

    it "does not accept relative paths" do
      assert_raises(ArgumentError) do
        Toys::SourceSpec.block(relative_paths: [".toys"], &my_proc)
      end
    end

    it "creates a frozen object" do
      assert_predicate(Toys::SourceSpec.block(&my_proc), :frozen?)
    end
  end

  describe "argument checking" do
    it "requires a path to be a string" do
      error = assert_raises(ArgumentError) { Toys::SourceSpec.path(nil) }
      assert_equal("Illegal path value: nil", error.message)
      assert_raises(ArgumentError) { Toys::SourceSpec.path(12_345) }
      assert_raises(ArgumentError) { Toys::SourceSpec.path(:sym) }
    end

    it "accepts a path-convertible object as a path, converting it to a string" do
      require "pathname"
      spec = Toys::SourceSpec.path(Pathname.new("/path/to/source"))
      assert_expanded_path("/path/to/source", spec.path)
      assert_instance_of(::String, spec.path)
    end

    it "requires each relative path to be a string" do
      error = assert_raises(ArgumentError) { Toys::SourceSpec.path("/p", relative_paths: [".toys", 5]) }
      assert_equal("Illegal relative path value: 5", error.message)
      assert_raises(ArgumentError) { Toys::SourceSpec.path("/p", relative_paths: :toys) }
    end

    it "accepts path-convertible objects as relative paths" do
      require "pathname"
      spec = Toys::SourceSpec.path("/p", relative_paths: [Pathname.new(".toys")])
      assert_equal([".toys"], spec.relative_paths)
    end

    it "requires a source name to be a string if given" do
      error = assert_raises(ArgumentError) { Toys::SourceSpec.path("/p", source_name: :sym) }
      assert_equal("Illegal source_name value: :sym", error.message)
      assert_raises(ArgumentError) { Toys::SourceSpec.block(source_name: 12_345) { nil } }
    end

    it "requires a context directory to be a string if given" do
      error = assert_raises(ArgumentError) { Toys::SourceSpec.git("r", context_directory: 12_345) }
      assert_equal("Illegal context_directory value: 12345", error.message)
    end

    it "requires a git remote to be a string if given" do
      error = assert_raises(ArgumentError) { Toys::SourceSpec.git(12_345) }
      assert_equal("Illegal remote value: 12345", error.message)
    end

    it "requires the other git fields to be strings if given" do
      assert_raises(ArgumentError) { Toys::SourceSpec.git("r", path: 12_345) }
      assert_raises(ArgumentError) { Toys::SourceSpec.git("r", commit: :main) }
    end

    it "requires a git update to be a boolean or an integer" do
      error = assert_raises(ArgumentError) { Toys::SourceSpec.git("r", update: "yes") }
      assert_equal("Illegal update value: \"yes\"", error.message)
      assert_raises(ArgumentError) { Toys::SourceSpec.git("r", update: nil) }
    end

    it "accepts a boolean or an integer git update" do
      assert_equal(true, Toys::SourceSpec.git("r", update: true).update)
      assert_equal(false, Toys::SourceSpec.git("r", update: false).update)
      assert_equal(3600, Toys::SourceSpec.git("r", update: 3600).update)
    end

    it "requires a gem name to be a string" do
      error = assert_raises(ArgumentError) { Toys::SourceSpec.gem(nil) }
      assert_equal("Illegal name value: nil", error.message)
      assert_raises(ArgumentError) { Toys::SourceSpec.gem(:mygem) }
    end

    it "requires each gem version requirement to be a string" do
      error = assert_raises(ArgumentError) { Toys::SourceSpec.gem("g", version: ["~> 1.0", 2]) }
      assert_equal("Illegal version requirement value: 2", error.message)
    end

    it "requires the other gem fields to be strings if given" do
      assert_raises(ArgumentError) { Toys::SourceSpec.gem("g", path: 12_345) }
      assert_raises(ArgumentError) { Toys::SourceSpec.gem("g", toys_dir: 12_345) }
    end

    it "requires a block" do
      error = assert_raises(ArgumentError) { Toys::SourceSpec.block }
      assert_equal("Illegal source block: nil", error.message)
    end
  end

  # Every path a spec holds is normalized at construction, so that downstream
  # consumers can compare paths as strings and can rely on a path remaining
  # correct after the process changes its working directory.
  describe "path normalization" do
    let(:relative_dir) { "some/relative/dir" }

    it "expands a relative path to an absolute path" do
      spec = Toys::SourceSpec.path(relative_dir)
      assert_equal(File.expand_path(relative_dir), spec.path)
    end

    it "collapses dot segments in an absolute path" do
      assert_expanded_path("/path/to/source", Toys::SourceSpec.path("/path/to/other/../source").path)
      assert_expanded_path("/path/to/source", Toys::SourceSpec.path("/path/./to//source").path)
    end

    it "expands a relative context directory to an absolute path" do
      spec = Toys::SourceSpec.path("/p", context_directory: relative_dir)
      assert_equal(File.expand_path(relative_dir), spec.context_directory)
    end

    it "collapses dot segments in an absolute context directory" do
      spec = Toys::SourceSpec.path("/p", context_directory: "/my/other/../context")
      assert_expanded_path("/my/context", spec.context_directory)
    end

    it "converts a path-convertible context directory to a string" do
      require "pathname"
      spec = Toys::SourceSpec.path("/p", context_directory: Pathname.new("/my/context"))
      assert_expanded_path("/my/context", spec.context_directory)
      assert_instance_of(::String, spec.context_directory)
    end

    it "normalizes the context directory of every kind of spec" do
      assert_expanded_path(
        "/my/context", Toys::SourceSpec.git("r", context_directory: "/my/other/../context").context_directory
      )
      assert_expanded_path(
        "/my/context", Toys::SourceSpec.gem("g", context_directory: "/my/other/../context").context_directory
      )
      assert_expanded_path(
        "/my/context",
        Toys::SourceSpec.block(context_directory: "/my/other/../context") { nil }.context_directory
      )
    end

    it "leaves relative paths within a path set relative" do
      spec = Toys::SourceSpec.path("/p", relative_paths: [".toys", ".toys.rb"])
      assert_equal([".toys", ".toys.rb"], spec.relative_paths)
    end

    it "treats two specs naming the same directory differently as equal" do
      spec1 = Toys::SourceSpec.path("/path/to/source")
      spec2 = Toys::SourceSpec.path("/path/to/other/../source")
      assert_equal(spec1, spec2)
      assert_equal(spec1.hash, spec2.hash)
    end
  end

  describe "equality" do
    it "treats path specs with the same fields as equal" do
      spec1 = Toys::SourceSpec.path("/p", relative_paths: [".toys"], source_name: "n")
      spec2 = Toys::SourceSpec.path("/p", relative_paths: [".toys"], source_name: "n")
      assert_equal(spec1, spec2)
      assert(spec1.eql?(spec2))
      assert_equal(spec1.hash, spec2.hash)
    end

    it "distinguishes path specs by their own fields" do
      spec = Toys::SourceSpec.path("/p", relative_paths: [".toys"])
      refute_equal(spec, Toys::SourceSpec.path("/q", relative_paths: [".toys"]))
      refute_equal(spec, Toys::SourceSpec.path("/p", relative_paths: [".toys.rb"]))
      refute_equal(spec, Toys::SourceSpec.path("/p"))
    end

    it "distinguishes specs by base fields" do
      spec = Toys::SourceSpec.path("/p")
      refute_equal(spec, Toys::SourceSpec.path("/p", context_directory: "/p"))
      refute_equal(spec, Toys::SourceSpec.path("/p", source_name: "n"))
    end

    it "treats git specs with the same fields as equal" do
      spec1 = Toys::SourceSpec.git("r", path: "p", commit: "c", update: true)
      spec2 = Toys::SourceSpec.git("r", path: "p", commit: "c", update: true)
      assert_equal(spec1, spec2)
      assert_equal(spec1.hash, spec2.hash)
    end

    it "distinguishes git specs by their own fields" do
      spec = Toys::SourceSpec.git("r", path: "p", commit: "c", update: true)
      refute_equal(spec, Toys::SourceSpec.git("r2", path: "p", commit: "c", update: true))
      refute_equal(spec, Toys::SourceSpec.git("r", path: "p2", commit: "c", update: true))
      refute_equal(spec, Toys::SourceSpec.git("r", path: "p", commit: "c2", update: true))
      refute_equal(spec, Toys::SourceSpec.git("r", path: "p", commit: "c", update: false))
    end

    it "treats gem specs with the same fields as equal" do
      spec1 = Toys::SourceSpec.gem("g", version: "1", path: "p", toys_dir: "t")
      spec2 = Toys::SourceSpec.gem("g", version: ["1"], path: "p", toys_dir: "t")
      assert_equal(spec1, spec2)
      assert_equal(spec1.hash, spec2.hash)
    end

    it "distinguishes gem specs by their own fields" do
      spec = Toys::SourceSpec.gem("g", version: "1", path: "p", toys_dir: "t")
      refute_equal(spec, Toys::SourceSpec.gem("g2", version: "1", path: "p", toys_dir: "t"))
      refute_equal(spec, Toys::SourceSpec.gem("g", version: "2", path: "p", toys_dir: "t"))
      refute_equal(spec, Toys::SourceSpec.gem("g", version: "1", path: "p2", toys_dir: "t"))
      refute_equal(spec, Toys::SourceSpec.gem("g", version: "1", path: "p", toys_dir: "t2"))
    end

    it "compares block specs by proc identity" do
      assert_equal(Toys::SourceSpec.block(&my_proc), Toys::SourceSpec.block(&my_proc))
      refute_equal(Toys::SourceSpec.block(&my_proc), Toys::SourceSpec.block(&my_proc2))
    end

    it "treats specs of different subclasses as unequal" do
      refute_equal(Toys::SourceSpec.path("x"), Toys::SourceSpec.git("x"))
      refute_equal(Toys::SourceSpec.git("x"), Toys::SourceSpec.gem("x"))
      refute_equal(Toys::SourceSpec.gem("x"), Toys::SourceSpec.block(&my_proc))
    end

    it "is not equal to a non-spec object" do
      refute_equal(Toys::SourceSpec.path("x"), "x")
    end

    it "can be used as a hash key" do
      hash = {Toys::SourceSpec.path("/p") => 1}
      assert_equal(1, hash[Toys::SourceSpec.path("/p")])
      assert_nil(hash[Toys::SourceSpec.path("/q")])
    end
  end
end
