# frozen_string_literal: true

tool "tool-1" do
  desc "file tool-1 short description"
  long_desc "file tool-1 long description"

  def run
    puts "file tool-1 execution"
  end
end

alias_tool "alias-1", "tool-1"
alias_tool "alias-2", "alias-1"
