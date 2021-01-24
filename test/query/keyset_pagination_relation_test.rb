require_relative '../test_helper'
require_relative '../../lib/params_ready/query/relation'

module ParamsReady
  module Query
    class KeysetPaginationRelationTest < Minitest::Test
      def test_builder_raises_if_ordering_defined_before_cursor
        err = assert_raises(ParamsReadyError) do
          Builder.define_relation(:users) do
            order do
              column :id, :asc
            end
            paginate(100, 500, method: :keyset) do
              key :integer, :id, :asc
            end
          end
        end
        assert_equal 'Ordering already defined', err.message
      end

      def get_def
        Builder.define_relation(:users) do
          operator{ local :and }

          fixed_operator_predicate :email_like do
            type :value, :string
            operator :like
            optional()
          end

          fixed_operator_predicate :name_like do
            type :value, :string
            operator :like
            optional()
          end

          paginate(100, 500, method: :keyset) do
            key :integer, :id, :asc
            key :value, :created_at, :asc do
              coerce do |value, _|
                DateTime.strptime(value.to_s, '%s')
              end

              format do |value, _|
                value.to_i
              end

              type_identifier(:date)
            end
            base64
          end

          order do
            column :email, :asc
            column :name, :asc
            column :hits, :desc
            default [:email, :asc], [:name, :asc]
          end

          optional
        end
      end

      def base64(hash)
        json = hash.to_json
        Base64.urlsafe_encode64(json)
      end

      def input
        created_at = DateTime.new(2020, 2, 6, 20, 40, 00)
        int = created_at.to_i
        {
          email_like: 'a',
          pgn: {
            dir: :aft,
            lmt: 100,
            ks: {
              id: 152,
              created_at: int
            }
          }
        }
      end

      def test_before_page_works
        d = get_def
        _, rel = d.from_input(input)
        bp = rel.before_page({ id: 3, created_at: 55 })
        base64 = self.base64({ dir: 'bfr', lmt: '100', ks: { id: '3', created_at: 55 }})
        exp = { email_like: 'a', pgn: base64 }
        assert_equal(exp, bp.for_frontend)
        assert_equal(exp, rel.before({ id: 3, created_at: 55 }))
      end

      def test_after_page_works
        d = get_def
        _, rel = d.from_input(input)
        bp = rel.after_page({ id: 3, created_at: 55 })
        base64 = self.base64({ dir: 'aft', lmt: '100', ks: { id: '3', created_at: 55 }})
        exp = { email_like: 'a', pgn: base64 }

        assert_equal(exp, bp.for_frontend)
        assert_equal(exp, rel.after({ id: 3, created_at: 55 }))
      end

      def test_limited_at_works
        d = get_def
        _, rel = d.from_input(input)
        c1 = rel.pagination[:keyset][:id].unwrap
        c2 = rel.pagination[:keyset][:created_at].format(Format.instance(:frontend))
        bp = rel.limited_at(32)
        base64 = self.base64({ dir: 'aft', lmt: '32', ks: { id: c1.to_s, created_at: c2 }})
        exp = { email_like: 'a', pgn: base64 }

        assert_equal(exp, bp.for_frontend)
        assert_equal(exp, rel.limit_at(32))
      end

      def test_build_keyset_query_works
        d = get_def
        _, rel = d.from_input(input)
        dttm = DateTime.parse('2020-01-08T20:34:16')
        cq = rel.build_keyset_query(100, :aft, { id: 200, created_at: dttm }, model_class: User)
        exp = <<~SQL
          WITH email_name_cte (email, name) AS 
            ((SELECT users.email, users.name 
            FROM users 
            WHERE (users.email_like LIKE '%a%') 
            AND users.id = 200 AND users.created_at = '2020-01-08 20:34:16')) 
          SELECT users.id, users.created_at 
          FROM users 
          WHERE (users.email_like LIKE '%a%') 
          AND ((users.email = (SELECT email FROM email_name_cte) 
            AND ((users.name = (SELECT name FROM email_name_cte) 
              AND ((users.id = 200 AND users.created_at > '2020-01-08 20:34:16') 
              OR users.id > 200)) 
            OR users.name > (SELECT name FROM email_name_cte))) 
          OR users.email > (SELECT email FROM email_name_cte)) 
          ORDER BY users.email ASC, users.name ASC, users.id ASC, users.created_at ASC 
          LIMIT 100
        SQL
        assert_equal exp.unformat, cq.to_sql.unquote
      end

      def test_keysets_method_works
        d = get_def
        _, rel = d.from_input(input)
        dttm = DateTime.parse('2020-01-08T20:34:16')
        exp = 'WITH email_name_cte (email, name) AS (SELECT stuff FROM stuff) SELECT stuff FROM stuff'
        conn = DummyConnection.new([1, 2, 3, 4, 5])
        ks = rel.keysets(100, :aft, { id: 200, created_at: dttm }, scope: DummyScope.new(User, conn)) do |raw|
          { id: raw }
        end
        assert_equal exp, conn.last_query
        assert ks.is_a? Pagination::AfterKeysets
        assert_equal({ id: 2 }, ks.page(2, 2))
      end

      def test_before_cursor_relation_works
        d = get_def
        _, rel = d.from_input(input)

        cursor = rel[:pagination]
        ordering = rel[:ordering]
        context = Restriction.blanket_permission

        scope = DummyScope.new(Company)

        bcr = cursor.paginate_relation(scope, ordering, context)
        where = bcr.instance_variable_get(:@where)
        assert_equal 3, where.length
        assert_equal({ id: 152, created_at: DateTime.parse('2020-02-06 20:40:00') }, where[1])
        exp = <<~SQL
          ((companies.email = (SELECT email FROM email_name_cte) 
            AND ((companies.name = (SELECT name FROM email_name_cte) 
              AND ((companies.id = 152 AND companies.created_at > '2020-02-06 20:40:00') 
              OR companies.id > 152)) 
            OR companies.name > (SELECT name FROM email_name_cte))) 
          OR companies.email > (SELECT email FROM email_name_cte))
        SQL
        assert_equal exp.unformat, where[0].to_sql.unquote
        exp = <<~SQL
          EXISTS (SELECT 1 FROM 
            (WITH email_name_cte (email, name) AS (SELECT stuff FROM stuff) 
            SELECT stuff FROM stuff) AS companies_id_created_at 
            WHERE companies.id = companies_id_created_at.id AND companies.created_at = companies_id_created_at.created_at)
        SQL
        assert_equal exp.unformat, where[2].to_sql.unquote
      end

      def test_after_cursor_relation_works
        d = get_def
        _, rel = d.from_input(input)

        pagination = rel[:pagination]
        ordering = rel[:ordering]
        context = Restriction.blanket_permission

        scope = DummyScope.new(Company)
        acr = pagination.paginate_relation(scope, ordering, context)

        where = acr.instance_variable_get(:@where)
        assert_equal 3, where.length
        assert_equal({ id: 152, created_at: DateTime.parse('2020-02-06 20:40:00') }, where[1])
        exp = <<~SQL
          ((companies.email = (SELECT email FROM email_name_cte) AND 
             ((companies.name = (SELECT name FROM email_name_cte) AND 
                 ((companies.id = 152 AND companies.created_at > '2020-02-06 20:40:00') OR companies.id > 152)) 
             OR companies.name > (SELECT name FROM email_name_cte))) 
          OR companies.email > (SELECT email FROM email_name_cte))
        SQL
        assert_equal exp.unformat, where[0].to_sql.unquote
        exp = <<~SQL
          EXISTS (SELECT 1 FROM 
            (WITH email_name_cte (email, name) AS (SELECT stuff FROM stuff) 
            SELECT stuff FROM stuff) AS companies_id_created_at 
            WHERE companies.id = companies_id_created_at.id AND companies.created_at = companies_id_created_at.created_at)
        SQL
        assert_equal exp.unformat, where[2].to_sql.unquote
      end

      def test_cursor_defined_correctly
        d = get_def
        created_at = DateTime.new(2020, 2, 6, 20, 40, 00)
        int = created_at.to_i
        inp = {
          email_like: 'a',
          pgn: {
            dir: :aft,
            lmt: 100,
            ks: {
              id: 152,
              created_at: int
            }
          }
        }

        _, p = d.from_input(inp)
        assert_equal 100, p[:pagination].limit
        assert_equal :aft, p[:pagination].direction
        assert_equal [152, created_at], p[:pagination].cursor
      end

      def test_explicit_and_implicit_columns_defined
        d = get_def
        od = d.child_definition(:ordering)
        cols = od.instance_variable_get(:@columns).keys
        assert_equal([:id, :created_at, :email, :name, :hits], cols)
      end

      def test_cursor_columns_marked_as_required
        d = get_def
        od = d.child_definition(:ordering)
        cols = od.instance_variable_get(:@required_columns)
        assert_equal([:id, :created_at], cols)
      end
    end

    class KeysetPaginationIncompleteKeysetTest < Minitest::Test
      def get_def
        Builder.define_relation(:users) do
          model User
          operator{ local :and }

          fixed_operator_predicate :email_like do
            type :value, :string
            operator :like
            optional()
          end

          paginate(100, 500, method: :keyset) do
            key :integer, :id, :asc
            column :integer, :hits, :desc
          end

          order do
            column :name, :asc
          end

          optional
        end
      end

      def input
        {
          email_like: 'Jane',
          pgn: {
            dir: :aft,
            lmt: 100,
            ks: { id: 10, hits: 50 }
          },
          ord: [[:name, :asc]]
        }
      end

      def test_cte_query_uses_all_keys
        d = get_def
        _, p = d.from_input(input)
        q = p.build_keyset_query 30, :aft, { id: 20 }
        exp = <<~SQL
          WITH name_cte (name) 
          AS ((SELECT users.name FROM users WHERE (users.email_like LIKE '%Jane%') AND users.id = 20)) 
          SELECT users.id, users.hits FROM users WHERE (users.email_like LIKE '%Jane%') 
          AND ((users.name = (SELECT name FROM name_cte) AND users.id > 20) 
          OR users.name > (SELECT name FROM name_cte)) 
          ORDER BY users.name ASC, users.id ASC LIMIT 30
        SQL
        assert_equal exp.unformat, q.to_sql.unquote
      end
    end
  end
end