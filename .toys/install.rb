# frozen_string_literal: true

desc "Build and install the current gems"

include :terminal

def handle_gem(gem_name)
  puts("**** Installing #{gem_name} from local build...", :bold, :cyan)
  ::Dir.chdir(::File.join(context_directory, gem_name)) do
    status = cli.child.add_config_path(".toys.rb").run("install", "-y")
    exit(status) unless status.zero?
  end
end

def run
  handle_gem("toys-core")
  handle_gem("toys")
end
