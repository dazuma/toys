# frozen_string_literal: true

tool "foo" do
  def run
    puts "FOO SUCCEEDED"
  end
end

tool "bar" do
  def run
    puts "BAR FAILED"
    exit(1)
  end
end
