# frozen_string_literal: true

# A plain Toys::Context subclass is not a tool: no inherited hook fires for it,
# so it never gets any load state.
class Helper < Toys::Context
  class Thing < Toys::Tool
  end
end
