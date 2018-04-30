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
  # The object context in effect in a toys configuration file
  #
  class Builder
    def initialize(path, tool, remaining_words, priority, loader, type)
      @path = path
      @tool = tool
      @remaining_words = remaining_words
      @priority = priority
      @loader = loader
      @type = type
    end

    def tool(word, alias_of: nil, &block)
      word = word.to_s
      subtool = @loader.get_tool(@tool.full_name + [word], @priority)
      return self if subtool.nil?
      if alias_of
        if block
          raise ToolDefinitionError, "Cannot take a block with alias_of"
        end
        subtool.make_alias_of_word(alias_of.to_s)
        return self
      end
      next_remaining = Loader.next_remaining_words(@remaining_words, word)
      Builder.build(@path, subtool, next_remaining, @priority, @loader, block, :tool)
      self
    end
    alias name tool

    def append(word, &block)
      word = word.to_s
      subtool = @loader.get_tool(@tool.full_name + [word], nil)
      next_remaining = Loader.next_remaining_words(@remaining_words, word)
      Builder.build(@path, subtool, next_remaining, @priority, @loader, block, :append)
      self
    end

    def group(word, &block)
      word = word.to_s
      subtool = @loader.get_tool(@tool.full_name + [word], @priority)
      return self if subtool.nil?
      next_remaining = Loader.next_remaining_words(@remaining_words, word)
      Builder.build(@path, subtool, next_remaining, @priority, @loader, block, :group)
      self
    end

    def alias_as(word)
      if @tool.root?
        raise ToolDefinitionError, "Cannot make an alias of the root tool"
      end
      if @type == :group || @type == :append
        raise ToolDefinitionError, "Cannot make an alias of a group"
      end
      alias_name = @tool.full_name.slice(0..-2) + [word.to_s]
      alias_tool = @loader.get_tool(alias_name, @priority)
      alias_tool.make_alias_of(@tool.simple_name) if alias_tool
      self
    end

    def alias_of(word)
      if @tool.root?
        raise ToolDefinitionError, "Cannot make the root tool an alias"
      end
      if @type == :group || @type == :append
        raise ToolDefinitionError, "Cannot make a group an alias"
      end
      @tool.make_alias_of(word.to_s)
      self
    end

    def include(path)
      @tool.yield_definition do
        @loader.include_path(path, @tool.full_name, @remaining_words, @priority)
      end
      self
    end

    def expand(template_class, *args)
      unless template_class.is_a?(::Class)
        template_class = template_class.to_s
        file_name =
          template_class
          .gsub(/([a-zA-Z])([A-Z])/) { |_m| "#{$1}_#{$2.downcase}" }
          .downcase
        require "toys/templates/#{file_name}"
        const_name = template_class.gsub(/(^|_)([a-zA-Z0-9])/) { |_m| $2.upcase }
        template_class = Templates.const_get(const_name)
      end
      template = template_class.new(*args)
      yield template if block_given?
      instance_exec(template, &template_class.expander)
      self
    end

    def long_desc(desc)
      if @type == :append
        raise ToolDefinitionError, "Cannot set the description when appending"
      end
      @tool.long_desc = desc
      self
    end

    def desc(desc)
      if @type == :append
        raise ToolDefinitionError, "Cannot set the description when appending"
      end
      @tool.desc = desc
      self
    end
    alias short_desc desc

    def switch(key, *switches,
               accept: nil, default: nil, doc: nil, only_unique: false, handler: nil)
      if @type == :append
        raise ToolDefinitionError, "Cannot add a switch when appending"
      end
      @tool.add_switch(key, *switches,
                       accept: accept, default: default, doc: doc,
                       only_unique: only_unique, handler: handler)
      self
    end

    def required_arg(key, accept: nil, doc: nil)
      if @type == :append
        raise ToolDefinitionError, "Cannot add an argument when appending"
      end
      @tool.add_required_arg(key, accept: accept, doc: doc)
      self
    end

    def optional_arg(key, accept: nil, default: nil, doc: nil)
      if @type == :append
        raise ToolDefinitionError, "Cannot add an argument when appending"
      end
      @tool.add_optional_arg(key, accept: accept, default: default, doc: doc)
      self
    end

    def remaining_args(key, accept: nil, default: [], doc: nil)
      if @type == :append
        raise ToolDefinitionError, "Cannot add an argument when appending"
      end
      @tool.set_remaining_args(key, accept: accept, default: default, doc: doc)
      self
    end

    def execute(&block)
      if @type == :group || @type == :append
        raise ToolDefinitionError, "Cannot set the executor of a group"
      end
      @tool.executor = block
      self
    end

    def helper(name, &block)
      if @type == :group || @type == :append
        raise ToolDefinitionError, "Cannot add a helper to a group"
      end
      @tool.add_helper(name, &block)
      self
    end

    def use(mod)
      if @type == :group || @type == :append
        raise ToolDefinitionError, "Cannot use a helper module in a group"
      end
      @tool.use_module(mod)
      self
    end

    def _binding
      binding
    end

    def self.build(path, tool, remaining_words, priority, loader, source, type)
      builder = new(path, tool, remaining_words, priority, loader, type)
      if type == :append
        eval_source(builder, path, source)
      else
        tool.defining_from(path) do
          eval_source(builder, path, source)
          tool.finish_definition
        end
      end
      tool
    end

    def self.eval_source(builder, path, source)
      case source
      when String
        # rubocop:disable Security/Eval
        eval(source, builder._binding, path, 1)
        # rubocop:enable Security/Eval
      when ::Proc
        builder.instance_eval(&source)
      end
    end
  end
end
