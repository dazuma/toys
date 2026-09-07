# frozen_string_literal: true

require "digest"
require "toys-core"
require "toys/utils/gems"

# The user scenario: a lockfile kept somewhere other than beside the gemfile,
# which is what BUNDLE_LOCKFILE is for. Bundler honors this variable from
# version 4 onward; the caller skips this case on earlier ones.
lockfile_path = File.join(__dir__, "custom.lock")
ENV["BUNDLE_LOCKFILE"] = lockfile_path
digest_before = Digest::SHA256.file(lockfile_path).hexdigest

# Load the local bundle. The vendor directory is empty, so this takes the
# install path, which is the one that used to overwrite the user's lockfile.
result = Toys::Utils::Gems.new.bundle(search_dirs: Dir.getwd)
puts "result: #{result.inspect}"

# The user's lockfile must come through untouched. Before the fix, `bundle
# install --gemfile=<temp>` wrote toys' own pinned dependency set here.
digest_after = Digest::SHA256.file(lockfile_path).hexdigest
unless digest_before == digest_after
  raise "custom.lock was modified:\n#{File.read(lockfile_path)}"
end

# The version pinned in that lockfile has to reach the bundle. If the lockfile
# were not found and copied, the bundle would resolve from scratch and take the
# newest highline instead of the pinned one.
require "highline"
loaded_version = Gem.loaded_specs["highline"].version.to_s
unless loaded_version == "2.0.2"
  raise "Wrong highline version #{loaded_version}: the pin in custom.lock was discarded"
end

# Bundler sets BUNDLE_LOCKFILE itself during setup, so toys has to put the
# user's value back.
unless ENV["BUNDLE_LOCKFILE"] == lockfile_path
  raise "Incorrect BUNDLE_LOCKFILE: #{ENV['BUNDLE_LOCKFILE'].inspect}"
end
