name "tool-1" do
  short_desc "tool-1 short description"
  long_desc "tool-1 long description"

  execute do
    puts "tool-1 execution"
  end
end

name "tool-2" do
  short_desc "tool-2 short description"
  long_desc "tool-2 long description"

  execute do
    puts "tool-2 execution"
  end
end

name "collection-1" do
  short_desc "collection-1 short description"

  name "tool-1-1" do
    short_desc "tool-1-1 short description"
    long_desc "tool-1-1 long description"

    execute do
      puts "tool-1-1 execution"
    end
  end

  name "tool-1-2" do
    short_desc "tool-1-2 short description"
    long_desc "tool-1-2 long description"

    execute do
      puts "tool-1-2 execution"
    end
  end
end
