# frozen_string_literal: true

tool "tool-1" do
  desc "file tool-1 short description"
  long_desc "file tool-1 long description"

  def run
    puts "file tool-1 execution"
  end

  tool "tool-2" do
    desc "file tool-2 short description"

    def run
      puts "file tool-2 execution"
    end

    alias_tool "alias-5", absolute: "tool-3"
  end
end

tool "tool-3" do
  desc "file tool-3 short description"

  def run
    puts "file tool-3 execution"
  end
end

alias_tool "alias-1", "tool-1"
alias_tool "alias-2", "alias-1"
alias_tool "alias-3", "tool-2"
alias_tool "alias-4", "tool-1:tool-2"

alias_tool "circular-1", "circular-2"
alias_tool "circular-2", "circular-3"
alias_tool "circular-3", "circular-1"
