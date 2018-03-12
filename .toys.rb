expand :minitest do |t|
  t.libs << "test"
  t.files << "test/*_test.rb"
end

expand :gem_build

expand :gem_build, name: "release" do |t|
  t.push_gem = true
  t.tag = true
end

expand :yardoc

expand :clean do |t|
  t.paths = ["pkg", "doc", ".yardoc"]
end

name "install" do
  short_desc "Build and install the current code as a gem"

  use :exec

  execute do
    run("build")
    sh("gem install pkg/toys-#{Toys::VERSION}.gem")
  end
end
