# frozen_string_literal: true

required_arg :code

def run
  exit(code.to_i)
end
