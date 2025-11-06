# frozen_string_literal: true

# load_git remote: "https://github.com/dazuma/toys.git",
#          path: "common-tools/release",
#          update: true
# load "#{__dir__}/../common-tools/release"

load_gem("toys-release", version: "~> 0.17")
