# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

require "helper"

describe Toys::Definition::FlagGroup do
  def add_flags(group)
    flag = Toys::Definition::Flag.new(:flag1, [], [], true, nil, nil, nil, nil, nil, group)
    group << flag
    flag = Toys::Definition::Flag.new(:flag2, [], [], true, nil, nil, nil, nil, nil, group)
    group << flag
    flag = Toys::Definition::Flag.new(:flag3, [], [], true, nil, nil, nil, nil, nil, group)
    group << flag
  end

  describe "Required" do
    it "sets the default descriptions" do
      group = Toys::Definition::FlagGroup::Required.new(nil, nil, nil)
      assert_equal("Required Flags", group.desc.to_s)
      assert_equal("These flags are required.", group.long_desc.first.to_s)
    end

    it "validates with all flags set" do
      group = Toys::Definition::FlagGroup::Required.new(nil, nil, nil)
      add_flags(group)
      assert_nil(group.validation_error([:flag1, :flag2, :flag3]))
    end

    it "fails to validate with a flag missing" do
      group = Toys::Definition::FlagGroup::Required.new(nil, nil, nil)
      add_flags(group)
      assert_equal('Flag "--flag2" is required', group.validation_error([:flag1, :flag3]))
    end
  end

  describe "Optional" do
    it "sets the default descriptions" do
      group = Toys::Definition::FlagGroup::Optional.new(nil, nil, nil)
      assert_equal("Flags", group.desc.to_s)
      assert(group.long_desc.empty?)
    end

    it "validates with all flags set" do
      group = Toys::Definition::FlagGroup::Optional.new(nil, nil, nil)
      add_flags(group)
      assert_nil(group.validation_error([:flag1, :flag2, :flag3]))
    end

    it "Validates with no flags set" do
      group = Toys::Definition::FlagGroup::Optional.new(nil, nil, nil)
      add_flags(group)
      assert_nil(group.validation_error([]))
    end
  end

  describe "ExactlyOne" do
    it "sets the default descriptions" do
      group = Toys::Definition::FlagGroup::ExactlyOne.new(nil, nil, nil)
      assert_equal("Flags", group.desc.to_s)
      assert_equal("Exactly one of these flags must be set.", group.long_desc.first.to_s)
    end

    it "validates with one flag set" do
      group = Toys::Definition::FlagGroup::ExactlyOne.new(nil, nil, nil)
      add_flags(group)
      assert_nil(group.validation_error([:flag2]))
    end

    it "fails to validate with no flags set" do
      group = Toys::Definition::FlagGroup::ExactlyOne.new(nil, nil, nil)
      add_flags(group)
      assert_equal('Exactly one out of group "Flags" is required', group.validation_error([]))
    end

    it "fails to validate with two flags set" do
      group = Toys::Definition::FlagGroup::ExactlyOne.new(nil, nil, nil)
      add_flags(group)
      assert_equal('Exactly one out of group "Flags" is required, but both' \
                   ' "--flag1" and "--flag3" were set',
                   group.validation_error([:flag1, :flag3]))
    end
  end

  describe "AtMostOne" do
    it "sets the default descriptions" do
      group = Toys::Definition::FlagGroup::AtMostOne.new(nil, nil, nil)
      assert_equal("Flags", group.desc.to_s)
      assert_equal("At most one of these flags must be set.", group.long_desc.first.to_s)
    end

    it "validates with one flag set" do
      group = Toys::Definition::FlagGroup::AtMostOne.new(nil, nil, nil)
      add_flags(group)
      assert_nil(group.validation_error([:flag2]))
    end

    it "validates with no flags set" do
      group = Toys::Definition::FlagGroup::AtMostOne.new(nil, nil, nil)
      add_flags(group)
      assert_nil(group.validation_error([]))
    end

    it "fails to validate with two flags set" do
      group = Toys::Definition::FlagGroup::AtMostOne.new(nil, nil, nil)
      add_flags(group)
      assert_equal('At most one out of group "Flags" is required, but both' \
                   ' "--flag1" and "--flag3" were set',
                   group.validation_error([:flag1, :flag3]))
    end
  end

  describe "AtLeastOne" do
    it "sets the default descriptions" do
      group = Toys::Definition::FlagGroup::AtLeastOne.new(nil, nil, nil)
      assert_equal("Flags", group.desc.to_s)
      assert_equal("At least one of these flags must be set.", group.long_desc.first.to_s)
    end

    it "validates with one flag set" do
      group = Toys::Definition::FlagGroup::AtLeastOne.new(nil, nil, nil)
      add_flags(group)
      assert_nil(group.validation_error([:flag2]))
    end

    it "fails to validate with no flags set" do
      group = Toys::Definition::FlagGroup::AtLeastOne.new(nil, nil, nil)
      add_flags(group)
      assert_equal('At least one out of group "Flags" is required', group.validation_error([]))
    end

    it "validates with two flags set" do
      group = Toys::Definition::FlagGroup::AtLeastOne.new(nil, nil, nil)
      add_flags(group)
      assert_nil(group.validation_error([:flag1, :flag3]))
    end
  end
end
