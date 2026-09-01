# frozen_string_literal: true

class Foo < Toys::Tool
  desc "description of foo"
end

tool "foo", if_defined: :reset do
  desc "reset description of foo"
end
