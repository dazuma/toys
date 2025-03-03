require_relative "helper"
require_relative "../.lib/semver"

describe ToysReleaser::Semver do
  def version(str)
    Gem::Version.new(str)
  end

  it "returns the name as a symbol" do
    assert_equal(:major, ToysReleaser::Semver::MAJOR.name)
    assert_equal(:minor, ToysReleaser::Semver::MINOR.name)
    assert_equal(:patch, ToysReleaser::Semver::PATCH.name)
    assert_equal(:patch2, ToysReleaser::Semver::PATCH2.name)
    assert_equal(:none, ToysReleaser::Semver::NONE.name)
  end

  it "returns the name as a string" do
    assert_equal("major", ToysReleaser::Semver::MAJOR.to_s)
    assert_equal("minor", ToysReleaser::Semver::MINOR.to_s)
    assert_equal("patch", ToysReleaser::Semver::PATCH.to_s)
    assert_equal("patch2", ToysReleaser::Semver::PATCH2.to_s)
    assert_equal("none", ToysReleaser::Semver::NONE.to_s)
  end

  it "returns the segment" do
    assert_equal(0, ToysReleaser::Semver::MAJOR.segment)
    assert_equal(1, ToysReleaser::Semver::MINOR.segment)
    assert_equal(2, ToysReleaser::Semver::PATCH.segment)
    assert_equal(3, ToysReleaser::Semver::PATCH2.segment)
    assert_nil(ToysReleaser::Semver::NONE.segment)
  end

  it "determines significance" do
    assert(ToysReleaser::Semver::MAJOR.significant?)
    assert(ToysReleaser::Semver::MINOR.significant?)
    assert(ToysReleaser::Semver::PATCH.significant?)
    assert(ToysReleaser::Semver::PATCH2.significant?)
    refute(ToysReleaser::Semver::NONE.significant?)
  end

  it "compares equality" do
    assert_operator(ToysReleaser::Semver::MAJOR, :==, ToysReleaser::Semver::MAJOR)
    assert_operator(ToysReleaser::Semver::NONE, :==, ToysReleaser::Semver::NONE)
    assert_operator(ToysReleaser::Semver::MAJOR, :!=, ToysReleaser::Semver::NONE)
  end

  it "compares ordering" do
    assert_operator(ToysReleaser::Semver::MAJOR, :>, ToysReleaser::Semver::MINOR)
    assert_operator(ToysReleaser::Semver::PATCH, :>, ToysReleaser::Semver::NONE)
    assert_operator(ToysReleaser::Semver::MINOR, :<, ToysReleaser::Semver::MAJOR)
    assert_operator(ToysReleaser::Semver::NONE, :<, ToysReleaser::Semver::PATCH)
  end

  it "bumps a version" do
    assert_equal(version("2.0.0"), ToysReleaser::Semver::MAJOR.bump(version("1.2.3.4")))
    assert_equal(version("1.3.0"), ToysReleaser::Semver::MINOR.bump(version("1.2.3.4")))
    assert_equal(version("1.2.4"), ToysReleaser::Semver::PATCH.bump(version("1.2.3.4")))
    assert_equal(version("1.2.3.5"), ToysReleaser::Semver::PATCH2.bump(version("1.2.3.4")))
    assert_equal(version("1.2.3.4"), ToysReleaser::Semver::NONE.bump(version("1.2.3.4")))
  end

  it "looks up semvers by name" do
    assert_equal(ToysReleaser::Semver::MAJOR, ToysReleaser::Semver.for_name(:major))
    assert_equal(ToysReleaser::Semver::MAJOR, ToysReleaser::Semver.for_name("major"))
    assert_equal(ToysReleaser::Semver::MAJOR, ToysReleaser::Semver.for_name("MAJOR"))
    assert_equal(ToysReleaser::Semver::MINOR, ToysReleaser::Semver.for_name(:minor))
    assert_equal(ToysReleaser::Semver::PATCH, ToysReleaser::Semver.for_name(:patch))
    assert_equal(ToysReleaser::Semver::PATCH2, ToysReleaser::Semver.for_name(:patch2))
    assert_equal(ToysReleaser::Semver::NONE, ToysReleaser::Semver.for_name(:none))
  end
end
