# frozen_string_literal: true

tool "in-sub" do
  def run
    exit(1) unless find_data("foo/sub.txt")
    exit(0)
  end
end
