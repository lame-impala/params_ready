require_relative '../test_helper'
require_relative '../../lib/params_ready/pagination/keyset_pagination'
require_relative '../../lib/params_ready/ordering/ordering'

module ParamsReady
  module Pagination
    class KeysetPaginationTest < Minitest::Test
      def ordering_builder
        Ordering::OrderingParameterBuilder.instance
      end

      def test_builder_raises_if_no_cursor_defined
        d = KeysetPaginationDefinition.new(100, 500)
        err = assert_raises(ParamsReadyError) do
          d.finish
        end

        assert_equal 'No cursor defined', err.message
      end

      def test_accessors_work_with_undefined_single_column_cursor
        d = KeysetPaginationBuilder.new(ordering_builder, 100, 500).build do
          key :integer, :id, :asc
        end

        _, p = d.from_input nil
        assert_equal 100, p.limit
        assert_equal :aft, p.direction
        assert_equal [nil], p.cursor
      end

      def test_accessors_work_with_definite_single_column_cursor
        d = KeysetPaginationBuilder.new(ordering_builder, 100, 500).build do
          key :integer, :id, :asc
        end

        _, p = d.from_input({ dir: :aft, lmt: 200, ks: { id: 250 }})
        assert_equal 200, p.limit
        assert_equal :aft, p[:direction].unwrap
        assert_equal 250, p[:keyset][:id].unwrap
        assert_equal [250], p.cursor
      end

      def test_accessors_work_with_undefined_multiple_column_cursor
        d = KeysetPaginationBuilder.new(ordering_builder, 100, 500).build do
          key :integer, :id, :asc
          key :integer, :created_at, :asc
        end

        _, p = d.from_input nil
        assert_equal 100, p.limit
        assert_equal :aft, p.direction
        assert_equal [nil, nil], p.cursor
      end

      def test_accessors_work_with_definite_multiple_column_cursor
        d = KeysetPaginationBuilder.new(ordering_builder, 100, 500).build do
          key :integer, :id, :asc
          key :integer, :created_at, :asc
        end

        _, p = d.from_input({ dir: :aft, lmt: 200, ks: { id: 250, created_at: 8466996 }})
        assert_equal 200, p.limit
        assert_equal :aft, p.direction
        assert_equal 250, p[:keyset][:id].unwrap
        assert_equal 8466996, p[:keyset][:created_at].unwrap
        assert_equal [250, 8466996], p.cursor
        assert_equal [:id, :created_at], p.cursor_columns
      end

      def ordering_definition
        Ordering::OrderingParameterBuilder.instance.include do
          column :company_id, :asc, required: true, pk: true
          column :part_id, :asc, required: true, pk: true
          column :name, :asc
          column :ranking, :desc
          default [:name, :asc], [:ranking, :desc]
        end.build
      end

      def test_correct_cursor_predicates_for_ascending_columns
        ord_def = ordering_definition
        _, ord = ord_def.from_input nil
        at = User.arel_table

        ks = { company_id: 5, part_id: 605 }
        ctx = Restriction.blanket_permission
        _cur, cp = Direction::After.cursor_predicates(ks, ord, at, ctx)
        exp = <<~SQL
            ((users.name = (SELECT name FROM name_ranking_cte) AND 
                ((users.ranking = (SELECT ranking FROM name_ranking_cte) AND 
                    ((users.company_id = 5 AND users.part_id > 605) OR users.company_id > 5)) 
                OR users.ranking < (SELECT ranking FROM name_ranking_cte))) 
            OR users.name > (SELECT name FROM name_ranking_cte))
        SQL
        assert_equal exp.unformat, cp.to_sql.unquote

        _cur, cp = Direction::Before.cursor_predicates(ks, ord, at, ctx)
        exp = <<~SQL
            ((users.name = (SELECT name FROM name_ranking_cte) AND 
                ((users.ranking = (SELECT ranking FROM name_ranking_cte) AND 
                    ((users.company_id = 5 AND users.part_id < 605) OR users.company_id < 5)) 
                OR users.ranking > (SELECT ranking FROM name_ranking_cte))) 
            OR users.name < (SELECT name FROM name_ranking_cte))
        SQL
        assert_equal exp.unformat, cp.to_sql.unquote
      end

      def test_correct_cursor_predicates_for_descending_columns
        ord_def = ordering_definition
        _, ord = ord_def.from_input 'company_id-desc|part_id-desc'
        at = User.arel_table

        ks = { company_id: 5, part_id: 605 }
        ctx = Restriction.blanket_permission
        _cur, cp = Direction::After.cursor_predicates(ks, ord, at, ctx)
        exp = '((users.company_id = 5 AND users.part_id < 605) OR users.company_id < 5)'
        assert_equal exp, cp.to_sql.unquote

        _cur, cp = Direction::Before.cursor_predicates(ks, ord, at, ctx)
        exp = '((users.company_id = 5 AND users.part_id > 605) OR users.company_id > 5)'
        assert_equal exp, cp.to_sql.unquote
      end

      def test_keyset_query_works_with_aft_direction
        d = KeysetPaginationBuilder.new(ordering_builder, 100, 500).build do
          key :integer, :company_id, :asc
          key :integer, :part_id, :asc
        end
        inp = { dir: :aft, lmt: 100, ks: { company_id: 30, part_id: 50 }}
        _, cp = d.from_input inp
        at = User.arel_table
        q = at.where(at[:name].matches('John').or(at[:ranking].gteq(10)))
        _, ord = ordering_definition.from_input('company_id-desc|part_id-asc|name-desc|ranking-asc')
        ctx = Restriction.blanket_permission

        cq = cp.select_keysets(q, 100, :aft, { company_id: 30, part_id: 50 }, ord, at, ctx)
        exp = <<~SQL
          WITH name_ranking_cte (name, ranking) 
          AS ((SELECT users.name, users.ranking FROM users 
              WHERE (users.name LIKE 'John' OR users.ranking >= 10) 
              AND users.company_id = 30 AND users.part_id = 50)) 
          SELECT users.company_id, users.part_id 
          FROM users 
          WHERE (users.name LIKE 'John' OR users.ranking >= 10) 
          AND ((users.company_id = 30 AND users.part_id > 50) OR users.company_id < 30) 
          ORDER BY users.company_id DESC, users.part_id ASC, users.name DESC, users.ranking ASC LIMIT 100
        SQL
        assert_equal exp.unformat, cq.to_sql.unquote
      end

      def test_keyset_query_works_with_aft_direction_if_query_empty
        d = KeysetPaginationBuilder.new(ordering_builder, 100, 500).build do
          key :integer, :company_id, :asc
          key :integer, :part_id, :asc
        end
        inp = { dir: :aft, lmt: 100, ks: { company_id: 30, part_id: 50 }}
        _, cp = d.from_input inp
        at = User.arel_table
        _, ord = ordering_definition.from_input('company_id-desc|part_id-asc|name-desc|ranking-asc')
        ctx = Restriction.blanket_permission

        cq = cp.select_keysets(at, 100, :aft, { company_id: 30, part_id: 50 }, ord, at, ctx)
        exp = <<~SQL
          WITH name_ranking_cte (name, ranking) AS 
            ((SELECT users.name, users.ranking FROM users WHERE users.company_id = 30 AND users.part_id = 50)) 
          SELECT users.company_id, users.part_id 
          FROM users 
          WHERE ((users.company_id = 30 AND users.part_id > 50) OR users.company_id < 30) 
          ORDER BY users.company_id DESC, users.part_id ASC, users.name DESC, users.ranking ASC 
          LIMIT 100
        SQL
        assert_equal exp.unformat, cq.to_sql.unquote
      end

      def test_keyset_query_works_with_bfr_direction
        d = KeysetPaginationBuilder.new(ordering_builder, 100, 500).build do
          key :integer, :company_id, :asc
          key :integer, :part_id, :asc
        end
        inp = { dir: :aft, lmt: 100, ks: { company_id: 30, part_id: 50 }}
        _, cp = d.from_input inp
        at = User.arel_table
        q = at.where(at[:name].matches('John').and(at[:ranking].gteq(10)))
        _, ord = ordering_definition.from_input('company_id-desc|part_id-asc|name-desc|ranking-asc')
        ctx = Restriction.blanket_permission

        cq = cp.select_keysets(q, 100, :bfr, { company_id: 30, part_id: 50 }, ord, at, ctx)
        exp = <<~SQL
          WITH name_ranking_cte (name, ranking) 
          AS ((SELECT users.name, users.ranking FROM users 
               WHERE users.name LIKE 'John' AND users.ranking >= 10 AND users.company_id = 30 AND users.part_id = 50)) 
          SELECT users.company_id, users.part_id 
          FROM users 
          WHERE users.name LIKE 'John' AND users.ranking >= 10 
          AND ((users.company_id = 30 AND users.part_id < 50) OR users.company_id > 30) 
          ORDER BY users.company_id ASC, users.part_id DESC, users.name ASC, users.ranking DESC LIMIT 100
        SQL
        assert_equal exp.unformat, cq.to_sql.unquote
      end

      def test_keyset_query_works_with_bfr_direction_if_query_empty
        d = KeysetPaginationBuilder.new(ordering_builder, 100, 500).build do
          key :integer, :company_id, :asc
          key :integer, :part_id, :asc
        end
        inp = { dir: :aft, lmt: 100, ks: { company_id: 30, part_id: 50 }}
        _, cp = d.from_input inp
        at = User.arel_table
        _, ord = ordering_definition.from_input('company_id-desc|part_id-asc|name-desc|ranking-asc')
        ctx = Restriction.blanket_permission

        cq = cp.select_keysets(at, 100, :bfr, { company_id: 30, part_id: 50 }, ord, at, ctx)

        exp = <<~SQL
          WITH name_ranking_cte (name, ranking) 
          AS ((SELECT users.name, users.ranking FROM users WHERE users.company_id = 30 AND users.part_id = 50)) 
          SELECT users.company_id, users.part_id 
          FROM users 
          WHERE ((users.company_id = 30 AND users.part_id < 50) OR users.company_id > 30) 
          ORDER BY users.company_id ASC, users.part_id DESC, users.name ASC, users.ranking DESC 
          LIMIT 100
        SQL
        assert_equal exp.unformat, cq.to_sql.unquote
      end

      def test_table_alias_is_composed_of_arel_table_name_and_cursor_columns
        d = KeysetPaginationBuilder.new(ordering_builder, 100, 500).build do
          key :integer, :company_id, :asc
          key :integer, :part_id, :asc
        end
        inp = { dir: :aft, lmt: 100, ks: { company_id: 30, part_id: 50 }}
        _, cp = d.from_input inp

        at = User.arel_table
        ta = cp.table_alias(at)
        assert_equal 'users_company_id_part_id', ta
      end

      def test_paginate_relation_works_with_empty_keyset
        d = KeysetPaginationBuilder.new(ordering_builder, 100, 500).build do
          key :integer, :company_id, :asc
          key :integer, :part_id, :asc
        end
        inp = { dir: :aft, lmt: 100, ks: {}}
        _, cp = d.from_input inp
        at = User.arel_table
        _, ord = ordering_definition.from_input('company_id-desc|part_id-asc|name-desc|ranking-asc')
        ctx = Restriction.blanket_permission

        q = at.where(at[:name].matches('John').and(at[:ranking].gteq(10)))
        bcq = cp.paginate_query(q, ord, at, ctx)
        bcq = bcq.project(Arel.star)

        exp = <<~SQL
          SELECT * FROM users 
          WHERE users.name LIKE 'John' 
          AND users.ranking >= 10 AND EXISTS 
            (SELECT 1 FROM 
              (SELECT users.company_id, users.part_id 
              FROM users 
              WHERE users.name LIKE 'John' 
              AND users.ranking >= 10 
              ORDER BY users.company_id DESC, users.part_id ASC, users.name DESC, users.ranking ASC 
              LIMIT 100) users_company_id_part_id 
          WHERE users.company_id = users_company_id_part_id.company_id 
          AND users.part_id = users_company_id_part_id.part_id)
        SQL
        assert_equal exp.unformat, bcq.to_sql.unquote

      end

      def test_before_keyset_query_works
        d = KeysetPaginationBuilder.new(ordering_builder, 100, 500).build do
          key :integer, :company_id, :asc
          key :integer, :part_id, :asc
        end
        inp = { dir: :bfr, lmt: 100, ks: { company_id: 30, part_id: 50 }}
        _, cp = d.from_input inp
        at = User.arel_table
        _, ord = ordering_definition.from_input('company_id-desc|part_id-asc|name-desc|ranking-asc')
        ctx = Restriction.blanket_permission

        q = at.where(at[:name].matches('John').and(at[:ranking].gteq(10)))
        bcq = cp.paginate_query(q, ord, at, ctx)
        bcq = bcq.project(Arel.star)

        exp = <<~SQL
          SELECT * FROM users 
          WHERE users.name LIKE 'John' 
          AND users.ranking >= 10 AND EXISTS 
            (SELECT 1 FROM 
              (WITH name_ranking_cte (name, ranking) AS 
                ((SELECT users.name, users.ranking 
                FROM users 
                WHERE users.name LIKE 'John' 
                AND users.ranking >= 10 
                AND users.company_id = 30 
                AND users.part_id = 50)) 
            SELECT users.company_id, users.part_id 
            FROM users 
            WHERE users.name LIKE 'John' 
            AND users.ranking >= 10 
            AND ((users.company_id = 30 AND users.part_id < 50) OR users.company_id > 30) 
            ORDER BY users.company_id ASC, users.part_id DESC, users.name ASC, users.ranking DESC 
            LIMIT 100) users_company_id_part_id 
          WHERE users.company_id = users_company_id_part_id.company_id 
          AND users.part_id = users_company_id_part_id.part_id)
        SQL
        assert_equal exp.unformat, bcq.to_sql.unquote
      end

      def test_after_keyset_query_works
        d = KeysetPaginationBuilder.new(ordering_builder, 100, 500).build do
          key :integer, :company_id, :asc
          key :integer, :part_id, :asc
          column :string, :name, :asc
        end
        inp = { dir: :aft, lmt: 100, ks: { company_id: 30, part_id: 50, name: 'John Doe' }}
        _, cp = d.from_input inp
        at = User.arel_table
        _, ord = ordering_definition.from_input('name-desc|company_id-desc|part_id-asc|ranking-asc')
        ctx = Restriction.blanket_permission

        q = at.where(at[:name].matches('John').and(at[:ranking].gteq(10)))

        bcq = cp.paginate_query(q, ord, at, ctx)
        sl = [at[:name], at[:part_id], at[:company_id], at[:ranking]]
        bcq = bcq.project(sl)
        exp = <<~SQL
          SELECT users.name, users.part_id, users.company_id, users.ranking 
          FROM users WHERE users.name LIKE 'John' AND users.ranking >= 10 
          AND EXISTS (SELECT 1 
          FROM (WITH ranking_cte (ranking) AS 
            ((SELECT users.ranking FROM users WHERE users.name LIKE 'John' AND users.ranking >= 10 
            AND users.company_id = 30 AND users.part_id = 50)) 
              SELECT users.company_id, users.part_id 
              FROM users 
              WHERE users.name LIKE 'John' AND users.ranking >= 10 
              AND ((users.name = 'John Doe' AND ((users.company_id = 30 AND users.part_id > 50) 
                OR users.company_id < 30)) 
              OR users.name < 'John Doe') 
              ORDER BY users.name DESC, users.company_id DESC, users.part_id ASC, users.ranking ASC 
              LIMIT 100) users_company_id_part_id_name 
          WHERE users.company_id = users_company_id_part_id_name.company_id 
          AND users.part_id = users_company_id_part_id_name.part_id)
        SQL
        assert_equal exp.unformat, bcq.to_sql.unquote
      end
    end
  end
end
