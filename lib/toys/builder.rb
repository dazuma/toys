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
    def initialize(path, tool, remaining_words, priority, lookup)
      @path = path
      @tool = tool
      @remaining_words = remaining_words
      @priority = priority
      @lookup = lookup
    end

    def name(word, alias_of: nil, &block)
      word = word.to_s
      subtool = @lookup.get_tool(@tool.full_name + [word], @priority)
      return self if subtool.nil?
      if alias_of
        if block
          raise ToolDefinitionError, "Cannot take a block with alias_of"
        end
        subtool.make_alias_of_word(alias_of.to_s)
        return self
      end
      next_remaining = Lookup.next_remaining_words(@remaining_words, word)
      Builder.build(@path, subtool, next_remaining, @priority, @lookup, block)
      self
    end

    def alias_as(word)
      if @tool.root?
        raise ToolDefinitionError, "Cannot make an alias of the root tool"
      end
      alias_name = @tool.full_name.slice(0..-2) + [word.to_s]
      alias_tool = @lookup.get_tool(alias_name, @priority)
      alias_tool.make_alias_of(@tool.simple_name) if alias_tool
      self
    end

    def alias_of(word)
      @tool.make_alias_of(word.to_s)
      self
    end

    def include(path)
      @tool.yield_definition do
        @lookup.include_path(path, @tool.full_name, @remaining_words, @priority)
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
      @tool.long_desc = desc
      self
    end

    def short_desc(desc)
      @tool.short_desc = desc
      self
    end
    alias desc short_desc

    def switch(key, *switches, accept: nil, default: nil, doc: nil)
      @tool.add_switch(key, *switches, accept: accept, default: default, doc: doc)
      self
    end

    def required_arg(key, accept: nil, doc: nil)
      @tool.add_required_arg(key, accept: accept, doc: doc)
      self
    end

    def optional_arg(key, accept: nil, default: nil, doc: nil)
      @tool.add_optional_arg(key, accept: accept, default: default, doc: doc)
      self
    end

    def remaining_args(key, accept: nil, default: [], doc: nil)
      @tool.set_remaining_args(key, accept: accept, default: default, doc: doc)
      self
    end

    def execute(&block)
      @tool.executor = block
      self
    end

    def helper(name, &block)
      @tool.add_helper(name, &block)
      self
    end

    def use(mod)
      @tool.use_module(mod)
      self
    end

    def _binding
      binding
    end

    def self.build(path, tool, remaining_words, priority, lookup, source)
      builder = new(path, tool, remaining_words, priority, lookup)
      tool.defining_from(path) do
        case source
        when String
          # rubocop:disable Security/Eval
          eval(source, builder._binding, path, 1)
          # rubocop:enable Security/Eval
        when ::Proc
          builder.instance_eval(&source)
        end
      end
      tool
    end
  end
end
