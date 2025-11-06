# frozen_string_literal: true

lib = ::File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "toys/release/version"

::Gem::Specification.new do |spec|
  spec.name = "toys-release"
  spec.version = ::Toys::Release::VERSION
  spec.authors = ["Daniel Azuma"]
  spec.email = ["dazuma@gmail.com"]

  spec.summary = "Release system using GitHub Actions and Toys"
  spec.description =
    "Toys-Release is a library release system using GitHub Actions and Toys." \
      " It generates "
  spec.license = "MIT"
  spec.homepage = "https://github.com/dazuma/toys"

  spec.files = ::Dir.glob("lib/**/*.rb") +
               ::Dir.glob("*.md") + ::Dir.glob("docs/*.md") +
               ::Dir.glob("toys/*.rb") + ["toys/.toys.rb"] +
               ::Dir.glob("toys/.data/**/*.erb") +
               [".yardopts"]
  spec.required_ruby_version = ">= 2.7.0"
  spec.require_paths = ["lib"]

  spec.add_dependency "toys-core", "~> 0.16"

  if spec.respond_to?(:metadata)
    spec.metadata["changelog_uri"] = "https://dazuma.github.io/toys/gems/toys-release/v#{::Toys::Release::VERSION}/file.CHANGELOG.html"
    spec.metadata["source_code_uri"] = "https://github.com/dazuma/toys/tree/main/toys-release"
    spec.metadata["bug_tracker_uri"] = "https://github.com/dazuma/toys/issues"
    spec.metadata["documentation_uri"] = "https://dazuma.github.io/toys/gems/toys-release/v#{::Toys::Release::VERSION}"
  end
end
