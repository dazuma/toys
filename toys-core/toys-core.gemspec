# frozen_string_literal: true

lib = ::File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "toys/core"

::Gem::Specification.new do |spec|
  spec.name = "toys-core"
  spec.version = ::Toys::Core::VERSION
  spec.authors = ["Daniel Azuma"]
  spec.email = ["dazuma@gmail.com"]

  spec.summary = "Framework for creating command line executables"
  spec.description =
    "Toys-Core is the command line tool framework underlying Toys. It can be" \
    " used to create command line executables using the Toys DSL and classes."
  spec.license = "MIT"
  spec.homepage = "https://github.com/dazuma/toys"

  spec.files = ::Dir.glob("lib/**/*.rb") + ::Dir.glob("*.md") +
               ::Dir.glob("docs/*.md") + [".yardopts"]
  spec.required_ruby_version = ">= 2.3.0"
  spec.require_paths = ["lib"]

  spec.add_development_dependency "did_you_mean", "~> 1.0"
  spec.add_development_dependency "highline", "~> 2.0"
  spec.add_development_dependency "minitest", "~> 5.14"
  spec.add_development_dependency "minitest-focus", "~> 1.1"
  spec.add_development_dependency "minitest-rg", "~> 5.2"
  spec.add_development_dependency "rdoc", "~> 6.1.2"
  spec.add_development_dependency "redcarpet", "~> 3.5" unless ::RUBY_PLATFORM == "java"
  spec.add_development_dependency "rubocop", "~> 0.79.0"
  spec.add_development_dependency "yard", "~> 0.9.24"

  if spec.respond_to?(:metadata)
    spec.metadata["changelog_uri"] = "https://github.com/dazuma/toys/blob/master/toys-core/CHANGELOG.md"
    spec.metadata["source_code_uri"] = "https://github.com/dazuma/toys"
    spec.metadata["bug_tracker_uri"] = "https://github.com/dazuma/toys/issues"
    spec.metadata["documentation_uri"] = "https://dazuma.github.io/toys/gems/toys-core/v#{::Toys::Core::VERSION}"
  end
end
