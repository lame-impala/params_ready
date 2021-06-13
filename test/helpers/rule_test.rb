require_relative '../../lib/params_ready/helpers/rule'
require_relative '../test_helper'

module ParamsReady
  module Helpers
    class RuleTest < Minitest::Test
      def test_all_rule_includes_all
        r = Helpers::Rule(:all)
        assert r.include? :foo
      end

      def test_all_rule_merges_with_all_rule
        r1 = Helpers::Rule(:all)
        r2 = Helpers::Rule(:all)
        r = r1.merge(r2)
        assert_equal :all, r.mode
      end

      def test_rule_merged_with_nil_returns_self
        r = Helpers::Rule(:all).merge nil
        assert_equal :all, r.mode
      end

      def test_none_rule_includes_nothing
        r = Helpers::Rule(:none)
        refute r.include? :foo
      end

      def test_none_rule_merges_with_none_rule
        r1 = Helpers::Rule(:none)
        r2 = Helpers::Rule(:none)
        r = r1.merge(r2)
        assert_equal :none, r.mode
      end

      def test_only_rule_includes_listed
        r = Helpers::Rule(only: [:foo])
        assert r.include? :foo
        refute r.include? :bar
      end

      def test_only_rule_merges_with_only_rule
        r1 = Helpers::Rule(only: [:foo])
        r2 = Helpers::Rule(only: [:bar])
        r = r1.merge(r2)
        assert r.include? :foo
        assert r.include? :bar
      end

      def test_except_rule_excludes_listed
        r = Helpers::Rule(except: [:bar])
        assert r.include? :foo
        refute r.include? :bar
      end

      def test_except_rule_merges_with_except_rule
        r1 = Helpers::Rule(except: [:foo])
        r2 = Helpers::Rule(except: [:bar])
        r = r1.merge(r2)
        refute r.include? :foo
        refute r.include? :bar
      end
    end
  end
end