# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::Semver do
  def version(str)
    Gem::Version.new(str)
  end
  let(:major) { Toys::Release::Semver::MAJOR }
  let(:minor) { Toys::Release::Semver::MINOR }
  let(:patch) { Toys::Release::Semver::PATCH }
  let(:patch2) { Toys::Release::Semver::PATCH2 }
  let(:none) { Toys::Release::Semver::NONE }

  describe "#name" do
    it "works on major" do
      assert_equal(:major, major.name)
    end

    it "works on minor" do
      assert_equal(:minor, minor.name)
    end

    it "works on patch" do
      assert_equal(:patch, patch.name)
    end

    it "works on patch2" do
      assert_equal(:patch2, patch2.name)
    end

    it "works on none" do
      assert_equal(:none, none.name)
    end
  end

  describe "#to_s" do
    it "works on major" do
      assert_equal("major", major.to_s)
    end

    it "works on minor" do
      assert_equal("minor", minor.to_s)
    end

    it "works on patch" do
      assert_equal("patch", patch.to_s)
    end

    it "works on patch2" do
      assert_equal("patch2", patch2.to_s)
    end

    it "works on none" do
      assert_equal("none", none.to_s)
    end
  end

  describe "#segment" do
    it "works on major" do
      assert_equal(0, major.segment)
    end

    it "works on minor" do
      assert_equal(1, minor.segment)
    end

    it "works on patch" do
      assert_equal(2, patch.segment)
    end

    it "works on patch2" do
      assert_equal(3, patch2.segment)
    end

    it "works on none" do
      assert_nil(none.segment)
    end
  end

  describe "#significant?" do
    it "works on major" do
      assert(major.significant?)
    end

    it "works on minor" do
      assert(minor.significant?)
    end

    it "works on patch" do
      assert(patch.significant?)
    end

    it "works on patch2" do
      assert(patch2.significant?)
    end

    it "works on none" do
      refute(none.significant?)
    end
  end

  describe "comparison operators" do
    it "compares equality" do
      assert_operator(major, :==, major)
    end

    it "compares equality for NONE" do
      assert_operator(none, :==, none)
    end

    it "compares inequality" do
      assert_operator(major, :!=, none)
    end

    it "compares greater than" do
      assert_operator(major, :>, minor)
    end

    it "compares greater than when none is included" do
      assert_operator(patch, :>, none)
    end

    it "compares less than" do
      assert_operator(minor, :<, major)
    end

    it "compares less than when none is included" do
      assert_operator(none, :<, patch)
    end
  end

  describe ".for_name" do
    it "accepts the symbol :major" do
      assert_equal(major, Toys::Release::Semver.for_name(:major))
    end

    it "accepts a string" do
      assert_equal(major, Toys::Release::Semver.for_name("major"))
    end

    it "downcases a string" do
      assert_equal(major, Toys::Release::Semver.for_name("MAJOR"))
    end

    it "accepts :minor" do
      assert_equal(minor, Toys::Release::Semver.for_name(:minor))
    end

    it "accepts :patch" do
      assert_equal(patch, Toys::Release::Semver.for_name(:patch))
    end

    it "accepts :patch2" do
      assert_equal(patch2, Toys::Release::Semver.for_name(:patch2))
    end

    it "accepts :none" do
      assert_equal(none, Toys::Release::Semver.for_name(:none))
    end
  end

  describe ".for_diff" do
    it "notices the same version" do
      assert_equal(none, Toys::Release::Semver.for_diff("1.2.3", "1.2.3"))
    end

    it "notices the same version with different trailing zeros" do
      assert_equal(none, Toys::Release::Semver.for_diff("1.2.0", "1.2"))
    end

    it "notices the second version being larger at the major level" do
      assert_equal(major, Toys::Release::Semver.for_diff("0.2.0", "1.2.0"))
    end

    it "notices the first version being larger at the major level" do
      assert_equal(major, Toys::Release::Semver.for_diff("1.2.0", "0.2.0"))
    end

    it "notices a minor version difference with trailing zeros" do
      assert_equal(minor, Toys::Release::Semver.for_diff("1.2.0", "1.3.0"))
    end

    it "notices a minor version difference when the difference is in extra fields" do
      assert_equal(patch, Toys::Release::Semver.for_diff("1.2", "1.2.1"))
    end

    it "notices a patch2 difference when the difference is in extra fields" do
      assert_equal(patch2, Toys::Release::Semver.for_diff("1.2", "1.2.0.1"))
    end

    it "treats smaller differences than patch2 as patch2" do
      assert_equal(patch2, Toys::Release::Semver.for_diff("1.2", "1.2.0.0.1"))
    end

    it "treats nils as the same" do
      assert_equal(none, Toys::Release::Semver.for_diff(nil, nil))
    end

    it "treats nil as 0 in a difference with a real version" do
      assert_equal(patch, Toys::Release::Semver.for_diff(nil, "0.0.1"))
    end
  end

  describe "#max" do
    it "compares major/minor" do
      assert_equal(major, major.max(minor))
    end

    it "compares minor/major" do
      assert_equal(major, minor.max(major))
    end

    it "compares patch/none" do
      assert_equal(patch, patch.max(none))
    end

    it "compares none/patch" do
      assert_equal(patch, none.max(patch))
    end
  end

  describe "#bump" do
    it "bumps major" do
      assert_equal("2.0.0.0", major.bump(version("1.2.3.4")).to_s)
    end

    it "bumps major with a fill length" do
      assert_equal("2.0.0", major.bump(version("1.2.3.4"), minimum_fill: patch).to_s)
    end

    it "bumps major with a very small fill length" do
      assert_equal("2", major.bump(version("1.2.3.4"), minimum_fill: major).to_s)
    end

    it "bumps minor" do
      assert_equal("1.3.0.0", minor.bump(version("1.2.3.4")).to_s)
    end

    it "bumps minor with a fill length" do
      assert_equal("1.3.0", minor.bump(version("1.2.3.4"), minimum_fill: patch).to_s)
    end

    it "bumps patch" do
      assert_equal("1.2.4.0", patch.bump(version("1.2.3.4")).to_s)
    end

    it "bumps patch with a fill length that is short" do
      assert_equal("1.2.4", patch.bump(version("1.2.3.4"), minimum_fill: minor).to_s)
    end

    it "bumps patch2" do
      assert_equal("1.2.3.5", patch2.bump(version("1.2.3.4")).to_s)
    end

    it "bumps patch2 when the original was short by two" do
      assert_equal("1.2.0.1", patch2.bump(version("1.2")).to_s)
    end

    it "bumps patch2 when the original was short by one" do
      assert_equal("1.2.3.1", patch2.bump(version("1.2.3")).to_s)
    end

    it "bumps none" do
      assert_equal("1.2.3.4", none.bump(version("1.2.3.4")).to_s)
    end

    it "bumps from nil" do
      assert_equal("0.1.0", minor.bump(nil).to_s)
    end

    it "bumps to 1.0 if prevent_bump_to_v1 is off" do
      assert_equal("1.0", major.bump(version("0.2")).to_s)
    end

    it "bumps to 0.x if prevent_bump_to_v1 is on" do
      assert_equal("0.3", major.bump(version("0.2"), prevent_bump_to_v1: true).to_s)
    end
  end
end
