# frozen_string_literal: true

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
