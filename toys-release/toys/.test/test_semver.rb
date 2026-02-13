# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::Semver do
  def version(str)
    Gem::Version.new(str)
  end

  it "returns the name as a symbol" do
    assert_equal(:major, Toys::Release::Semver::MAJOR.name)
    assert_equal(:minor, Toys::Release::Semver::MINOR.name)
    assert_equal(:patch, Toys::Release::Semver::PATCH.name)
    assert_equal(:patch2, Toys::Release::Semver::PATCH2.name)
    assert_equal(:none, Toys::Release::Semver::NONE.name)
  end

  it "returns the name as a string" do
    assert_equal("major", Toys::Release::Semver::MAJOR.to_s)
    assert_equal("minor", Toys::Release::Semver::MINOR.to_s)
    assert_equal("patch", Toys::Release::Semver::PATCH.to_s)
    assert_equal("patch2", Toys::Release::Semver::PATCH2.to_s)
    assert_equal("none", Toys::Release::Semver::NONE.to_s)
  end

  it "returns the segment" do
    assert_equal(0, Toys::Release::Semver::MAJOR.segment)
    assert_equal(1, Toys::Release::Semver::MINOR.segment)
    assert_equal(2, Toys::Release::Semver::PATCH.segment)
    assert_equal(3, Toys::Release::Semver::PATCH2.segment)
    assert_nil(Toys::Release::Semver::NONE.segment)
  end

  it "determines significance" do
    assert(Toys::Release::Semver::MAJOR.significant?)
    assert(Toys::Release::Semver::MINOR.significant?)
    assert(Toys::Release::Semver::PATCH.significant?)
    assert(Toys::Release::Semver::PATCH2.significant?)
    refute(Toys::Release::Semver::NONE.significant?)
  end

  it "compares equality" do
    assert_operator(Toys::Release::Semver::MAJOR, :==, Toys::Release::Semver::MAJOR)
    assert_operator(Toys::Release::Semver::NONE, :==, Toys::Release::Semver::NONE)
    assert_operator(Toys::Release::Semver::MAJOR, :!=, Toys::Release::Semver::NONE)
  end

  it "compares ordering" do
    assert_operator(Toys::Release::Semver::MAJOR, :>, Toys::Release::Semver::MINOR)
    assert_operator(Toys::Release::Semver::PATCH, :>, Toys::Release::Semver::NONE)
    assert_operator(Toys::Release::Semver::MINOR, :<, Toys::Release::Semver::MAJOR)
    assert_operator(Toys::Release::Semver::NONE, :<, Toys::Release::Semver::PATCH)
  end

  it "bumps a version" do
    assert_equal(version("2.0.0"), Toys::Release::Semver::MAJOR.bump(version("1.2.3.4")))
    assert_equal(version("1.3.0"), Toys::Release::Semver::MINOR.bump(version("1.2.3.4")))
    assert_equal(version("1.2.4"), Toys::Release::Semver::PATCH.bump(version("1.2.3.4")))
    assert_equal(version("1.2.3.5"), Toys::Release::Semver::PATCH2.bump(version("1.2.3.4")))
    assert_equal(version("1.2.3.4"), Toys::Release::Semver::NONE.bump(version("1.2.3.4")))
  end

  it "looks up semvers by name" do
    assert_equal(Toys::Release::Semver::MAJOR, Toys::Release::Semver.for_name(:major))
    assert_equal(Toys::Release::Semver::MAJOR, Toys::Release::Semver.for_name("major"))
    assert_equal(Toys::Release::Semver::MAJOR, Toys::Release::Semver.for_name("MAJOR"))
    assert_equal(Toys::Release::Semver::MINOR, Toys::Release::Semver.for_name(:minor))
    assert_equal(Toys::Release::Semver::PATCH, Toys::Release::Semver.for_name(:patch))
    assert_equal(Toys::Release::Semver::PATCH2, Toys::Release::Semver.for_name(:patch2))
    assert_equal(Toys::Release::Semver::NONE, Toys::Release::Semver.for_name(:none))
  end

  it "analyzes the diff between versions" do
    assert_equal(Toys::Release::Semver::NONE, Toys::Release::Semver.for_diff("1.2.3", "1.2.3"))
    assert_equal(Toys::Release::Semver::NONE, Toys::Release::Semver.for_diff("1.2.0", "1.2"))
    assert_equal(Toys::Release::Semver::MAJOR, Toys::Release::Semver.for_diff("0.2.0", "1.2.0"))
    assert_equal(Toys::Release::Semver::MAJOR, Toys::Release::Semver.for_diff("1.2.0", "0.2.0"))
    assert_equal(Toys::Release::Semver::MINOR, Toys::Release::Semver.for_diff("1.2.0", "1.3.0"))
    assert_equal(Toys::Release::Semver::PATCH, Toys::Release::Semver.for_diff("1.2", "1.2.1"))
    assert_equal(Toys::Release::Semver::PATCH2, Toys::Release::Semver.for_diff("1.2", "1.2.0.1"))
    assert_equal(Toys::Release::Semver::PATCH2, Toys::Release::Semver.for_diff("1.2", "1.2.0.0.1"))
    assert_equal(Toys::Release::Semver::NONE, Toys::Release::Semver.for_diff(nil, nil))
    assert_equal(Toys::Release::Semver::PATCH, Toys::Release::Semver.for_diff(nil, "0.0.1"))
  end

  it "returns a max" do
    assert_equal(Toys::Release::Semver::MAJOR, Toys::Release::Semver::MAJOR.max(Toys::Release::Semver::MINOR))
    assert_equal(Toys::Release::Semver::MAJOR, Toys::Release::Semver::MINOR.max(Toys::Release::Semver::MAJOR))
    assert_equal(Toys::Release::Semver::PATCH, Toys::Release::Semver::PATCH.max(Toys::Release::Semver::NONE))
    assert_equal(Toys::Release::Semver::PATCH, Toys::Release::Semver::NONE.max(Toys::Release::Semver::PATCH))
  end
end
