require_relative '../test_helper'
require_relative '../../lib/params_ready/pagination/direction'
require_relative '../../lib/params_ready/pagination/cursor'
require_relative '../../lib/params_ready/restriction'
require_relative '../../lib/params_ready/ordering/ordering'

module ParamsReady
  module Pagination
    class DirectionTest
      def self.build_cursor
        at = User.arel_table
        cb = CursorBuilder.new({ id: 11, cid: 932 }, at, {})
        id_col = Ordering::Column.new(
          :asc, arel_table: nil, expression: nil
        )
        cb.add :id, id_col

        cid_col = Ordering::Column.new(
          :asc, arel_table: nil, expression: nil
        )
        cb.add :cid, cid_col

        ranking_col = Ordering::Column.new(
          :asc, arel_table: nil, expression: nil, nulls: :last
        )
        cb.add :ranking, ranking_col
        cb.build
      end

      class CommonTests < Minitest::Test
        def get_ordering_definition
          definition = Ordering::OrderingParameterDefinition.new({})
          # pk
          definition.add_column :id, :asc, expression: nil, arel_table: nil, required: true, pk: true
          # in keyset
          expr = '(SELECT COUNT(id) FROM posts WHERE users_id = users.id)'
          definition.add_column :num_posts, :asc, expression: expr, arel_table: :none
          # non nullable
          definition.add_column :name, :asc, expression: nil, arel_table: nil
          # nullable
          definition.add_column :ranking, :desc, expression: nil, arel_table: nil, nulls: :last
          definition.finish
        end

        def test_produces_cursor_for_keyset_and_ordering
          definition = get_ordering_definition
          _, ordering = definition.from_input([[:id, :asc], [:num_posts, :desc], [:ranking, :desc]])
          keyset = { id: 115, num_posts: 10 }
          arel_table = User.arel_table
          context = Restriction.blanket_permission

          after = Direction::After
          cursor = after.build_cursor(keyset, ordering, arel_table, context)
          assert_equal 2, cursor.literals.length
          assert_equal 1, cursor.selectors.length
          assert_equal 115, cursor.rvalue(:id).value
          assert_equal 10, cursor.rvalue(:num_posts).value
          exp = 'SELECT ranking FROM ranking_cte'
          assert_equal exp, cursor.rvalue(:ranking).to_sql.unquote
        end

        def test_produces_keyset_predicates
          definition = get_ordering_definition
          _, ordering = definition.from_input([[:num_posts, :desc], [:ranking, :desc], [:id, :asc]])
          keyset = { id: 115, num_posts: 10 }
          arel_table = User.arel_table
          context = Restriction.blanket_permission
          after = Direction::After
          cursor, predicates = after.cursor_predicates(keyset, ordering, arel_table, context)
          exp = <<~SQL
            (((SELECT COUNT(id) FROM posts WHERE users_id = users.id) = 10 
            AND CASE WHEN ((SELECT ranking FROM ranking_cte)) IS NULL THEN 
              (users.ranking IS NULL AND users.id > 115) 
            ELSE (((users.ranking = (SELECT ranking FROM ranking_cte) AND users.id > 115) 
               OR users.ranking < (SELECT ranking FROM ranking_cte)) 
               OR users.ranking IS NULL) 
            END) OR (SELECT COUNT(id) FROM posts WHERE users_id = users.id) < 10)
          SQL
          assert_equal exp.unformat, predicates.to_sql.unquote
        end
      end

      class BeforeTest < Minitest::Test
        def test_inverts_ordering
          assert Direction::Before.invert_ordering?
        end

        def test_produces_correct_pk_predicate_with_asc_ordering
          ordering = :asc
          column = User.arel_table[:id]
          exp = 'users.id < 11'
          before = Direction::Before
          arel = before.pk_predicate(ordering, column, 11)
          assert_equal exp, arel.to_sql.unquote
        end

        def test_produces_correct_pk_predicate_with_desc_ordering
          ordering = :desc
          column = User.arel_table[:id]
          exp = 'users.id > 11'
          before = Direction::Before
          arel = before.pk_predicate(ordering, column, 11)
          assert_equal exp, arel.to_sql.unquote
        end

        def test_produces_correct_non_nullable_predicate_with_asc_ordering
          ordering = :asc
          column = User.arel_table[:ranking]
          exp = '((users.ranking = 5 AND users.id > 11) OR users.ranking < 5)'
          before = Direction::Before
          nested = Arel::Nodes::SqlLiteral.new('users.id > 11')
          arel = before.non_nullable_predicate(ordering, column, 5, nested)
          assert_equal exp, arel.to_sql.unquote
        end

        def test_produces_correct_non_nullable_predicate_with_desc_ordering
          ordering = :desc
          column = User.arel_table[:ranking]
          expr = '(SELECT ranking FROM ranking_cte)'
          exp = "((users.ranking = #{expr} AND users.id > 11) OR users.ranking > #{expr})"
          before = Direction::Before
          nested = Arel::Nodes::SqlLiteral.new('users.id > 11')
          cur = DirectionTest.build_cursor
          value = cur.rvalue(:ranking)
          arel = before.non_nullable_predicate(ordering, column, value, nested)
          assert_equal exp, arel.to_sql.unquote
        end

        def test_produces_correct_nullable_predicate_with_nulls_first_strategy
          ordering = :asc
          column = User.arel_table[:ranking]
          value = 5
          nested = Arel::Nodes::SqlLiteral.new('users.id > 11')
          exp = <<~SQL
            CASE WHEN (#{value}) IS NULL THEN
              (users.ranking IS NULL AND #{nested})
            ELSE
              (((users.ranking = #{value} AND #{nested}) OR users.ranking < #{value}) OR users.ranking IS NULL)
            END
          SQL
          before = Direction::Before
          arel = before.nullable_predicate(ordering, :first, column, value, nested)
          assert_equal exp.unformat, arel.to_sql.unquote
        end

        def test_produces_correct_nullable_predicate_with_nulls_last_strategy
          ordering = :desc
          column = User.arel_table[:ranking]
          expr = '(SELECT ranking FROM ranking_cte)'
          nested = Arel::Nodes::SqlLiteral.new('users.id > 11')
          exp = <<~SQL
            CASE WHEN (#{expr}) IS NULL THEN
              ((users.ranking IS NULL AND #{nested}) OR users.ranking IS NOT NULL)
            ELSE
              ((users.ranking = #{expr} AND #{nested}) OR users.ranking > #{expr})
            END
          SQL
          before = Direction::Before
          cur = DirectionTest.build_cursor
          value = cur.rvalue(:ranking)
          arel = before.nullable_predicate(ordering, :last, column, value, nested)
          assert_equal exp.unformat, arel.to_sql.unquote
        end
      end

      class AfterTest < Minitest::Test
        def test_inverts_ordering_not
          refute Direction::After.invert_ordering?
        end

        def test_produces_correct_pk_predicate_with_asc_ordering
          ordering = :asc
          column = User.arel_table[:id]
          exp = 'users.id > 11'
          after = Direction::After
          arel = after.pk_predicate(ordering, column, 11)
          assert_equal exp, arel.to_sql.unquote
        end

        def test_produces_correct_pk_predicate_with_desc_ordering
          ordering = :desc
          column = User.arel_table[:id]
          exp = 'users.id < 11'
          after = Direction::After
          arel = after.pk_predicate(ordering, column, 11)
          assert_equal exp, arel.to_sql.unquote
        end

        def test_produces_correct_non_nullable_predicate_with_asc_ordering
          ordering = :asc
          column = User.arel_table[:ranking]
          exp = '((users.ranking = 5 AND users.id > 11) OR users.ranking > 5)'
          after = Direction::After
          nested = Arel::Nodes::SqlLiteral.new('users.id > 11')
          arel = after.non_nullable_predicate(ordering, column, 5, nested)
          assert_equal exp, arel.to_sql.unquote
        end

        def test_produces_correct_non_nullable_predicate_with_desc_ordering
          ordering = :desc
          column = User.arel_table[:ranking]
          expr = '(SELECT ranking FROM ranking_cte)'
          exp = "((users.ranking = #{expr} AND users.id > 11) OR users.ranking < #{expr})"
          after = Direction::After
          nested = Arel::Nodes::SqlLiteral.new('users.id > 11')
          cur = DirectionTest.build_cursor
          value = cur.rvalue(:ranking)
          arel = after.non_nullable_predicate(ordering, column, value, nested)
          assert_equal exp, arel.to_sql.unquote
        end

        def test_produces_correct_nullable_predicate_with_nulls_last_strategy
          ordering = :asc
          column = User.arel_table[:ranking]
          value = 5
          nested = Arel::Nodes::SqlLiteral.new('users.id > 11')
          exp = <<~SQL
            CASE WHEN (#{value}) IS NULL THEN
              (users.ranking IS NULL AND #{nested})
            ELSE
              (((users.ranking = #{value} AND #{nested}) OR users.ranking > #{value}) OR users.ranking IS NULL)
            END
          SQL
          after = Direction::After
          arel = after.nullable_predicate(ordering, :last, column, value, nested)
          assert_equal exp.unformat, arel.to_sql.unquote
        end

        def test_produces_correct_nullable_predicate_with_nulls_first_strategy
          ordering = :desc
          column = User.arel_table[:ranking]
          expr = '(SELECT ranking FROM ranking_cte)'
          nested = Arel::Nodes::SqlLiteral.new('users.id > 11')
          exp = <<~SQL
            CASE WHEN (#{expr}) IS NULL THEN
              ((users.ranking IS NULL AND #{nested}) OR users.ranking IS NOT NULL)
            ELSE
              ((users.ranking = #{expr} AND #{nested}) OR users.ranking < #{expr})
            END
          SQL
          after = Direction::After
          cur = DirectionTest.build_cursor
          value = cur.rvalue(:ranking)
          arel = after.nullable_predicate(ordering, :first, column, value, nested)
          assert_equal exp.unformat, arel.to_sql.unquote
        end
      end
    end
  end
end
