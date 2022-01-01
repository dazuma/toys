# frozen_string_literal: true

desc "Git-cache management tools"

long_desc \
  "Tools that manage the git cache.",
  "",
  "The Toys::Utils::GitCache class manages a cache of files from remote git repoistories." \
    " It is used when loading tools from git, and can also be used directly by tools to access" \
    " files from a remote git repository such as from GitHub.",
  "",
  "The tools in the `system git-cache` namespace can show the current contents of the git-cache," \
    " as well as clear data from it."

tool "list" do
  desc "Output a list of the git repositories in the cache."

  long_desc \
    "Outputs a list of the git remotes for the repositories in the cache, in YAML format, to" \
      " the standard output stream."

  flag :cache_dir, "--cache-dir=PATH" do
    desc "The base directory for the cache. Optional. Defaults to the standard cache directory."
  end

  def run
    require "psych"
    require "toys/utils/git_cache"
    git_cache = ::Toys::Utils::GitCache.new(cache_dir: cache_dir)
    output = {
      "cache_dir" => git_cache.cache_dir,
      "remotes" => git_cache.remotes,
    }
    puts(::Psych.dump(output))
  end
end

tool "show" do
  desc "Output information about the specified git repo in the cache."

  long_desc \
    "Outputs information about the git repo specified by the given remote, in YAML format, to" \
      " the standard output stream."

  required_arg :remote, desc: "The git remote identifying the repo. Required."

  flag :cache_dir, "--cache-dir=PATH" do
    desc "The base directory for the cache. Optional. Defaults to the standard cache directory."
  end

  def run
    require "psych"
    require "toys/utils/git_cache"
    git_cache = ::Toys::Utils::GitCache.new(cache_dir: cache_dir)
    info = git_cache.repo_info(remote)
    if info.nil?
      logger.fatal("Unknown remote: #{remote}")
      exit(1)
    end
    puts(::Psych.dump(info.to_h))
  end
end

tool "get" do
  desc "Get files from the git cache, loading from the repo if necessary."

  long_desc \
    "Get files from the git cache, loading from the repo if necessary, and output the path to" \
      " the files to the standard output stream.",
    "",
    "The resulting files are either served from a shared source directory, or copied into aa" \
      " directory specified by the `--into=` flag. If you use the shared directory, do not" \
      " modify the files or directory structure, or other callers will see your modifications."

  required_arg :remote, desc: "The git remote identifying the repo. Required."

  flag :cache_dir, "--cache-dir=PATH" do
    desc "The base directory for the cache. Optional. Defaults to the standard cache directory."
  end

  flag :path, "--path=PATH" do
    desc "A path to a specific file or directory in the repository. Optional. Defaults to the" \
         " entire repository."
  end

  flag :commit, "--commit=REF", "--ref=REF" do
    desc "The commit, which may be a SHA, branch, tag, or HEAD (the default). Optional."
  end

  flag :update do
    desc "Update refs, such as branches, from the remote repo."
  end

  flag :into, "--into=DIR" do
    desc "Copy files into the given directory rather than returning a shared directory."
  end

  def run
    require "toys/utils/git_cache"
    git_cache = ::Toys::Utils::GitCache.new(cache_dir: cache_dir)
    out = git_cache.get(remote, path: path, commit: commit, into: into, update: update)
    puts(out)
  rescue ::Toys::Utils::GitCache::Error => e
    logger.fatal(e.message)
    exit(1)
  end
end

tool "remove" do
  desc "Remove the given repositories from the cache."

  long_desc \
    "Remove the given repositories, including local clones and all shared source directories," \
      " from the cache. The next time any of these repositories is requested, it will be" \
      " reloaded from the remote repository from scratch.",
    "",
    "You can remove specific repositories by providing their remotes as arguments, or remove all" \
      " repositories from the cache by specifying the `--all` flag.",
    "",
    "Be careful not to clear repos that are currently in use by other processes. This command" \
      " may delete files that are in use by other git-cache clients."

  remaining_args :remotes, desc: "The git remote(s) identifying the repo(s) to remove."

  flag :cache_dir, "--cache-dir=PATH" do
    desc "The base directory for the cache. Optional. Defaults to the standard cache directory."
  end

  flag :all do
    desc "Remove all repositories. Required unless specific remotes are provided."
  end

  def run
    require "psych"
    require "toys/utils/git_cache"
    if remotes.empty? == !all
      logger.fatal("You must specify at least one remote to clear, or --all to clear all remotes.")
      exit(2)
    end
    git_cache = ::Toys::Utils::GitCache.new(cache_dir: cache_dir)
    removed = git_cache.remove_repos(all ? :all : remotes)
    output = {
      "removed" => removed,
    }
    puts(::Psych.dump(output))
  end
end

tool "remove-refs" do
  desc "Removes records of the given refs from the cache."

  long_desc \
    "Removes records of the given refs (i.e. branches, tags, or HEAD) from the cache for the" \
      " given repo. The next time any of these refs are requested, they will be pulled fresh" \
      " from the remote repo.",
    "",
    "You must provide either the `--all` flag to remove all refs, or at least one `--ref=` flag" \
      " to remove specific refs.",
    "",
    "Outputs a list of the refs actually removed, in YAML format, to the standard output stream."

  required_arg :remote, desc: "The git remote identifying the repo. Required."

  exactly_one_required do
    flag :refs, "--ref=REF", handler: :push do
      desc "Remove a specific ref."
    end

    flag :all do
      desc "Remove all refs."
    end
  end

  flag :cache_dir, "--cache-dir=PATH" do
    desc "The base directory for the cache. Optional. Defaults to the standard cache directory."
  end

  def run
    require "psych"
    require "toys/utils/git_cache"
    git_cache = ::Toys::Utils::GitCache.new(cache_dir: cache_dir)
    removed = git_cache.remove_refs(remote, refs: refs)
    if removed.nil?
      logger.fatal("Unknown remote: #{remote}")
      exit(1)
    end
    output = {
      "remote" => remote,
      "removed_refs" => removed.map(&:to_h),
    }
    puts(::Psych.dump(output))
  end
end

tool "remove-sources" do
  desc "Removes shared sources from the cache."

  long_desc \
    "Removes the specified shared sources from the cache for the given repository. The next time" \
      " these files are retrieved, they will be recopied from the repository.",
    "",
    "You must provide either the `--all` flag to remove all sources associated with the repo," \
      " or at least one `--commit=` flag to remove sources for specific commits.",
    "",
    "Outputs a list of the sources actually removed, in YAML format, to the standard output stream."

  required_arg :remote, desc: "The git remote identifying the repo. Required."

  exactly_one_required do
    flag :commits, "--commit=REF", handler: :push do
      desc "Remove sources associated with a specific commit."
    end

    flag :all do
      desc "Remove all sources."
    end
  end

  flag :cache_dir, "--cache-dir=PATH" do
    desc "The base directory for the cache. Optional. Defaults to the standard cache directory."
  end

  def run
    require "psych"
    require "toys/utils/git_cache"
    git_cache = ::Toys::Utils::GitCache.new(cache_dir: cache_dir)
    removed = git_cache.remove_sources(remote, commits: commits)
    if removed.nil?
      logger.fatal("Unknown remote: #{remote}")
      exit(1)
    end
    output = {
      "remote" => remote,
      "removed_sources" => removed.map(&:to_h),
    }
    puts(::Psych.dump(output))
  end
end
