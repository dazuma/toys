# frozen_string_literal: true

desc "Create a new git repo"

optional_arg :name, desc: "Name of the directory to create"

include :exec, exit_on_nonzero_status: true
include :fileutils
include :terminal

def run
  if name.nil?
    response = ask("Please enter a directory name: ")
    set(:name, response)
  end
  if File.exist?(name)
    puts("Aborting because #{name} already exists", :red, :bold)
    exit(1)
  end
  logger.info("Creating new repo in directory #{name}...")
  mkdir(name)
  cd(name) do
    create_repo
  end
  puts("Created repo in #{name}", :green, :bold)
end

def create_repo
  exec(["git", "init"])
  File.write(".gitignore", <<~CONTENT)
    tmp
    .DS_STORE
  CONTENT
  # You can add additional files here.
  exec(["git", "add", "."])
  exec(["git", "commit", "-m", "Initial commit"])
end
