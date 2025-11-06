# frozen_string_literal: true

desc "Check a pull request"

long_desc \
  "This tool is called by a GitHub Actions workflow when any pull request" \
    " is opened or synchronized. It checks the commit messages and/or pull" \
    " request title (as appropriate) for conventional commit style."

flag :event_path, "--event-path=VAL" do
  default ::ENV["GITHUB_EVENT_PATH"]
  desc "Path to the pull request event JSON file"
end

include :exec
include :terminal, styled: true

def run
  setup
  lint_commit_messages if @utils.commit_lint_active?
end

def setup
  ::Dir.chdir(context_directory)

  require "json"
  require "toys/release/environment_utils"
  require "toys/release/pull_request"
  require "toys/release/repo_settings"
  require "toys/release/repository"

  @utils = Toys::Release::EnvironmentUtils.new(self)
  @settings = Toys::Release::RepoSettings.load_from_environment(@utils)
  @repository = Toys::Release::Repository.new(@utils, @settings)

  @utils.error("GitHub event path missing") unless event_path
  pr_resource = ::JSON.parse(::File.read(event_path))["pull_request"]
  @pull_request = Toys::Release::PullRequest.new(@repository, pr_resource)
end

def lint_commit_messages
  errors = []
  shas = find_shas
  if shas.size == 1 || !@settings.commit_lint_merge.intersection(["merge", "rebase"]).empty?
    lint_sha_messages(shas, errors)
  end
  if shas.size > 1 && @settings.commit_lint_merge.include?("squash")
    lint_pr_message(errors)
  end
  if errors.empty?
    puts "No conventional commit format problems found.", :green, :bold
  else
    report_lint_errors(errors)
    if @settings.commit_lint_fail_checks?
      @utils.error("Failing due to conventional commit format problems")
    end
  end
end

def find_shas
  @repository.git_unshallow("origin", branch: @pull_request.head_sha)
  log = capture(["git", "log", "#{@pull_request.base_sha}..#{@pull_request.head_sha}", "--format=%H"], e: true)
  shas = log.split("\n").reverse
  shas.find_all do |sha|
    parents = capture(["git", "show", "-s", "--pretty=%p", sha], e: true).strip.split
    @utils.log("Omitting merge commit #{sha}") if parents.size > 1
    parents.size == 1
  end
end

def lint_sha_messages(shas, errors)
  shas.each do |sha|
    @utils.log("Checking commit #{sha} ...")
    message = capture(["git", "log", "#{sha}^..#{sha}", "--format=%B"], e: true).strip
    lint_message(message) do |err|
      @utils.warning("Commit #{sha}: #{err}")
      suggestion = "Please consider amending the commit message."
      if @settings.commit_lint_merge == ["squash"]
        suggestion += " Alternately, because this pull request will be squashed when merged, you" \
                      " can add multiple commits, and instead make sure the pull request _title_" \
                      " conforms to the Conventional Commit format."
      end
      err =
        [
          "The message for commit #{sha} does not conform to the Conventional Commit format.",
          "",
          "```",
        ] + message.split("\n") + [
          "```",
          "",
          err,
          suggestion,
        ]
      errors << err
    end
  end
end

def lint_pr_message(errors)
  @utils.log("Checking Pull request title ...")
  lint_message(@pull_request.title) do |err|
    @utils.warning("PR title: #{err}")
    header = "The pull request title does not conform to the Conventional Commit format."
    header +=
      if @settings.commit_lint_merge == ["squash"]
        " (The title will be used as the merge commit message when this pull request is merged.)"
      else
        " (The title may be used as the merge commit message if this pull request is squashed" \
          " when merged.)"
      end
    errors << [
      header,
      "",
      "```",
      @pull_request.title,
      "```",
      "",
      err,
    ]
  end
end

def lint_message(message)
  lines = message.split("\n")
  matches = /^([\w-]+)(?:\(([^()]+)\))?!?:\s(.+)$/.match(lines.first)
  unless matches
    yield "The first line should follow the form `<type>: <description>`."
    return
  end
  allowed_types = @settings.commit_lint_allowed_types
  if allowed_types && !allowed_types.include?(matches[1].downcase)
    yield "The type `#{matches[1]}` is not allowed by this repository." \
          " Please use one of the types: `#{allowed_types.inspect}`."
  end
  if lines.size > 1 && !lines[1].empty?
    yield "You may not use multiple conventional commit formatted lines." \
          " If you want to include a body or footers in your commit message," \
          " they must be separated from the main message by a blank line." \
          " If you are making multiple semantic changes, please use separate" \
          " commits/pull requets."
  end
end

def report_lint_errors(errors)
  header = <<~STR
    Please use [Conventional Commit](https://conventionalcommits.org/) format \
    for commit messages and pull request titles. The automated linter found \
    the following problems in this pull request:
  STR
  lines = [header]
  errors.each do |error_lines|
    lines << "" << " *  #{error_lines.first}"
    error_lines[1..].each do |err_line|
      lines << (err_line.empty? ? "" : "    #{err_line}")
    end
  end
  @pull_request.add_comment(lines.join("\n"))
end
