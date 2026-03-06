# frozen_string_literal: true

require "helper"
require "set"

describe "user guide" do
  let(:guide_path) { File.join(__dir__, "../docs/guide.md") }
  let(:guide_content) { File.read(guide_path) }

  # Returns [level, text] pairs for all headers, skipping lines inside HTML comments.
  let(:guide_headers) do
    in_comment = false
    guide_content.each_line.filter_map do |line|
      in_comment = true if line.include?("<!--")
      result = line.match(/\A(#+)\s+(.+?)\s*\z/)&.then { |m| [m[1].length, m[2]] } unless in_comment
      in_comment = false if line.include?("-->")
      result
    end
  end

  # Converts a header text to its GitHub-style anchor ID.
  def header_to_anchor(text)
    text.downcase.gsub(/[^a-z0-9 -]/, "").tr(" ", "-")
  end

  it "has exactly one H1" do
    h1s = guide_headers.select { |level, _| level == 1 }.map { |_, text| text }
    assert_equal(1, h1s.length, "Expected exactly one H1, found: #{h1s.inspect}")
  end

  it "has no skipped header levels" do
    skips = []
    prev_level = 0
    guide_headers.each do |level, text|
      skips << "\"#{text}\" (h#{level} after h#{prev_level})" if prev_level.positive? && level > prev_level + 1
      prev_level = level
    end
    assert_empty(skips, "Skipped header levels:\n#{skips.join("\n")}")
  end

  it "has no duplicate anchor IDs" do
    anchors = guide_headers.map { |_, text| header_to_anchor(text) }
    duplicates = anchors.tally.select { |_, count| count > 1 }.keys
    assert_empty(duplicates, "Duplicate anchor IDs found: #{duplicates.inspect}")
  end

  it "has no broken internal links" do
    anchor_set = Set.new(guide_headers.map { |_, text| header_to_anchor(text) })
    broken = []
    guide_content.each_line.with_index(1) do |line, lineno|
      line.scan(/\(#([^)]+)\)/) do |match|
        anchor = match[0]
        broken << "line #{lineno}: ##{anchor}" unless anchor_set.include?(anchor)
      end
    end
    assert_empty(broken, "Broken internal links found:\n#{broken.join("\n")}")
  end
end
