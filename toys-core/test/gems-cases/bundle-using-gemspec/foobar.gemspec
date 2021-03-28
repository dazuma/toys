# frozen_string_literal: true

::Gem::Specification.new do |spec|
  spec.name = "foobar"
  spec.version = "0.0.1"
  spec.summary = "Hello"
  spec.authors = ["Me"]

  spec.files = ::Dir.glob("lib/**/*.rb")
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.4"
  spec.add_dependency "highline", "2.0.1"
end
