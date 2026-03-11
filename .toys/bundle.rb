# frozen_string_literal: true

# Normally you would do the following to load the CI framework:
#     load_gem "toys-ci"
# In this repo we want to use the current HEAD instead, so we manually add
# the lib directory to the load path and load the tool directory directly.
toys_ci_path = ::File.join(::File.dirname(__dir__), "toys-ci")
lib_path = ::File.join(toys_ci_path, "lib")
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
load(::File.join(toys_ci_path, "toys"))

desc "Installs or updates bundles in all gems"

flag :update, desc: "Do a bundle update instead of install"

def bundle_cmd_array
  update ? ["bundle", "update", "--all"] : ["bundle", "install"]
end

expand(Toys::CI::Template) do |ci|
  ci.only_flag = true
  ci.fail_fast_flag = true

  ci.job("Bundle for the root directory", flag: :root) do
    exec(bundle_cmd_array, name: "Bundle for the root directory").success?
  end
  ci.job("Bundle for toys-core", flag: :toys_core) do
    exec(bundle_cmd_array, name: "Bundle for toys-core", chdir: "toys-core").success?
  end
  ci.job("Bundle for toys", flag: :toys) do
    exec(bundle_cmd_array, name: "Bundle for toys", chdir: "toys").success?
  end
  ci.job("Bundle for toys-ci", flag: :toys_ci) do
    exec(bundle_cmd_array, name: "Bundle for toys-ci", chdir: "toys-ci").success?
  end
  ci.job("Bundle for toys-release", flag: :toys_release) do
    exec(bundle_cmd_array, name: "Bundle for toys-release", chdir: "toys-release").success?
  end
end
