short_desc "A collection of system commands for toys"
long_desc "A collection of system commands for toys"


name "version" do

  short_desc "Print current toys version"

  execute do
    puts Toys::VERSION
  end

end


name "update" do

  short_desc "Update toys if a newer version is available"

  helper_module :exec

  execute do
    version_info = capture("gem query -q -r -e toys")
    if version_info =~ /toys\s\((.+)\)/
      latest_version = Gem::Version.new($1)
      cur_version = Gem::Version.new(Toys::VERSION)
      if latest_version > cur_version
        logger.warn("Updating toys from #{cur_version} to #{latest_version}...")
        sh("gem install toys")
      else
        logger.warn("Toys is already at the latest version: #{latest_version}")
      end
    else
      logger.error("Could not get latest toys version")
      exit(1)
    end
  end

end
