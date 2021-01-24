require_relative '../test_helper'
require_relative '../../lib/params_ready/pagination/cursor'
require_relative '../../lib/params_ready/ordering/ordering'

module ParamsReady
  module Pagination
    class CursorBuilderTest < Minitest::Test
      def build_cursor
        at = User.arel_table
        cb = CursorBuilder.new({ pid: 5, cid: 18 }, at, {})

        col = Ordering::Column.new(
          :asc,
          arel_table: nil,
          expression: nil,
          pk: true
        )

        cb.add :pid, col
        cb.add :cid, col
        col = Ordering::Column.new(
          :asc,
          arel_table: nil,
          expression: nil,
          nulls: :first
        )
        cb.add :ranking, col
        col = Ordering::Column.new(
          :desc,
          arel_table: nil,
          expression: nil,
          nulls: :last
        )
        cb.add :name, col
        cb.build
      end

      def test_cursor_produces_cte_expression
        c = build_cursor

        sel = <<~SQL
          SELECT users.ranking, user.name FROM users 
          WHERE pid = 5 AND cid = 18
        SQL
        sel = sel.unformat

        relation = Minitest::Mock.new
        relation.expect(:select, relation, [Arel::Attributes::Attribute, Arel::Attributes::Attribute])
        relation.expect(:where, relation, [{ pid: 5, cid: 18 }])
        relation.expect(:to_sql, sel)
        cte = c.cte_for_relation(relation)

        exp = <<~SQL
          WITH ranking_name_cte (ranking, name)
          AS (#{sel})
        SQL
        assert_equal exp.unformat, cte.to_sql.unquote
      end

      def test_cursor_produces_rvalues
        c = build_cursor
        assert_equal 5, c.rvalue(:pid).value
        assert_equal 18, c.rvalue(:cid).value
        assert_equal 'SELECT ranking FROM ranking_name_cte', c.rvalue(:ranking).to_sql.unquote
        assert_equal 'SELECT name FROM ranking_name_cte', c.rvalue(:name).to_sql.unquote
      end
    end
  end
end
