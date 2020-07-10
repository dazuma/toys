# frozen_string_literal: true

unless defined?(@__toys_dev_gemspec__)
  gem("toys-core", ::Toys::Core::VERSION)
  gem("toys", ::Toys::VERSION) if ::Toys.const_defined?(:VERSION)
end
