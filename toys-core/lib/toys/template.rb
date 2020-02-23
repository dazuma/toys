# frozen_string_literal: true

module Toys
  ##
  # A template definition. Template classes should include this module.
  #
  # A template is a configurable set of DSL code that can be run in a toys
  # configuration to automate tool defintion. For example, toys provides a
  # "minitest" template that generates a "test" tool that invokes minitest.
  # Templates will often support configuration; for example the minitest
  # template lets you configure the paths to the test files.
  #
  # ## Usage
  #
  # To create a template, define a class and include this module.
  # The class defines the "configuration" of the template. If your template
  # has options/parameters, you should provide a constructor, and methods
  # appropriate to edit those options. The arguments given to the
  # {Toys::DSL::Tool#expand} method are passed to your constructor, and your
  # template object is passed to any block given to {Toys::DSL::Tool#expand}.
  #
  # Next, in your template class, call the `on_expand` method, which is defined
  # in {Toys::Template::ClassMethods#on_expand}. Pass this a block which
  # defines the implementation of the template. Effectively, the contents of
  # this block are "inserted" into the user's configuration. The template
  # object is passed to the block so you have access to the template options.
  #
  # ## Example
  #
  # This is a simple template that generates a "hello" tool. The tool simply
  # prints a `"Hello, #{name}!"` greeting. The name is set as a template
  # option; it is defined when the template is expanded in a toys
  # configuration.
  #
  #     # Define a template by creating a class that includes Toys::Template.
  #     class MyHelloTemplate
  #       include Toys::Template
  #
  #       # A user of the template may pass an optional name as a parameter to
  #       # `expand`, or leave it as the default of "world".
  #       def initialize(name: "world")
  #         @name = name
  #       end
  #
  #       # The template is passed to the expand block, so a user of the
  #       # template may also call this method to set the name.
  #       attr_accessor :name
  #
  #       # The following block is inserted when the template is expanded.
  #       on_expand do |template|
  #         desc "Prints a greeting to #{template.name}"
  #         tool "templated-greeting" do
  #           to_run do
  #             puts "Hello, #{template.name}!"
  #           end
  #         end
  #       end
  #     end
  #
  # Now you can use the template in your `.toys.rb` file like this:
  #
  #     expand(MyHelloTemplate, name: "rubyists")
  #
  # or alternately:
  #
  #     expand(MyHelloTemplate) do |template|
  #       template.name = "rubyists"
  #     end
  #
  # And it will create a tool called "templated-greeting".
  #
  module Template
    ##
    # Create a template class with the given block.
    #
    # @param block [Proc] Defines the template class.
    # @return [Class]
    #
    def self.create(&block)
      template_class = ::Class.new do
        include ::Toys::Template
      end
      template_class.class_eval(&block) if block
      template_class
    end

    ## @private
    def self.included(mod)
      return if mod.respond_to?(:on_expand)
      mod.extend(ClassMethods)
      mod.include(Context::Key)
    end

    ##
    # Class methods that will be added to a template class.
    #
    module ClassMethods
      ##
      # Define how to expand this template. The given block is passed the
      # template object, and is evaluated in the tool class. It should invoke
      # directives to create tools and other objects.
      #
      # @param block [Proc] The expansion of this template.
      # @return [self]
      #
      def on_expand(&block)
        self.expansion = block
        self
      end
      alias to_expand on_expand

      ##
      # The template expansion proc. This proc is passed the template object,
      # and is evaluted in the tool class. It should invoke directives to
      # create tools and other objects.
      #
      # @return [Proc] The expansion of this template.
      #
      attr_accessor :expansion
    end
  end
end
