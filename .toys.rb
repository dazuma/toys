expand(:minitest, test_files: ::Dir.glob("test/*_test.rb"))

expand(:gem_build)

expand(:gem_build, name: "release", push_gem: true, tag: true)

name "install" do
  short_desc "Build and install the current code as a gem"

  use :exec

  execute do
    run("build")
    sh("gem install pkg/toys-#{Toys::VERSION}.gem")
  end
end

name "clean" do
  short_desc "Clean built artifacts"

  use :file_utils

  execute do
    rm_rf("pkg")
    rm_rf("doc")
  end
end
