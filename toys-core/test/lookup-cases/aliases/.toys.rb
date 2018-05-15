tool "tool-1" do
  desc "file tool-1 short description"
  long_desc "file tool-1 long description"
  alias_as "alias-1"

  script do
    puts "file tool-1 execution"
  end
end

alias_tool "alias-2", "alias-1"
