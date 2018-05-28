tool "tool-1" do
  desc "file tool-1 short description"
  long_desc "file tool-1 long description"

  def run
    puts "file tool-1 execution"
  end
end

tool "namespace-1" do
  desc "file namespace-1 short description"

  tool "tool-1-1" do
    desc "file tool-1-1 short description"
    long_desc "file tool-1-1 long description"

    def run
      puts "file tool-1-1 execution"
    end
  end
end
