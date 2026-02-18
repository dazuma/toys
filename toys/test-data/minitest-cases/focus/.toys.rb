# frozen_string_literal: true

truncate_load_path!

expand :minitest, name: "test-without", files: "foo.rb"

expand :minitest, name: "test-direct", files: "foo.rb", minitest_focus: true

expand :minitest, name: "test-bundle", files: "foo.rb", bundler: true
