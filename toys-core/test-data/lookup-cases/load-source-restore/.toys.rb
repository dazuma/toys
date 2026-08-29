# frozen_string_literal: true

# Loads a nested source in the middle of this file. The source info in effect
# afterwards, and for any tool defined afterwards, must still be this file.
load(::File.join(__dir__, ".toys"))

tool "after-load" do
  def run
    exit(1) unless find_data("foo/root.txt")
    exit(1) if find_data("foo/sub.txt")
    exit(0)
  end
end
