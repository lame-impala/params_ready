require_relative '../test_helper'
require_relative '../../lib/params_ready/pagination/tendency'

module ParamsReady
  module Pagination
    class TendencyTest < Minitest::Test
      def test_growing_tendency_uses_gt_predicate
        at = User.arel_table
        attr = at[:ranking]
        g = Tendency::Growing
        p = g.comparison_predicate(attr, 5)
        exp = 'users.ranking > 5'
        assert_equal exp, p.to_sql.unquote
      end

      def test_growing_produces_correct_predicate_for_non_nullable_column
        at = User.arel_table
        attr = at[:ranking]
        nested = Arel::Nodes::Grouping.new(at[:id].gt(2))
        g = Tendency::Growing
        p = g.non_nullable_predicate(attr, 5, nested)
        exp = '((users.ranking = 5 AND (users.id > 2)) OR users.ranking > 5)'
        assert_equal exp, p.to_sql.unquote
      end

      def test_falling_tendency_uses_lt_predicate
        at = User.arel_table
        attr = at[:ranking]
        g = Tendency::Falling
        p = g.comparison_predicate(attr, 5)
        exp = 'users.ranking < 5'
        assert_equal exp, p.to_sql.unquote
      end

      def test_falling_produces_correct_predicate_for_non_nullable_column
        at = User.arel_table
        attr = at[:ranking]
        nested = Arel::Nodes::Grouping.new(at[:id].gt(2))
        g = Tendency::Falling
        p = g.non_nullable_predicate(attr, 5, nested)
        exp = '((users.ranking = 5 AND (users.id > 2)) OR users.ranking < 5)'
        assert_equal exp, p.to_sql.unquote
      end
    end
  end
end
