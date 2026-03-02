# frozen_string_literal: true

truncate_load_path!

expand :rspec, name: "spec-without", pattern: "spec/*_spec.rb"

expand :rspec, name: "spec-bundle", pattern: "spec/*_spec.rb", bundler: true
