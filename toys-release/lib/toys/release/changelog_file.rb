# frozen_string_literal: true

module Toys
  module Release
    ##
    # Represents a changelog read from a file.
    #
    class ChangelogFile
      ##
      # Create a changelog file object given a file path
      #
      # @param path [String] File path
      # @param environmentUtils [Toys::Release::EnvironmentUtils]
      #
      def initialize(path, environment_utils)
        @path = path
        @utils = environment_utils
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
      #
      def content
        ::File.read(@path)
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
        today = ::Time.now.strftime("%Y-%m-%d")
        entry = []
        state = :start
        ::File.readlines(@path).each do |line|
          case state
          when :start
            case line
            when %r{^### v#{::Regexp.escape(version)} / \d\d\d\d-\d\d-\d\d\n$}
              entry << line
              state = :during
            when /^### /
              @utils.error("The first changelog entry in #{path} isn't for version #{version}.",
                           "It should start with:",
                           "### v#{version} / #{today}",
                           "But it actually starts with:",
                           line)
              entry << line
              state = :during
            end
          when :during
            break if line =~ /^### /
            entry << line
          end
        end
        if entry.empty?
          @utils.error("The changelog #{path} doesn't have any entries.",
                       "The first changelog entry should start with:",
                       "### v#{version} / #{today}")
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
      #
      def append(changeset, version, date: nil)
        date ||= ::Time.now.utc
        date = date.strftime("%Y-%m-%d") if date.respond_to?(:strftime)
        new_entry = [
          "### v#{version} / #{date}",
          "",
        ]
        changeset.change_groups.each do |group|
          new_entry.concat(group.prefixed_changes.map { |line| "* #{line}" })
        end
        new_entry = new_entry.join("\n")
        new_content = content.sub(%r{^(### v\S+ / \d\d\d\d-\d\d-\d\d)$}, "#{new_entry}\n\n\\1")
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
    end
  end
end
