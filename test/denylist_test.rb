require_relative 'test_helper'
require_relative '../lib/params_ready/restriction'

module ParamsReady
  class Restriction
    class DenylistTest < Minitest::Test
      def test_default_denylist_permits_all
        dl = Denylist.new
        assert dl.name_permitted? :foo
      end

      def test_nothing_denylist_permits_all
        dl = Denylist.instance Denylist::Nothing
        assert dl.name_permitted? :foo
        assert dl.name_permitted? :bar
      end

      def test_regex_denylist_prohibits_what_matches_the_regex
        dl = Denylist.instance /bar/
        assert dl.name_permitted? :foo
        refute dl.name_permitted? :bar
      end

      def test_array_denylist_prohibits_what_is_included_in_array
        dl = Denylist.instance :bar, :bax
        assert dl.name_permitted? :foo
        refute dl.name_permitted? :bar
      end

      def test_nested_denylist_permits_parent_with_nesting
        dl = Denylist.instance :foo, bar: [:a, :b]
        assert dl.name_permitted? :bar
      end

      def test_nested_denylist_prohibits_parent_without_nesting
        dl = Denylist.instance :foo, bar: [:a, :b]
        assert dl.name_permitted? :bar
      end

      def test_denylist_returns_default_at_for_children_request_for_non_listed_parent
        dl = Denylist.instance :foo, bar: [:a, :b]
        param = DummyParam.new(:baz)

        fc = dl.for_children param
        assert_equal Restriction::Allowlist, fc.class
        assert_equal Restriction::Everything, fc.restriction
      end

      def test_nested_denylist_raises_if_list_for_children_request_for_non_nesting_parent
        dl = Denylist.instance :foo, bar: [:a, :b]
        param = DummyParam.new(:foo)
        err = assert_raises do
          dl.for_children param
        end

        assert_equal "Parameter 'foo' not permitted", err.message
      end

      def test_nested_denylist_returns_children_restrictions_at_request_for_nesting_parent
        dl = Denylist.instance :foo, bar: [:a, b: [:ba, :bb]]
        param = DummyParam.new(:bar)
        fc = dl.for_children param

        assert_equal({ a: Restriction::Everything, b: [:ba, :bb] }, fc.restriction)
        refute fc.permitted? DummyParam.new(:a)
        assert fc.permitted? DummyParam.new(:b)
        assert fc.permitted? DummyParam.new(:c)

        fc = fc.for_children  DummyParam.new(:b)
        refute fc.permitted? DummyParam.new(:ba)
        refute fc.permitted? DummyParam.new(:bb)
        assert fc.permitted? DummyParam.new(:bc)
      end
    end
  end
end