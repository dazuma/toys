# frozen_string_literal: true

raise "failed!" unless IO.read(find_data("foo/bar.txt")).strip == "ruby"

tool "foo" do
  raise "failed!" unless IO.read(find_data("foo/bar.txt")).strip == "ruby"

  def run
    exit(1) unless IO.read(find_data("foo/bar.txt")).strip == "ruby"
  end
end

tool "type_file" do
  def run
    exit(1) unless find_data("foo/bar.txt", type: :file)
    exit(1) if find_data("foo", type: :file)
    exit(0)
  end
end

tool "type_dir" do
  def run
    exit(1) unless find_data("foo", type: :directory)
    exit(1) if find_data("foo/bar.txt", type: :directory)
    exit(0)
  end
end
