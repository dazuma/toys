include File.join(File.dirname(__dir__), "config-items", ".toys.rb")
include File.join(File.dirname(__dir__), "config-items", ".toys")

name "group-0" do
  include File.join(File.dirname(__dir__), "normal-file-hierarchy")
end
