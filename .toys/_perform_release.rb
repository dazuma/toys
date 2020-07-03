# frozen_string_literal: true

desc "Perform a full release from Github actions"

long_desc(
  "This tool performs an official release. It is intended to be called from within a Github" \
    " Actions workflow, and may not work if run locally, unless the environment is set up as" \
    " expected."
)

flag :enable_releases, "--enable-releases=BOOL"
flag :release_ref, "--release-ref=REF", default: ::ENV["GITHUB_REF"]
flag :api_key, "--api-key=KEY", default: ::ENV["RUBYGEMS_API_KEY"]
flag :user_name, "--user-name=NAME", default: ::ENV["GIT_USER_NAME"]
flag :user_email, "--user-email=EMAIL", default: ::ENV["GIT_USER_EMAIL"]
flag :gh_pages_dir, "--gh-pages-dir=DIR", default: "tmp"

include :fileutils
include :terminal, styled: true
include :exec, exit_on_nonzero_status: true
include "release-tools"

def run
  cd(context_directory)
  version = parse_ref(release_ref)
  puts("Release of toys #{version} requested.", :yellow, :bold)
  verify_library_versions(version)
  verify_changelog_content("toys-core", version)
  verify_changelog_content("toys", version)
  build_docs("toys-core", version)
  build_docs("toys", version)
  push_docs(version)
  using_api_key(api_key) do
    perform_release("toys-core", version)
    perform_release("toys", version)
  end
end

def parse_ref(ref)
  match = %r{^refs/tags/v(\d+\.\d+\.\d+)$}.match(ref)
  error("Illegal release ref: #{ref}") unless match
  match[1]
end

def build_docs(name, version)
  puts("Building #{name} #{version} docs...", :yellow, :bold)
  cd(name) do
    rm_rf(".yardoc")
    rm_rf("doc")
    exec_tool(["yardoc"])
  end
  rm_rf("#{gh_pages_dir}/gems/#{name}/v#{version}")
  cp_r("#{name}/doc", "#{gh_pages_dir}/gems/#{name}/v#{version}")
end

def push_docs(version)
  puts("Pushing docs to gh-pages...", :yellow, :bold)
  cd(gh_pages_dir) do
    if releases_enabled?
      content = ::IO.read("404.html")
      content.sub!(/version = "[\w\.]+";/, "version = \"#{version}\";")
      ::File.open("404.html", "w") do |file|
        file.write(content)
      end
    end
    exec(["git", "config", "user.email", user_email]) if user_email
    exec(["git", "config", "user.name", user_name]) if user_name
    exec(["git", "add", "."])
    exec(["git", "commit", "-m", "Generate yardocs for version #{version}"])
    exec(["git", "push", "origin", "gh-pages"])
  end
  puts("SUCCESS: Pushed docs for version #{version}.", :green, :bold)
end

def using_api_key(key)
  home_dir = ::ENV["HOME"]
  creds_path = "#{home_dir}/.gem/credentials"
  creds_exist = ::File.exist?(creds_path)
  if creds_exist && !key
    puts("Using existing Rubygems credentials")
    yield
    return
  end
  error("API key not provided") unless key
  error("Cannot set API key because #{creds_path} already exists") if creds_exist
  begin
    mkdir_p("#{home_dir}/.gem")
    ::File.open(creds_path, "w", 0o600) do |file|
      file.puts("---\n:rubygems_api_key: #{api_key}")
    end
    puts("Using provided Rubygems credentials")
    yield
  ensure
    exec(["shred", "-u", creds_path])
  end
end

def perform_release(name, version)
  puts("Building and pushing #{name} #{version} gem...", :yellow, :bold)
  cd(name) do
    mkdir_p("pkg")
    built_file = "pkg/#{name}-#{version}.gem"
    exec(["gem", "build", "#{name}.gemspec", "-o", built_file])
    if releases_enabled?
      exec(["gem", "push", built_file])
      puts("SUCCESS: Released #{name} #{version}", :green, :bold)
    else
      error("#{built_file} didn't get built.") unless ::File.file?(built_file)
      puts("SUCCESS: Mock release of #{name} #{version}", :green, :bold)
    end
  end
end

def releases_enabled?
  /^t/i =~ enable_releases.to_s ? true : false
end
