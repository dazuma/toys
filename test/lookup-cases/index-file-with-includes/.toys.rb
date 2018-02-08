name "tool-1" do
  short_desc "first tool-1 short description"
  long_desc "first tool-1 long description"

  execute do
    puts "first tool-1 execution"
  end
end

include File.join(File.dirname(__dir__), "index-file-only")

name "collection-0" do
  include File.join(File.dirname(__dir__), "normal-file-hierarchy")
end

name "tool-1" do
  short_desc "last tool-1 short description"
  long_desc "last tool-1 long description"

  execute do
    puts "last tool-1 execution"
  end
end
