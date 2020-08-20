# frozen_string_literal: true

raise "failed!" unless IO.read(find_data("foo/bar.txt")).strip == "ruby"
raise "failed!" unless IO.read(find_data("foo/root.txt")).strip == "root"

tool "foo" do
  raise "failed!" unless IO.read(find_data("foo/bar.txt")).strip == "ruby"
  raise "failed!" unless IO.read(find_data("foo/root.txt")).strip == "root"

  def run
    exit(1) unless IO.read(find_data("foo/bar.txt")).strip == "ruby"
    exit(1) unless IO.read(find_data("foo/root.txt")).strip == "root"
  end
end
