describe "test-rack" do
  it "has rack" do
    require "rack"
    assert(defined?(::Rack))
  end
end
