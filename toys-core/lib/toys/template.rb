# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
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
  #           run do
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
    ## @private
    def self.included(mod)
      mod.extend(ClassMethods)
      mod.include(Tool::Keys)
    end

    ##
    # Class methods that will be added to a template class.
    #
    module ClassMethods
      ##
      # Provide the block that implements the template.
      #
      def to_expand(&block)
        @expander = block
      end

      ##
      # You may alternately set the expander block using this accessor.
      # @return [Proc]
      #
      attr_accessor :expander
    end
  end
end
