# frozen_string_literal: true

require "json"

mixin "release-tools" do
  on_include do
    include(:exec, e: true) unless include?(:exec)
    include(:fileutils) unless include?(:fileutils)
    include(:terminal) unless include?(:terminal)
  end

  def verify_library_versions(vers)
    logger.info("Verifying library versions...")
    lib_vers = ::Toys::VERSION
    unless vers == lib_vers
      error("Tagged version #{vers.inspect} doesn't match toys version #{lib_vers.inspect}.")
    end
    lib_vers = ::Toys::Core::VERSION
    unless vers == lib_vers
      error("Tagged version #{vers.inspect} doesn't match toys-core version #{lib_vers.inspect}.")
    end
    vers
  end

  def verify_changelog_content(name, vers)
    logger.info("Verifying changelog content for #{name}...")
    today = ::Time.now.strftime("%Y-%m-%d")
    entry = []
    state = :start
    path = ::File.join(context_directory, name, "CHANGELOG.md")
    ::File.readlines(path).each do |line|
      case state
      when :start
        if line =~ /^### #{::Regexp.escape(vers)} \/ \d\d\d\d-\d\d-\d\d\n$/
          entry << line
          state = :during
        elsif line =~ /^### /
          error("The first #{name} changelog entry isn't for version #{vers}",
                "It should start with:",
                "### #{vers} / #{today}",
                "But it actually starts with:",
                line)
        end
      when :during
        if line =~ /^### /
          state = :after
        else
          entry << line
        end
      end
    end
    if entry.empty?
      error("The #{name} changelog doesn't have any entries.",
            "The first changelog entry should start with:",
            "### #{vers} / #{today}")
    end
    entry.join
  end

  def verify_git_clean
    logger.info("Verifying git clean...")
    output = capture(["git", "status", "-s"]).strip
    error("There are local git changes that are not committed.") unless output.empty?
  end

  def verify_github_checks
    logger.info("Verifying GitHub checks...")
    ref = capture(["git", "rev-parse", "HEAD"]).strip
    data = capture(["gh", "api", "repos/dazuma/toys/commits/#{ref}/check-runs",
                    "-H", "Accept: application/vnd.github.antiope-preview+json"])
    results = ::JSON.parse(data)
    checks = results["check_runs"]
    error("No checks found for #{ref}") if checks.empty?
    error("Check count mismatch for #{ref}") unless checks.size == results["total_count"]
    checks.each do |check|
      name = check["name"]
      next unless name.start_with?("test")
      error("Check #{name.inspect} is not complete") unless check["status"] == "completed"
      error("Check #{name.inspect} was not successful") unless check["conclusion"] == "success"
    end
  end

  def build_gem(name, version)
    logger.info("Building #{name} #{version} gem...")
    built_file = "pkg/#{name}-#{version}.gem"
    cd(name) do
      mkdir_p("pkg")
      exec(["gem", "build", "#{name}.gemspec", "-o", "pkg/#{name}-#{version}.gem"])
    end
    built_file
  end

  def push_gem(name, version, live_release: false)
    logger.info("Pushing #{name} #{version} gem...")
    cd(name) do
      built_file = "pkg/#{name}-#{version}.gem"
      if live_release
        exec(["gem", "push", built_file])
        puts("SUCCESS: Released #{name} #{version}", :green, :bold)
      else
        error("#{built_file} didn't get built.") unless ::File.file?(built_file)
        puts("SUCCESS: Mock release of #{name} #{version}", :green, :bold)
      end
    end
  end

  def build_docs(name, version, dir)
    logger.info("Building #{name} #{version} docs...")
    cd(name) do
      rm_rf(".yardoc")
      rm_rf("doc")
      exec_separate_tool(["yardoc"])
    end
    rm_rf("#{dir}/gems/#{name}/v#{version}")
    cp_r("#{name}/doc", "#{dir}/gems/#{name}/v#{version}")
  end

  def set_default_docs(version, dir)
    logger.info("Changing default docs version to #{version}...")
    cd(dir) do
      content = ::IO.read("404.html")
      content.sub!(/version = "[\w\.]+";/, "version = \"#{version}\";")
      ::File.open("404.html", "w") do |file|
        file.write(content)
      end
    end
  end
  
  def push_docs(version, dir, live_release: false, git_remote: "origin")
    logger.info("Pushing docs to gh-pages...")
    cd(dir) do
      exec(["git", "add", "."])
      exec(["git", "commit", "-m", "Generate yardocs for version #{version}"])
      if live_release
        exec(["git", "push", git_remote, "gh-pages"])
        puts("SUCCESS: Pushed docs for version #{version}.", :green, :bold)
      else
        puts("SUCCESS: Mock docs push for version #{version}.", :green, :bold)
      end
    end
  end

  def error(message, *more_messages)
    puts(message, :red, :bold)
    more_messages.each { |m| puts(m) }
    exit(1)
  end
end
