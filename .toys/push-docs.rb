# frozen_string_literal: true

desc "Pushes docs to gh-pages from the local checkout"

flag :tmp_dir, default: "tmp"
flag :default, "--[no-]default", default: true

include :exec, exit_on_nonzero_status: true
include :fileutils
include :terminal

def run
  cd(context_directory)
  version = capture(["./toys-dev", "system", "version"]).strip
  exit(1) unless confirm("Build and push yardocs for version #{version}? ")
  rm_rf("toys/.yardoc")
  rm_rf("toys/doc")
  rm_rf("toys-core/.yardoc")
  rm_rf("toys-core/doc")
  exec_tool(["yardoc"])
  mkdir_p(tmp_dir)
  cd(tmp_dir) do
    rm_rf("toys")
    exec(["git", "clone", "git@github.com:dazuma/toys.git"])
  end
  cd("#{tmp_dir}/toys") do
    exec(["git", "checkout", "gh-pages"])
    rm_rf("gems/toys/v#{version}")
    rm_rf("gems/toys-core/v#{version}")
    cp_r("#{context_directory}/toys/doc", "gems/toys/v#{version}")
    cp_r("#{context_directory}/toys-core/doc", "gems/toys-core/v#{version}")
    if default
      content = ::IO.read("404.html")
      content.sub!(/version = "[\w\.]+";/, "version = \"#{version}\";")
      ::File.open("404.html", "w") do |file|
        file.write(content)
      end
    end
    exec(["git", "add", "."])
    exec(["git", "commit", "-m", "Generate yardocs for version #{version} [ci skip]"])
    exec(["git", "push", "origin", "gh-pages"])
  end
end
