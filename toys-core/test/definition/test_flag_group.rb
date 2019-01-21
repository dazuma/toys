# frozen_string_literal: true

# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

require "helper"

describe Toys::Definition::FlagGroup do
  def add_flags(group)
    flag = Toys::Definition::Flag.new(:flag1, [], [], true, nil, nil, nil, nil, group)
    group << flag
    flag = Toys::Definition::Flag.new(:flag2, [], [], true, nil, nil, nil, nil, group)
    group << flag
    flag = Toys::Definition::Flag.new(:flag3, [], [], true, nil, nil, nil, nil, group)
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
