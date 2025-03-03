# frozen_string_literal: true

raise "failed!" unless find_data("foo/bar.txt").nil?

tool "foo" do
  raise "failed!" unless find_data("foo/bar.txt").nil?

  def run
    exit(1) unless find_data("foo/bar.txt").nil?
  end
end
