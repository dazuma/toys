require "minitest/focus"

describe "test-bundled1" do
  focus
  it "has focus" do
    assert(true)
  end

  it "does not have focus" do
    assert(false)
  end
end
