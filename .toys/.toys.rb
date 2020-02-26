# frozen_string_literal: true

# Run this against local Toys code instead of installed Toys gems.
# This is to support development of Toys itself. Most Toys files should not
# include this.
::Kernel.exec(::File.join(context_directory, "toys-dev"), *::ARGV) unless ::ENV["TOYS_DEV"]

mixin "release-tools" do
  on_include do
    include :terminal unless include?(:terminal)
  end

  def verify_library_versions(vers)
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

  def verify_changelog_content(dir, vers)
    today = ::Time.now.strftime("%Y-%m-%d")
    entry = []
    state = :start
    path = ::File.join(context_directory, dir, "CHANGELOG.md")
    ::File.readlines(path).each do |line|
      case state
      when :start
        if line =~ /^### #{::Regexp.escape(vers)} \/ \d\d\d\d-\d\d-\d\d\n$/
          entry << line
          state = :during
        elsif line =~ /^### /
          error("The first #{dir} changelog entry isn't for version #{vers}",
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
      error("The #{dir} changelog doesn't have any entries.",
            "The first changelog entry should start with:",
            "### #{vers} / #{today}")
    end
    entry.join
  end

  def error(message, *more_messages)
    puts(message, :red, :bold)
    more_messages.each { |m| puts(m) }
    exit(1)
  end
end
