# frozen_string_literal: true

lib = ::File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "toys/ci/version"

::Gem::Specification.new do |spec|
  spec.name = "toys-ci"
  spec.version = ::Toys::CI::VERSION
  spec.authors = ["Daniel Azuma"]
  spec.email = ["dazuma@gmail.com"]

  spec.summary = "CI system using GitHub Actions and Toys"
  spec.description =
    "Toys-CI is a framework for generating simple CI coordinator tools." \
    " It provides a declarative interface for configuring the tool and" \
    " specifying individual jobs to run. The generated tool runs jobs" \
    " specified using command line arguments, and produces a final report of" \
    " the results."
  spec.license = "MIT"
  spec.homepage = "https://github.com/dazuma/toys"

  spec.files = ::Dir.glob("lib/**/*.rb") +
               ::Dir.glob("toys/**/*.rb") + ::Dir.glob("toys/**/.toys.rb") +
               (::Dir.glob("*.md") - ["CLAUDE.md", "AGENTS.md"]) +
               ::Dir.glob("docs/*.md") + [".yardopts"]
  spec.required_ruby_version = ">= 2.7.0"
  spec.require_paths = ["lib"]

  spec.add_dependency "toys-core", "~> 0.20"

  if spec.respond_to?(:metadata)
    spec.metadata["changelog_uri"] = "https://dazuma.github.io/toys/gems/toys-ci/v#{::Toys::CI::VERSION}/file.CHANGELOG.html"
    spec.metadata["source_code_uri"] = "https://github.com/dazuma/toys/tree/toys-ci/v#{::Toys::CI::VERSION}/toys-ci"
    spec.metadata["bug_tracker_uri"] = "https://github.com/dazuma/toys/issues"
    spec.metadata["documentation_uri"] = "https://dazuma.github.io/toys/gems/toys-ci/v#{::Toys::CI::VERSION}"
  end
end
