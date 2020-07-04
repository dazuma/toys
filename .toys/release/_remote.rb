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
  logger.info("Release of toys #{version} requested.", :yellow, :bold)

  verify_library_versions(version)
  verify_changelog_content("toys-core", version)
  verify_changelog_content("toys", version)
  verify_github_checks()

  build_gem("toys-core", version)
  build_gem("toys", version)
  build_docs("toys-core", version, gh_pages_dir)
  build_docs("toys", version, gh_pages_dir)
  set_default_docs(version, gh_pages_dir)

  setup_git_config(gh_pages_dir)
  using_api_key(api_key) do
    push_gem("toys-core", version, live_release: releases_enabled?)
    push_gem("toys", version, live_release: releases_enabled?)
    push_docs(version, gh_pages_dir, live_release: releases_enabled?)
  end
end

def parse_ref(ref)
  match = %r{^refs/tags/v(\d+\.\d+\.\d+(?:\.(?:\d+|[a-zA-Z][\w]*))*)$}.match(ref)
  error("Illegal release ref: #{ref}") unless match
  match[1]
end

def setup_git_config(dir)
  cd(dir) do
    exec(["git", "config", "user.email", user_email]) if user_email
    exec(["git", "config", "user.name", user_name]) if user_name
  end
end

def using_api_key(key)
  home_dir = ::ENV["HOME"]
  creds_path = "#{home_dir}/.gem/credentials"
  creds_exist = ::File.exist?(creds_path)
  if creds_exist && !key
    logger.info("Using existing Rubygems credentials")
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
    logger.info("Using provided Rubygems credentials")
    yield
  ensure
    exec(["shred", "-u", creds_path])
  end
end

def releases_enabled?
  /^t/i =~ enable_releases.to_s ? true : false
end
