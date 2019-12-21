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

desc "Cleans both gems"

include :terminal
include :fileutils

def handle_gem(gem_name)
  puts("**** Cleaning #{gem_name}...", :bold, :cyan)
  cd(::File.join(context_directory, gem_name)) do
    status = cli.child.add_config_path(".toys.rb").run("clean")
    exit(status) unless status.zero?
  end
end

def handle_dir(path)
  if ::File.exist?(path)
    rm_rf(path)
    puts "Cleaned: #{path}"
  end
end

def run
  handle_gem("toys-core")
  handle_gem("toys")
  cd(context_directory) do
    puts("**** Cleaning toplevel directory...", :bold, :cyan)
    handle_dir("tmp")
  end
end
