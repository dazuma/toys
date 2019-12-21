# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

desc "Pushes docs to gh-pages"

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
