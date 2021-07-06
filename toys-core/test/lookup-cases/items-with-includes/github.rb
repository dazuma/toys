# frozen_string_literal: true

load_git(remote: "https://github.com/dazuma/toys.git", commit: "main",
         path: "toys-core/test/lookup-cases/config-items/.toys.rb")
load_git(remote: "https://github.com/dazuma/toys.git", commit: "main",
         path: "toys-core/test/lookup-cases/config-items/.toys")

tool "namespace-0" do
  load_git(remote: "https://github.com/dazuma/toys.git", commit: "main",
          path: "toys-core/test/lookup-cases/normal-file-hierarchy")
end
