short_desc "Category: System commands for toys"

name :version do
  short_desc "Print current toys version"
  execute do
    puts Toys::VERSION
  end
end
