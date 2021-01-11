# frozen_string_literal: true

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
  def self.evaluate(tool_class, words, priority, remaining_words, source, loader)
    namespace = ::Module.new
    namespace.module_eval do
      include ::Toys::Context::Key
      @tool_class = tool_class
    end
    path = source.source_path
    basename = ::File.basename(path).tr(".-", "_").gsub(/\W/, "")
    name = "M#{namespace.object_id}_#{basename}"
    str = build_eval_string(name, ::IO.read(path))
    if str
      const_set(name, namespace)
      ::Toys::DSL::Tool.prepare(tool_class, words, priority, remaining_words, source, loader) do
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
