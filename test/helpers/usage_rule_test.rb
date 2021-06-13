require_relative '../../lib/params_ready/helpers/rule'
require_relative '../test_helper'

module ParamsReady
  module Helpers
    class UsageRuleTest < Minitest::Test
      def get_def
        Builder.define_parameter :string, :param
      end

      def test_delegates_name_to_parameter_definition
        ur = UsageRule.new(get_def, only: [:create])
        assert_equal :param, ur.name
      end

      def test_valid_for_to_rule
        ur = UsageRule.new(get_def, only: [:create])
        assert ur.valid_for?(:create)
        refute ur.valid_for?(:update)
      end

      def test_returns_self_when_merged_with_nil
        ur1 = UsageRule.new(get_def, only: [:create])
        ur = ur1.merge(nil)
        assert ur.valid_for?(:create)
        refute ur.valid_for?(:update)
      end

      def test_merges_with_compatible_rule
        d = get_def
        ur1 = UsageRule.new(d, only: [:create])
        ur2 = UsageRule.new(d, only: [:update])
        ur = ur1.merge(ur2)
        assert ur.valid_for?(:create)
        assert ur.valid_for?(:update)
      end

      def test_refuses_to_merge_with_rule_using_different_definition
        ur1 = UsageRule.new(get_def, only: [:create])
        ur2 = UsageRule.new(get_def, only: [:update])

        err = assert_raises(ParamsReadyError) do
          ur1.merge(ur2)
        end
        assert_equal "Can't merge incompatible rules: param/param", err.message
      end

      def test_refuses_to_merge_with_rule_using_different_mode
        d = get_def
        ur1 = UsageRule.new(d, except: [:create])
        ur2 = UsageRule.new(d, only: [:update])

        err = assert_raises(ParamsReadyError) do
          ur1.merge(ur2)
        end
        assert_equal "Can't merge incompatible rules: except/only", err.message
      end
    end
  end
end