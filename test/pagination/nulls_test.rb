require_relative '../test_helper'
require_relative '../../lib/params_ready/pagination/nulls'
require_relative '../../lib/params_ready/pagination/tendency'

module ParamsReady
  module Pagination
    class NullsTest < Minitest::Test
      def test_nulls_first_strategy_creates_correct_sql_if_value_null
        at = User.arel_table
        column = at[:ranking]
        nested = Arel::Nodes::Grouping.new(at[:id].gt(5))
        strategy = Nulls::First
        exp = '((users.ranking IS NULL AND (users.id > 5)) OR users.ranking IS NOT NULL)'
        arel = strategy.if_null_predicate(column, nested)
        assert_equal exp, arel.to_sql.unquote
      end

      def test_nulls_first_strategy_creates_correct_sql_if_value_is_not_null
        at = User.arel_table
        column = at[:ranking]
        nested = Arel::Nodes::Grouping.new(at[:id].gt(5))
        strategy = Nulls::First
        exp = '((users.ranking = 15 AND (users.id > 5)) OR users.ranking < 15)'
        tendency = Tendency::Falling
        arel = strategy.if_not_null_predicate(tendency, column, 15, nested)
        assert_equal exp, arel.to_sql.unquote
      end

      def test_nulls_last_strategy_creates_correct_sql_if_value_null
        at = User.arel_table
        column = at[:ranking]
        nested = Arel::Nodes::Grouping.new(at[:id].gt(5))
        strategy = Nulls::Last
        exp = '(users.ranking IS NULL AND (users.id > 5))'
        arel = strategy.if_null_predicate(column, nested)
        assert_equal exp, arel.to_sql.unquote
      end

      def test_nulls_last_strategy_creates_correct_sql_if_value_is_not_null
        at = User.arel_table
        column = at[:ranking]
        nested = Arel::Nodes::Grouping.new(at[:id].gt(5))
        strategy = Nulls::Last
        exp = '(((users.ranking = 15 AND (users.id > 5)) OR users.ranking < 15) OR users.ranking IS NULL)'
        tendency = Tendency::Falling
        arel = strategy.if_not_null_predicate(tendency, column, 15, nested)
        assert_equal exp, arel.to_sql.unquote
      end
    end
  end
end
