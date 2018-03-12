module Toys
  module Template
    def self.included(mod)
      mod.extend(ClassMethods)
    end

    module ClassMethods
      def to_expand(&block)
        @expander = block
      end

      attr_accessor :expander
    end
  end
end
