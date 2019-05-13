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

##
# This module is a namespace for constant scopes. Whenever a configuration file
# is parsed, a module is created under this parent for that file's constants.
#
module Toys::InputFile # rubocop:disable Style/ClassAndModuleChildren
  ## @private
  def self.__binding
    binding
  end

  ## @private
  def self.evaluate(tool_class, remaining_words, source)
    namespace = ::Module.new
    namespace.module_eval do
      include ::Toys::Tool::Keys
      @tool_class = tool_class
    end
    path = source.source_path
    basename = ::File.basename(path).tr(".-", "_").gsub(/\W/, "")
    name = "M#{namespace.object_id}_#{basename}"
    str = build_eval_string(name, ::IO.read(path))
    if str
      const_set(name, namespace)
      ::Toys::DSL::Tool.prepare(tool_class, remaining_words, source) do
        ::Toys::ContextualError.capture_path("Error while loading Toys config!", path) do
          # rubocop:disable Security/Eval
          eval(str, __binding, path, -2)
          # rubocop:enable Security/Eval
        end
      end
    end
  end

  ## @private
  def self.build_eval_string(module_name, string)
    index = string.index(/^\s*[^#\s]/)
    return nil if index.nil?
    "#{string[0, index]}\n" \
      "module #{module_name}\n" \
      "@tool_class.class_eval do\n" \
      "#{string[index..-1]}\n" \
      "end\n" \
      "end\n"
  end
end
