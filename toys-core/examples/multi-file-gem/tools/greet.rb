# frozen_string_literal: true

desc "Display a simple greeting"
flag :whom, default: "world"
def run
  puts "Hello, #{whom}!"
end
