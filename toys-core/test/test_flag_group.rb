# frozen_string_literal: true

require "helper"

describe Toys::FlagGroup do
  def add_flags(group)
    (1..3).map do |i|
      flag = Toys::Flag.create(:"flag#{i}", group: group)
      group << flag
      flag
    end
  end

  def add_same_key_flags(group)
    ["--foo", "--bar"].map do |name|
      flag = Toys::Flag.create(:flag, [name], group: group)
      group << flag
      flag
    end
  end

  describe "create" do
    describe "type resolution" do
      it "defaults to Optional when type is omitted" do
        assert_instance_of(Toys::FlagGroup::Optional, Toys::FlagGroup.create)
      end

      it "creates Optional from :optional" do
        assert_instance_of(Toys::FlagGroup::Optional, Toys::FlagGroup.create(type: :optional))
      end

      it "creates Required from :required" do
        assert_instance_of(Toys::FlagGroup::Required, Toys::FlagGroup.create(type: :required))
      end

      it "creates ExactlyOne from :exactly_one" do
        assert_instance_of(Toys::FlagGroup::ExactlyOne, Toys::FlagGroup.create(type: :exactly_one))
      end

      it "creates AtMostOne from :at_most_one" do
        assert_instance_of(Toys::FlagGroup::AtMostOne, Toys::FlagGroup.create(type: :at_most_one))
      end

      it "creates AtLeastOne from :at_least_one" do
        assert_instance_of(Toys::FlagGroup::AtLeastOne, Toys::FlagGroup.create(type: :at_least_one))
      end

      it "accepts a class directly" do
        assert_instance_of(Toys::FlagGroup::Required,
                           Toys::FlagGroup.create(type: Toys::FlagGroup::Required))
      end

      it "raises on an unknown symbol" do
        assert_raises(Toys::ToolDefinitionError) do
          Toys::FlagGroup.create(type: :unknown_group_type)
        end
      end

      it "raises when given a class that is not a FlagGroup subclass" do
        assert_raises(Toys::ToolDefinitionError) do
          Toys::FlagGroup.create(type: String)
        end
      end
    end

    describe "attributes" do
      it "sets name to nil by default" do
        assert_nil(Toys::FlagGroup.create.name)
      end

      it "sets name from the name: keyword" do
        group = Toys::FlagGroup.create(name: :mygroup)
        assert_equal(:mygroup, group.name)
      end

      it "sets desc to an empty WrappableString by default" do
        group = Toys::FlagGroup.create
        assert_equal(Toys::WrappableString.new, group.desc)
      end

      it "sets desc from the desc: keyword" do
        group = Toys::FlagGroup.create(desc: "my group")
        assert_equal(Toys::WrappableString.new("my group"), group.desc)
      end

      it "sets long_desc to an empty array by default" do
        assert_empty(Toys::FlagGroup.create.long_desc)
      end

      it "sets long_desc from the long_desc: keyword" do
        group = Toys::FlagGroup.create(long_desc: ["line one", "line two"])
        assert_equal(2, group.long_desc.size)
        assert_equal(Toys::WrappableString.new("line one"), group.long_desc[0])
        assert_equal(Toys::WrappableString.new("line two"), group.long_desc[1])
      end
    end
  end

  describe "Base" do
    it "raises NotImplementedError from validation_errors" do
      base = Toys::FlagGroup::Base.new(nil, nil, nil)
      assert_raises(NotImplementedError) { base.validation_errors([]) }
    end

    it "reports empty? correctly" do
      group = Toys::FlagGroup::Optional.new(nil, nil, nil)
      assert(group.empty?)
      add_flags(group)
      refute(group.empty?)
    end

    it "summarizes using desc when present" do
      group = Toys::FlagGroup::Optional.new(nil, "my flags", nil)
      assert_equal('"my flags"', group.summary)
    end

    it "summarizes using flag display names when desc is absent" do
      group = Toys::FlagGroup::Optional.new(nil, nil, nil)
      add_flags(group)
      assert_equal('["--flag1", "--flag2", "--flag3"]', group.summary)
    end
  end

  describe "Required" do
    it "validates with all flags set" do
      group = Toys::FlagGroup::Required.new(nil, nil, nil)
      flags = add_flags(group)
      assert_empty(group.validation_errors([flags[0], flags[1], flags[2]]))
    end

    it "fails to validate with a flag missing" do
      group = Toys::FlagGroup::Required.new(nil, nil, nil)
      flags = add_flags(group)
      assert_includes(group.validation_errors([flags[0], flags[2]]),
                      'Flag "--flag2" is required.')
    end

    it "distinguishes flags that share a context key" do
      group = Toys::FlagGroup::Required.new(nil, nil, nil)
      flags = add_same_key_flags(group)
      assert_empty(group.validation_errors(flags))
      assert_includes(group.validation_errors([flags[0]]),
                      'Flag "--bar" is required.')
    end
  end

  describe "Optional" do
    it "validates with all flags set" do
      group = Toys::FlagGroup::Optional.new(nil, nil, nil)
      flags = add_flags(group)
      assert_empty(group.validation_errors([flags[0], flags[1], flags[2]]))
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
      flags = add_flags(group)
      assert_empty(group.validation_errors([flags[1]]))
    end

    it "fails to validate with no flags set" do
      group = Toys::FlagGroup::ExactlyOne.new(nil, nil, nil)
      add_flags(group)
      assert_includes(
        group.validation_errors([]),
        'Exactly one flag out of group ["--flag1", "--flag2", "--flag3"] is required,' \
          " but none were provided."
      )
    end

    it "fails to validate with two flags set" do
      group = Toys::FlagGroup::ExactlyOne.new(nil, nil, nil)
      flags = add_flags(group)
      assert_includes(
        group.validation_errors([flags[0], flags[2]]),
        'Exactly one flag out of group ["--flag1", "--flag2", "--flag3"] is required,' \
          ' but 2 were provided: ["--flag1", "--flag3"].'
      )
    end

    it "distinguishes flags that share a context key" do
      group = Toys::FlagGroup::ExactlyOne.new(nil, nil, nil)
      flags = add_same_key_flags(group)
      assert_empty(group.validation_errors([flags[0]]))
      assert_includes(
        group.validation_errors(flags),
        'Exactly one flag out of group ["--foo", "--bar"] is required,' \
          ' but 2 were provided: ["--foo", "--bar"].'
      )
    end
  end

  describe "AtMostOne" do
    it "validates with one flag set" do
      group = Toys::FlagGroup::AtMostOne.new(nil, nil, nil)
      flags = add_flags(group)
      assert_empty(group.validation_errors([flags[1]]))
    end

    it "validates with no flags set" do
      group = Toys::FlagGroup::AtMostOne.new(nil, nil, nil)
      add_flags(group)
      assert_empty(group.validation_errors([]))
    end

    it "fails to validate with two flags set" do
      group = Toys::FlagGroup::AtMostOne.new(nil, nil, nil)
      flags = add_flags(group)
      assert_includes(
        group.validation_errors([flags[0], flags[2]]),
        'At most one flag out of group ["--flag1", "--flag2", "--flag3"] is required,' \
          ' but 2 were provided: ["--flag1", "--flag3"].'
      )
    end

    it "distinguishes flags that share a context key" do
      group = Toys::FlagGroup::AtMostOne.new(nil, nil, nil)
      flags = add_same_key_flags(group)
      assert_empty(group.validation_errors([flags[0]]))
      assert_includes(
        group.validation_errors(flags),
        'At most one flag out of group ["--foo", "--bar"] is required,' \
          ' but 2 were provided: ["--foo", "--bar"].'
      )
    end
  end

  describe "AtLeastOne" do
    it "validates with one flag set" do
      group = Toys::FlagGroup::AtLeastOne.new(nil, nil, nil)
      flags = add_flags(group)
      assert_empty(group.validation_errors([flags[1]]))
    end

    it "fails to validate with no flags set" do
      group = Toys::FlagGroup::AtLeastOne.new(nil, nil, nil)
      add_flags(group)
      assert_includes(
        group.validation_errors([]),
        'At least one flag out of group ["--flag1", "--flag2", "--flag3"] is required,' \
          " but none were provided."
      )
    end

    it "validates with two flags set" do
      group = Toys::FlagGroup::AtLeastOne.new(nil, nil, nil)
      flags = add_flags(group)
      assert_empty(group.validation_errors([flags[0], flags[2]]))
    end

    it "distinguishes flags that share a context key" do
      group = Toys::FlagGroup::AtLeastOne.new(nil, nil, nil)
      flags = add_same_key_flags(group)
      assert_empty(group.validation_errors([flags[0]]))
      assert_includes(
        group.validation_errors([]),
        'At least one flag out of group ["--foo", "--bar"] is required,' \
          " but none were provided."
      )
    end
  end
end
