# frozen_string_literal: true

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
          eval(str, __binding, path, 0)
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
