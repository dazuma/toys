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
      def initialize(path, environment_utils, settings)
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
        ChangelogFile.current_version_from_content(content, header_format)
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
        expected_header = format_header(version, ::Time.now.utc)
        version_re = ::Regexp.new("^#{ChangelogFile.header_regex(header_format, version: version)}\n$")
        any_header_re = ::Regexp.new("^#{ChangelogFile.header_regex(header_format)}")
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
      # @param date [Time,String,nil] The date. If not provided, uses the current UTC.
      #
      def append(changeset, version, date: nil)
        @utils.log("Writing version #{version} to changelog #{path}")
        bullet = @settings.changelog_bullet
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
        new_content = old_content.sub(/^(#{ChangelogFile.header_regex(header_format)})$/, "#{new_entry}\n\n\\1")
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
      # @param header_format [String] The header format string containing
      #     `%v` for version and strftime directives for date components.
      # @return [::Gem::Version] Latest version in the changelog
      #
      def self.current_version_from_content(content, header_format)
        regex_str = header_regex(header_format)
        match = ::Regexp.new(regex_str).match(content.to_s)
        match ? ::Gem::Version.new(match[1]) : nil
      end

      ##
      # @private
      #
      # Converts a header format into a regular expression string for
      # matching changelog headers. The `%v` placeholder is replaced with
      # either a specific escaped version or a general version-capturing
      # pattern. Strftime directives (including those with flags and width
      # specifiers) are replaced with appropriate character class patterns.
      #
      # TODO: This does not correctly handle escaped percent signs (`%%`)
      # in the format string. A `%%` sequence (which strftime interprets
      # as a literal `%`) could have its second `%` misidentified as the
      # start of a strftime directive. This is unlikely in practice but
      # may warrant future investigation.
      #
      # @param header_format [String] The header format string.
      # @param version [String,nil] If provided, the regex will match only
      #     this specific version. If nil, the regex captures any version.
      # @return [String] A regular expression string (not a Regexp object).
      #
      def self.header_regex(header_format, version: nil)
        version_re = version ? ::Regexp.escape(version.to_s) : "(#{VERSION_PATTERN})"
        ::Regexp.escape(header_format)
                .gsub("%v", version_re)
                .gsub(/%[-_0^#]?\d*([a-zA-Z])/) do
                  STRFTIME_CONVERSIONS[::Regexp.last_match(1)] || '\S+'
                end
      end

      # @private
      VERSION_PATTERN = '\d+(?:\.[a-zA-Z0-9]+)+'
      private_constant :VERSION_PATTERN

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
      private_constant :STRFTIME_CONVERSIONS

      private

      ##
      # Returns the configured header format string from settings.
      #
      # @return [String] A format string containing `%v` for version and
      #     strftime directives for date components.
      #
      def header_format
        @settings.changelog_release_header_format
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
        date ||= ::Time.now.utc
        date = ::Time.parse(date) if date.is_a?(::String)
        fmt = header_format.gsub("%v", "%%v")
        date.strftime(fmt).gsub("%v", version.to_s)
      end
    end
  end
end
