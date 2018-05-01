append "group-1" do
  tool "tool-1-2" do
    desc "file tool-1-2 short description"
    long_desc "file tool-1-2 long description"

    execute do
      puts "file tool-1-2 execution"
    end
  end
end
