# frozen_string_literal: true

class Foo < Toys::Tool
  # subtool_apply reads the current tool without activating it. That is the
  # read that prepare_subclass pre-seeds when it configures this class.
  subtool_apply do
    long_desc "applied to subtools of foo"
  end

  tool "bar" do
    def run; end
  end
end
