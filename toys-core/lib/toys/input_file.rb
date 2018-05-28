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
# Internal modules providing constant namespaces for config files.
#
module Toys::InputFile # rubocop:disable Style/ClassAndModuleChildren
  ## @private
  def self.__binding
    binding
  end

  ## @private
  def self.evaluate(tool_class, remaining_words, path)
    namespace = ::Module.new
    namespace.module_eval do
      include ::Toys::Tool::Keys
      @tool_class = tool_class
    end
    name = "M#{namespace.object_id}"
    const_set(name, namespace)
    str = <<-STR
      module #{name}; @tool_class.class_eval do
      #{::IO.read(path)}
      end end
    STR
    ::Toys::DSL::Tool.prepare(tool_class, remaining_words, path) do
      ::Toys::ContextualError.capture_path("Error while loading Toys config!", path) do
        # rubocop:disable Security/Eval
        eval(str, __binding, path, 0)
        # rubocop:enable Security/Eval
      end
    end
  end
end
