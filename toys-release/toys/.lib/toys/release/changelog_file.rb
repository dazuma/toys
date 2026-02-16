# frozen_string_literal: true

require "time"

module Toys
  module Release
    ##
    # Represents a changelog read from a file.
    #
    class ChangelogFile
      ##
      # @return [String] The default header used when there is no changelog.
      #
      DEFAULT_HEADER = "# Changelog\n"

      ##
      # Create a changelog file object given a file path
      #
      # @param path [String] File path
      # @param environment_utils [Toys::Release::EnvironmentUtils]
      # @param settings [Toys::Release::RepoSettings] Repository settings
      #
      def initialize(path, environment_utils, settings = nil)
        @path = path
        @utils = environment_utils
        @settings = settings
      end

      ##
      # @return [String] Path to the changelog file
      #
      attr_reader :path

      ##
      # @return [boolean] Whether the file exists
      #
      def exists?
        ::File.file?(path)
      end

      ##
      # @return [String] Current contents of the changelog
      # @return [nil] if the changelog file doesn't exist
      #
      def content
        ::File.file?(path) ? ::File.read(path) : nil
      end

      ##
      # @return [::Gem::Version,nil] Current latest version from the changelog
      #
      def current_version
        ChangelogFile.current_version_from_content(content)
      end

      ##
      # Reads the latest changelog entry and verifies that it accurately
      # reflects the given version.
      #
      # @param version [String,::Gem::Version] Release version to verify.
      # @return [String] The multiline changelog entry, or the empty string if
      #     there are no entries.
      #
      def read_and_verify_latest_entry(version) # rubocop:disable Metrics/MethodLength
        version = version.to_s
        @utils.log("Verifying #{path} changelog content...")
        expected_header = format_header(version, ::Time.now)
        version_re = ::Regexp.new("^#{header_regex(version: version)}\n$")
        any_header_re = ::Regexp.new("^#{header_regex}")
        entry = []
        state = :start
        ::File.readlines(@path).each do |line|
          case state
          when :start
            case line
            when version_re
              entry << line
              state = :during
            when any_header_re
              @utils.error("The first changelog entry in #{path} isn't for version #{version}.",
                           "It should start with:",
                           expected_header,
                           "But it actually starts with:",
                           line)
              entry << line
              state = :during
            end
          when :during
            break if any_header_re.match?(line)
            entry << line
          end
        end
        if entry.empty?
          @utils.error("The changelog #{path} doesn't have any entries.",
                       "The first changelog entry should start with:",
                       expected_header)
        else
          @utils.log("Changelog OK")
        end
        entry.join
      end

      ##
      # Append a new entry to the changelog.
      #
      # @param changeset [ChangeSet] The changeset.
      # @param version [String] The release version.
      # @param date [String] The date. If not provided, uses the current UTC.
      # @param bullet [String] The bullet character for list items. Defaults to "*".
      #
      def append(changeset, version, date: nil, bullet: "*")
        @utils.log("Writing version #{version} to changelog #{path}")
        header_line = format_header(version, date)
        new_entry = [
          header_line,
          "",
        ]
        changeset.change_groups.each do |group|
          new_entry.concat(group.prefixed_changes.map { |line| "#{bullet} #{line}" })
        end
        new_entry = new_entry.join("\n")
        old_content = content || DEFAULT_HEADER
        new_content = old_content.sub(/^(#{header_regex})$/, "#{new_entry}\n\n\\1")
        if new_content == old_content
          new_content = old_content.sub(/\n+\z/, "\n\n#{new_entry}\n")
        end
        ::File.write(path, new_content)
        self
      end

      ##
      # Returns the current version from the given file content
      #
      # @param content [String] File contents
      # @return [::Gem::Version] Latest version in the changelog
      #
      def self.current_version_from_content(content)
        match = %r{### v(\d+(?:\.[a-zA-Z0-9]+)+) / \d\d\d\d-\d\d-\d\d}.match(content)
        match ? ::Gem::Version.new(match[1]) : nil
      end

      private

      # @private
      VERSION_PATTERN = '\d+(?:\.[a-zA-Z0-9]+)+'

      # @private
      # Maps strftime conversion characters to regex patterns.
      # Flags and width specifiers (e.g. %-d, %02m) are handled by
      # header_regex via a general pattern match.
      STRFTIME_CONVERSIONS = {
        "Y" => '\d{4}',
        "m" => '\d{1,2}',
        "d" => '\d{1,2}',
        "B" => '\w+',
        "b" => '\w+',
        "e" => '[\d ]\d',
      }.freeze

      ##
      # Returns the configured header format string, falling back to the
      # default format if no settings are provided.
      #
      # @return [String] A format string containing `%v` for version and
      #     strftime directives for date components.
      #
      def header_format
        (@settings&.changelog_release_header_format) || "### v%v / %Y-%m-%d"
      end

      ##
      # Generates a formatted header line by substituting the version and
      # formatting the date using strftime directives from the header format.
      #
      # @param version [String] The release version string.
      # @param date [Time,String,nil] The release date. If nil, defaults to
      #     the current UTC time. Strings are parsed via `Time.parse`.
      # @return [String] The formatted header line.
      #
      def format_header(version, date)
        date = ::Time.now.utc unless date
        date = ::Time.parse(date) if date.is_a?(::String)
        fmt = header_format.gsub("%v", "%%v")
        date.strftime(fmt).gsub("%v", version.to_s)
      end

      ##
      # Converts the header format into a regular expression string for
      # matching changelog headers. The `%v` placeholder is replaced with
      # either a specific escaped version or a general version pattern.
      # Strftime directives (including those with flags and width
      # specifiers) are replaced with appropriate character class patterns.
      #
      # @param version [String,nil] If provided, the regex will match only
      #     this specific version. If nil, the regex captures any version.
      # @return [String] A regular expression string (not a Regexp object).
      #
      def header_regex(version: nil)
        version_re = version ? ::Regexp.escape(version.to_s) : VERSION_PATTERN
        result = ::Regexp.escape(header_format)
        result = result.gsub("%v", version_re)
        result = result.gsub(/%[-_0^#]?\d*([a-zA-Z])/) do
          STRFTIME_CONVERSIONS[::Regexp.last_match(1)] || '\S+'
        end
        result
      end
    end
  end
end
