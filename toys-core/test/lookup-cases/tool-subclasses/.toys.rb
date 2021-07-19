# frozen_string_literal: true

class Foo < Toys::Tool
  desc "description of foo"

  def foo
    exit 9
  end

  def run
    foo
  end
end

class FooBar < Toys::Tool
  desc "description of foo-bar"

  class Baz < Toys.Tool()
    desc "description of foo-bar baz"
  end

  tool "qux" do
    desc "description of foo-bar qux"
  end
end

class Quux < Toys.Tool("qu_ux")
  desc "description of qu_ux"

  def quux
    exit 8
  end

  def run
    quux
  end
end

class FooChild1 < Foo
  desc "description of foo-child1"

  def run
    foo
  end
end

class FooChild2 < Toys.Tool(name: "foo_child2", base: Foo)
  desc "description of foo_child2"

  def run
    foo
  end
end

class QuuxChild1 < Quux
  desc "description of quux-child1"

  def run
    quux
  end
end

class QuuxChild2 < Toys.Tool("quux_child2", Quux)
  desc "description of quux_child2"

  def run
    quux
  end
end
