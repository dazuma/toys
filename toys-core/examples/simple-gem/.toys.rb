# frozen_string_literal: true

expand :clean, paths: ["pkg"]

expand :gem_build
expand :gem_build, name: "release", push_gem: true
expand :gem_build, name: "install", install_gem: true
