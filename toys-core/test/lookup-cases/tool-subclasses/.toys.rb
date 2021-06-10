# frozen_string_literal: true

class Foo < Toys::Tool
  desc "description of foo"
end

class FooBar < Toys::Tool
  desc "description of foo-bar"

  class Baz < Toys::Tool
    desc "description of foo-bar baz"
  end

  tool "qux" do
    desc "description of foo-bar qux"
  end
end
