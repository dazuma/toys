# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

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
  # Next, in your template class, call the `to_expand` method, which is defined
  # in {Toys::Template::ClassMethods#to_expand}. Pass this a block which
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
  #       to_expand do |template|
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
      return if mod.respond_to?(:to_expand)
      mod.extend(ClassMethods)
      mod.include(Context::Key)
    end

    ##
    # Class methods that will be added to a template class.
    #
    module ClassMethods
      ##
      # Provide the block that implements the template.
      #
      def to_expand(&block)
        self.expander = block
      end

      ##
      # You may alternately set the expander block using this accessor.
      # @return [Proc]
      #
      attr_accessor :expander
    end
  end
end
