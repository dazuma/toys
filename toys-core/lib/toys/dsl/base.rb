# frozen_string_literal: true

##
# Create a base class for defining a tool with a given name.
#
# This method returns a base class for defining a tool with a given name.
# This is useful if the naming behavior of {Toys::Tool} is not adequate for
# your tool.
#
# ## Example
#
#     class FooBar < Toys.Tool("Foo_Bar")
#       desc "This is a tool called Foo_Bar"
#
#       def run
#         puts "Foo_Bar called"
#       end
#     end
#
def Toys.Tool(given_name = nil) # rubocop:disable Naming/MethodName
  return ::Toys::Tool if given_name.nil?
  ::Class.new(::Toys::Context) do
    define_singleton_method(:inherited) do |tool_class|
      super(tool_class)
      ::Toys::DSL::Internal.create_class(tool_class, given_name)
    end
  end
end

module Toys
  ##
  # Base class for defining tools
  #
  # This base class provides an alternative to the {Toys::DSL::Tool#tool}
  # directive for defining tools in the Toys DSL. Creating a subclass of
  # `Toys::Tool` will create a tool whose name is the "kebab-case" of the class
  # name. Subclasses can be created only in the context of a tool configuration
  # DSL. Furthermore, a class-defined tool can be created only at the top level
  # of a configuration file, or within another class-defined tool. It cannot
  # be a subtool of a tool block.
  #
  # ## Example
  #
  #     class FooBar < Toys::Tool
  #       desc "This is a tool called foo-bar"
  #
  #       def run
  #         puts "foo-bar called"
  #       end
  #     end
  #
  class Tool < Context
    # @private
    def self.inherited(tool_class)
      super
      DSL::Internal.create_class(tool_class)
    end
  end
end
