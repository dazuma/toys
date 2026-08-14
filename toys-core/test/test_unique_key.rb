# frozen_string_literal: true

require "helper"

describe Toys::UniqueKey do
  it "returns unique objects each time, even if they have the same name" do
    obj1 = Toys::UniqueKey.new("hello")
    obj2 = Toys::UniqueKey.new("hello")
    refute_equal(obj1, obj2)
  end

  it "gets the name of an object" do
    obj1 = Toys::UniqueKey.new("hello")
    assert_equal("hello", obj1.to_s)
    assert_equal("hello", obj1.inspect)
  end

  it "constructs a name from the object ID when no name is given" do
    obj1 = Toys::UniqueKey.new
    assert_includes(obj1.to_s, obj1.object_id.to_s)
    assert_equal(obj1.to_s, obj1.inspect)
  end

  it "constructs a distinct name for each object when no name is given" do
    obj1 = Toys::UniqueKey.new
    obj2 = Toys::UniqueKey.new
    refute_equal(obj1.to_s, obj2.to_s)
  end

  it "freezes the name" do
    assert(Toys::UniqueKey.new("hello").to_s.frozen?)
    assert(Toys::UniqueKey.new.to_s.frozen?)
  end

  it "does not alias a name string that is later modified" do
    str = +"hello"
    obj1 = Toys::UniqueKey.new(str)
    str << " there"
    assert_equal("hello", obj1.to_s)
  end

  describe "toys-core constants" do
    # The number of unique keys currently defined in toys-core. This is a lower
    # bound guarding against the check below silently walking nothing, as would
    # happen if the eager require were dropped and lazily-loaded modules such as
    # the standard mixins were never reached.
    MINIMUM_KEY_COUNT = 32

    def check_constants(mod, visited, count)
      # A visited set is required rather than a namespace check, because the
      # constant graph may contain a cycle wholly within the Toys namespace.
      return count if visited[mod]
      visited[mod] = true
      mod.constants(false).each do |name|
        value = mod.const_get(name)
        case value
        when ::Module
          count = check_constants(value, visited, count)
        when Toys::UniqueKey
          assert_equal("#{mod.name}::#{name}", value.to_s)
          count += 1
        end
      end
      count
    end

    it "names all unique keys after their constant path" do
      # Lazily-loaded files must be loaded for their keys to be reachable.
      lib_dir = ::File.expand_path("../lib", __dir__)
      ::Dir.glob("#{lib_dir}/**/*.rb").sort.each { |path| require path }
      count = check_constants(Toys, {}, 0)
      assert_operator(count, :>=, MINIMUM_KEY_COUNT)
    end
  end
end
