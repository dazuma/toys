# frozen_string_literal: true

require "helper"
require "set"

markdown_files = [
  "README.md",
  "toys/README.md",
  "toys-core/README.md",
  "toys-ci/README.md",
  "toys-release/README.md",
  "toys/docs/guide.md",
  "toys-core/docs/guide.md",
  "toys-release/docs/guide.md",
]

markdown_files.each do |path|
  describe(path) do
    let(:content) { File.read(File.join(::File.dirname(__dir__), path)) }

    # Returns [level, text] pairs for all headers, skipping lines inside HTML comments.
    let(:headers) do
      in_comment = false
      in_codeblock = false
      content.each_line.filter_map do |line|
        in_comment = true if line.start_with?("<!--")
        in_codeblock = true if /^```\w/.match?(line)
        result = line.match(/\A(#+)\s+(.+?)\s*\z/)&.then { |m| [m[1].length, m[2]] } unless in_comment || in_codeblock
        in_comment = false if line.start_with?("-->")
        in_codeblock = false if /^```\n/.match?(line)
        result
      end
    end

    # Converts a header text to its GitHub-style anchor ID.
    def header_to_anchor(text)
      text.downcase.gsub(/[^a-z0-9 -]/, "").tr(" ", "-")
    end

    it "has exactly one H1" do
      h1s = headers.select { |level, _| level == 1 }.map { |_, text| text }
      assert_equal(1, h1s.length, "Expected exactly one H1, found: #{h1s.inspect}")
    end

    it "has no skipped header levels" do
      skips = []
      prev_level = 0
      headers.each do |level, text|
        skips << "\"#{text}\" (h#{level} after h#{prev_level})" if prev_level.positive? && level > prev_level + 1
        prev_level = level
      end
      assert_empty(skips, "Skipped header levels:\n#{skips.join("\n")}")
    end

    it "has no duplicate anchor IDs" do
      anchors = headers.map { |_, text| header_to_anchor(text) }
      duplicates = anchors.tally.select { |_, count| count > 1 }.keys
      assert_empty(duplicates, "Duplicate anchor IDs found: #{duplicates.inspect}")
    end

    it "has no broken internal links" do
      anchor_set = Set.new(headers.map { |_, text| header_to_anchor(text) })
      broken = []
      content.each_line.with_index(1) do |line, lineno|
        line.scan(/(?<!`)\(#([^)]+)\)/) do |match|
          anchor = match[0]
          broken << "line #{lineno}: ##{anchor}" unless anchor_set.include?(anchor)
        end
      end
      assert_empty(broken, "Broken internal links found:\n#{broken.join("\n")}")
    end
  end
end
