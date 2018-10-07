# frozen_string_literal: true

raise "failed!" unless IO.read(find_data("foo/bar.txt")).strip == "toys"

tool "foo" do
  raise "failed!" unless IO.read(find_data("foo/bar.txt")).strip == "toys"

  def run
    exit(1) unless IO.read(find_data("foo/bar.txt")).strip == "toys"
  end
end
