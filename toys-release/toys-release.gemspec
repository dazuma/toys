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
    "Toys-Release is a Ruby library release system using GitHub Actions and" \
    " Toys. It interprets conventional commit message format to automate" \
    " changelog generation and library version updating based on semantic" \
    " versioning, and supports fine tuning and approval of releases using" \
    " GitHub pull requests. Out of the box, Toys-Release knows how to tag" \
    " GitHub releases, build and push gems to Rubygems, and build and" \
    " publish documentation to gh-pages. You can also customize the build" \
    " pipeline and many aspects of its behavior."
  spec.license = "MIT"
  spec.homepage = "https://github.com/dazuma/toys"

  spec.files = ::Dir.glob("lib/**/*.rb") +
               ::Dir.glob("toys/*.rb") + ["toys/.toys.rb"] +
               ::Dir.glob("toys/.lib/**/*.rb") + ::Dir.glob("toys/.data/**/*.erb") +
               ::Dir.glob("*.md") + ::Dir.glob("docs/*.md") + [".yardopts"]
  spec.required_ruby_version = ">= 2.7.0"
  spec.require_paths = ["lib"]

  spec.add_dependency "toys-core", "~> 0.17"

  if spec.respond_to?(:metadata)
    spec.metadata["changelog_uri"] = "https://dazuma.github.io/toys/gems/toys-release/v#{::Toys::Release::VERSION}/file.CHANGELOG.html"
    spec.metadata["source_code_uri"] = "https://github.com/dazuma/toys/tree/main/toys-release"
    spec.metadata["bug_tracker_uri"] = "https://github.com/dazuma/toys/issues"
    spec.metadata["documentation_uri"] = "https://dazuma.github.io/toys/gems/toys-release/v#{::Toys::Release::VERSION}"
  end
end
