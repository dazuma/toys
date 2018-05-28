append "namespace-1" do
  tool "tool-1-2" do
    desc "file tool-1-2 short description"
    long_desc "file tool-1-2 long description"

    def run
      puts "file tool-1-2 execution"
    end
  end
end
