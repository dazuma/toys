# frozen_string_literal: true

require "helper"

describe Toys::FlagGroup do
  def add_flags(group)
    flag = Toys::Flag.create(:flag1, group: group)
    group << flag
    flag = Toys::Flag.create(:flag2, group: group)
    group << flag
    flag = Toys::Flag.create(:flag3, group: group)
    group << flag
  end

  def assert_errors_include(expected, errors)
    return if errors.any? do |err|
      case expected
      when ::String
        err.message == expected
      when ::Class
        err.is_a?(expected)
      end
    end
    flunk("Errors #{errors.inspect} did not include expected #{expected.inspect}")
  end

  describe "Required" do
    it "validates with all flags set" do
      group = Toys::FlagGroup::Required.new(nil, nil, nil)
      add_flags(group)
      assert_empty(group.validation_errors([:flag1, :flag2, :flag3]))
    end

    it "fails to validate with a flag missing" do
      group = Toys::FlagGroup::Required.new(nil, nil, nil)
      add_flags(group)
      assert_errors_include('Flag "--flag2" is required.',
                            group.validation_errors([:flag1, :flag3]))
    end
  end

  describe "Optional" do
    it "validates with all flags set" do
      group = Toys::FlagGroup::Optional.new(nil, nil, nil)
      add_flags(group)
      assert_empty(group.validation_errors([:flag1, :flag2, :flag3]))
    end

    it "Validates with no flags set" do
      group = Toys::FlagGroup::Optional.new(nil, nil, nil)
      add_flags(group)
      assert_empty(group.validation_errors([]))
    end
  end

  describe "ExactlyOne" do
    it "validates with one flag set" do
      group = Toys::FlagGroup::ExactlyOne.new(nil, nil, nil)
      add_flags(group)
      assert_empty(group.validation_errors([:flag2]))
    end

    it "fails to validate with no flags set" do
      group = Toys::FlagGroup::ExactlyOne.new(nil, nil, nil)
      add_flags(group)
      assert_errors_include(
        'Exactly one flag out of group ["--flag1", "--flag2", "--flag3"] is required,' \
          " but none were provided.",
        group.validation_errors([])
      )
    end

    it "fails to validate with two flags set" do
      group = Toys::FlagGroup::ExactlyOne.new(nil, nil, nil)
      add_flags(group)
      assert_errors_include(
        'Exactly one flag out of group ["--flag1", "--flag2", "--flag3"] is required,' \
          ' but 2 were provided: ["--flag1", "--flag3"].',
        group.validation_errors([:flag1, :flag3])
      )
    end
  end

  describe "AtMostOne" do
    it "validates with one flag set" do
      group = Toys::FlagGroup::AtMostOne.new(nil, nil, nil)
      add_flags(group)
      assert_empty(group.validation_errors([:flag2]))
    end

    it "validates with no flags set" do
      group = Toys::FlagGroup::AtMostOne.new(nil, nil, nil)
      add_flags(group)
      assert_empty(group.validation_errors([]))
    end

    it "fails to validate with two flags set" do
      group = Toys::FlagGroup::AtMostOne.new(nil, nil, nil)
      add_flags(group)
      assert_errors_include(
        'At most one flag out of group ["--flag1", "--flag2", "--flag3"] is required,' \
          ' but 2 were provided: ["--flag1", "--flag3"].',
        group.validation_errors([:flag1, :flag3])
      )
    end
  end

  describe "AtLeastOne" do
    it "validates with one flag set" do
      group = Toys::FlagGroup::AtLeastOne.new(nil, nil, nil)
      add_flags(group)
      assert_empty(group.validation_errors([:flag2]))
    end

    it "fails to validate with no flags set" do
      group = Toys::FlagGroup::AtLeastOne.new(nil, nil, nil)
      add_flags(group)
      assert_errors_include(
        'At least one flag out of group ["--flag1", "--flag2", "--flag3"] is required,' \
          " but none were provided.",
        group.validation_errors([])
      )
    end

    it "validates with two flags set" do
      group = Toys::FlagGroup::AtLeastOne.new(nil, nil, nil)
      add_flags(group)
      assert_empty(group.validation_errors([:flag1, :flag3]))
    end
  end
end
