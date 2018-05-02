tool "group-1" do
  desc "replacement group-1 short description"

  tool "tool-1-2" do
    desc "replacement tool-1-2 short description"
    long_desc "replacement tool-1-2 long description"

    execute do
      puts "replacement tool-1-2 execution"
    end

    tool "tool-1-2-3" do
      desc "replacement tool-1-2-3 short description"
      long_desc "replacement tool-1-2-3 long description"

      execute do
        puts "replacement tool-1-2-3 execution"
      end
    end
  end
end
