::Gem::Specification.new do |spec|
  spec.name = "foobar"
  spec.version = "0.0.1"
  spec.summary = "Hello"
  spec.authors = ["Me"]

  spec.files = ::Dir.glob("lib/**/*.rb")
  spec.require_paths = ["lib"]

  spec.add_dependency "highline", "2.0.1"
end
