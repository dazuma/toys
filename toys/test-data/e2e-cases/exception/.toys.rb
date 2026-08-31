# frozen_string_literal: true

tool "boom" do
  def run
    raise "something went wrong"
  end
end

tool "defboom" do
  raise "something went wrong"
end
