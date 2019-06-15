# frozen_string_literal: true

xpand :clean, paths: ["pkg", "tmp"]

expand :gem_build
expand :gem_build, name: "install", install_gem: true
