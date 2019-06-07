# frozen_string_literal: true

require "toys-core"

::Gem::Specification.new do |spec|
  spec.name = "toys-core-simple-example"
  spec.version = "0.0.1"
  spec.authors = ["Daniel Azuma"]
  spec.email = ["dazuma@gmail.com.com"]

  spec.summary = "An example command line gem created using toys-core"
  spec.description =
    "An example command line gem created using toys-core. For more" \
    " information on toys-core, see https://github.com/dazuma/toys"
  spec.license = "MIT"
  spec.homepage = "https://github.com/dazuma/toys"

  spec.files = ::Dir.glob("*.md") + ::Dir.glob("bin/*")
  spec.required_ruby_version = ">= 2.4.0"
  spec.require_paths = ["lib"]

  spec.bindir = "bin"
  spec.executables = ["toys-core-simple-example"]

  spec.add_dependency "toys-core", "~> #{::Toys::CORE_VERSION}"
end
