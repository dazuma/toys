# frozen_string_literal: true

expand :clean, paths: ["pkg", "tmp"]

expand :gem_build
expand :gem_build, name: "install", install_gem: true
