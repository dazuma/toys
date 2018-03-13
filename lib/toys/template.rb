module Toys
  ##
  # A template definition. Template classes should include this module.
  #
  module Template
    def self.included(mod)
      mod.extend(ClassMethods)
    end

    ##
    # Class methods that will be added to a template class.
    #
    module ClassMethods
      def to_expand(&block)
        @expander = block
      end

      attr_accessor :expander
    end
  end
end
