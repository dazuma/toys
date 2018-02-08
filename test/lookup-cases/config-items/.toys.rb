name "tool-1" do
  short_desc "file tool-1 short description"
  long_desc "file tool-1 long description"

  execute do
    puts "file tool-1 execution"
  end
end

name "collection-1" do
  short_desc "file collection-1 short description"

  name "tool-1-1" do
    short_desc "file tool-1-1 short description"
    long_desc "file tool-1-1 long description"

    execute do
      puts "file tool-1-1 execution"
    end
  end
end
