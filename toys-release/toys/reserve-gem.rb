# frozen_string_literal: true

desc "Reserve a rubygem"

long_desc \
  "This tool generates an empty placeholder rubygem, builds, and releases" \
  " it. This effectively reserves the name, ensuring no one else squats it" \
  " until a real release can be performed.",
  "",
  "Proper credentials for pushing to Rubygems must be present. The easiest" \
  " way to do this is to set the `GEM_HOST_API_KEY` environment variable."

flag :directory, "-d", "--directory=PATH" do
  desc "Where to build the placeholder gem. Defaults to a temporary directory."
end
flag :gem_version, "--gem-version=VERSION", default: "0.0.0" do
  desc "Version to release. Defaults to 0.0.0"
end
flag :yes, "--yes", "-y" do
  desc "Automatically answer yes to all confirmations"
end
flag :dry_run do
  desc "Do not push the gem"
end

required_arg :gem_name, desc: "The name of the gem to reserve"
required_arg :contact, desc: "A contact email or URL"

include :exec, e: true
include :terminal, styled: true
include :fileutils

def run
  check_inputs
  cd(context_directory)
  if directory
    mkdir_p(directory)
    reserve_gem(directory)
  else
    require "tmpdir"
    ::Dir.mktmpdir { |dir| reserve_gem(dir) }
  end
end

def check_inputs
  unless /\A[\w-]+\z/.match?(gem_name)
    logger.error("Illegal gem name: #{gem_name.inspect}")
    exit(1)
  end
  if contact.strip.empty?
    logger.error("Contact info is required")
    exit(1)
  end
  unless /\A0(\.[0-9a-zA-Z]+)*\z/.match?(gem_version)
    logger.error("Placeholder gem version must start with 0.")
    exit(1)
  end
end

def reserve_gem(dir)
  cd(dir) do
    generate_gem
    build_gem
    user_confirmation
    push_gem
    final_result
  end
end

def generate_gem
  require "erb"
  logger.info("Generating placeholder gem into #{::Dir.getwd}")
  generate_file("#{gem_name}.gemspec", "gemspec.erb")
  generate_file("README.md")
  generate_file("lib/#{gem_name}.rb", "entrypoint.rb.erb")
end

def generate_file(file_path, template_path = nil)
  template_path ||= "#{file_path}.erb"
  template_data_path = find_data("reserve-gem/#{template_path}")
  raise "Unable to find template #{template_path}" unless template_data_path
  erb = ::ERB.new(::File.read(template_data_path))
  dir = ::File.dirname(file_path)
  mkdir_p(dir) unless dir == "."
  ::File.write(file_path, erb.result(ErbContext.get(gem_name, gem_version, contact)))
  logger.info("Wrote #{file_path}")
end

def build_gem
  mkdir_p("pkg")
  logger.info("Building gem...")
  exec(["gem", "build", "#{gem_name}.gemspec", "-o", pkg_path])
  logger.info("Gem built to #{pkg_path}")
end

def user_confirmation
  return if yes
  dry_run_suffix = dry_run ? " in DRY RUN mode" : ""
  unless confirm("Push gem #{gem_name} #{gem_version}#{dry_run_suffix}? ", default: false)
    logger.error("Aborted")
    exit(1)
  end
end

def push_gem
  logger.info("Pushing gem...")
  if dry_run
    logger.info("Pushed #{gem_name} #{gem_version} (DRY RUN)")
  else
    exec(["gem", "push", pkg_path])
    logger.info("Pushed #{gem_name} #{gem_version}")
  end
end

def final_result
  if dry_run
    puts("Reserved gem #{gem_name} #{gem_version} (DRY RUN)")
  else
    puts("Reserved gem #{gem_name} #{gem_version}")
  end
end

def pkg_path
  ::File.join("pkg", "#{gem_name}-#{gem_version}.gem")
end

# Context for ERB templates
class ErbContext
  def initialize(gem_name, gem_version, contact)
    @gem_name = gem_name
    @gem_version = gem_version
    @contact = contact
    @date = ::Time.now.utc.strftime("%Y-%m-%d")
  end

  def __binding
    binding
  end

  def self.get(gem_name, gem_version, contact)
    new(gem_name, gem_version, contact).__binding
  end
end
