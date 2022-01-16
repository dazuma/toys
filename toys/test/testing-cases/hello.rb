# frozen_string_literal: true

flag :shout

def run
  puts "#{message} #{message}"
end

def message
  shout ? "HELLO" : "hello"
end
