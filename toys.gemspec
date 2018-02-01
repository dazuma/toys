lib = File.expand_path "lib", __dir__
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib
require 'toys/version'

Gem::Specification.new do |spec|
  spec.name = "toys"
  spec.version = Toys::VERSION
  spec.authors = ["Daniel Azuma"]
  spec.email = ["dazuma@gmail.com"]

  spec.summary = "Command line tool framework"
  spec.description = "Command line tool framework"
  spec.license = "Apache 2.0"
  spec.homepage = "https://github.com/dazuma/toys"

  spec.files = Dir.glob("lib/**/*.rb") + Dir.glob("bin/*") + ["builtin/system.rb"]
  spec.required_ruby_version = ">= 2.0.0"
  spec.require_paths = ["lib"]

  spec.bindir = "bin"
  spec.executables = ["toys"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rdoc", "~> 4.2"
  spec.add_development_dependency "yard", "~> 0.9"
end
