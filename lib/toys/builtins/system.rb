short_desc "A collection of system commands for toys"
long_desc "A collection of system commands for toys"

name :version do
  short_desc "Print current toys version"
  execute do
    puts Toys::VERSION
  end
end
