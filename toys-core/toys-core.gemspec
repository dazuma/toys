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

  if spec.respond_to?(:metadata)
    spec.metadata["changelog_uri"] = "https://dazuma.github.io/toys/gems/toys-core/v#{::Toys::Core::VERSION}/file.CHANGELOG.html"
    spec.metadata["source_code_uri"] = "https://github.com/dazuma/toys"
    spec.metadata["bug_tracker_uri"] = "https://github.com/dazuma/toys/issues"
    spec.metadata["documentation_uri"] = "https://dazuma.github.io/toys/gems/toys-core/v#{::Toys::Core::VERSION}"
  end
end
