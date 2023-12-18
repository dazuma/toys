# frozen_string_literal: true

##
# This module is the root namespace for tool definitions loaded from files.
# Whenever a toys configuration file is parsed, a module is created under this
# parent for that file's contents. Tool classes defined in that file, along
# with mixins and templates, and any other classes, modules, and constants
# defined, are located within that file's module.
#
module Toys::InputFile # rubocop:disable Style/ClassAndModuleChildren
  ##
  # @private This interface is internal and subject to change without warning.
  #
  def self.evaluate(tool_class, words, priority, remaining_words, source, loader)
    namespace = ::Module.new
    namespace.module_eval do
      include ::Toys::Context::Key
      @__tool_class = tool_class
    end
    path = source.source_path
    basename = ::File.basename(path).tr(".-", "_").gsub(/\W/, "")
    name = "M#{namespace.object_id}_#{basename}"
    str = build_eval_string(name, ::IO.read(path))
    if str
      const_set(name, namespace)
      ::Toys::DSL::Internal.prepare(tool_class, words, priority, remaining_words, source, loader) do
        ::Toys::ContextualError.capture_path("Error while loading Toys config!", path) do
          # rubocop:disable Security/Eval
          eval(str, __binding, path)
          # rubocop:enable Security/Eval
        end
      end
    end
  end

  ##
  # @private
  #
  def self.__binding
    binding
  end

  ##
  # @private
  #
  def self.build_eval_string(module_name, string)
    index = string.index(/^\s*[^#\s]/)
    return nil if index.nil?
    "#{string[0, index]}" \
      "module #{module_name}; @__tool_class.class_eval do; " \
      "#{string[index..-1]}\n" \
      "end; end\n"
  end
end
