# frozen_string_literal: true

tool "greet" do
  def run
    puts "hello world"
  end
end

tool "echo" do
  flag :shout
  required_arg :message

  def run
    puts shout ? message.upcase : message
  end
end

tool "calc" do
  tool "add" do
    required_arg :a, accept: Integer
    required_arg :b, accept: Integer

    def run
      puts a + b
    end
  end
end
