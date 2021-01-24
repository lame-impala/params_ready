require_relative '../test_helper'
require_relative '../../lib/params_ready/query/custom_predicate'
require_relative '../../lib/params_ready/query_context'

module ParamsReady
  module Query
    class DynamicCustomPredicateTest < Minitest::Test
      def get_predicate
        CustomPredicateBuilder.instance(:created).include do
          type :hash do
            add(:integer, :days) { optional }
            add :symbol, :operator do
              constrain :enum, [:gt, :lt]
            end
          end

          eligible do |_table, context|
            next false unless is_definite?
            next false if context[:date].nil?

            true
          end

          to_query do |table, context|
            date = context[:date] - self[:days].unwrap_or(0)
            operator = self[:operator].unwrap
            table[:created_at].send(operator, date)
          end
          optional
        end.build
      end

      def test_unpermitted_custom_predicate_returns_nil_from_query
        d = get_predicate
        _, p = d.from_hash({ created: { days: 20, operator: 'lt' }})

        date = Date.parse('2020-07-14')
        context = QueryContext.new(Restriction.prohibit(:created), { date: date })
        assert_nil p.to_query(Subscription.arel_table, context: context)
      end

      def test_eligibility_checked_before_to_query_called
        d = get_predicate
        _, p = d.from_hash({})
        assert_nil p.to_query(:whatever, context: Restriction.blanket_permission)

        _, p = d.from_hash({ created: { days: 20, operator: 'lt' }})
        context = QueryContext.new(Restriction.blanket_permission, { date: nil })
        assert_nil p.to_query(Subscription.arel_table, context: context)
      end

      def test_query_receives_context
        d = get_predicate
        _, p = d.from_hash({ created: { days: 20, operator: 'lt' }})

        date = Date.parse('2020-07-14')
        exp = "subscriptions.created_at < '#{(date - 20.days).strftime('%F')}'"
        context = QueryContext.new(Restriction.blanket_permission, { date: date })
        query = p.to_query(Subscription.arel_table, context: context)
        assert_equal exp, query.to_sql.unquote
      end
    end

    class CustomPredicateTest < Minitest::Test
      def get_predicate
        builder = CustomPredicateBuilder.instance :custom, altn: :cst
        builder.type :hash do
          add :integer, :role, altn: :rl
          add :string, :email, altn: :eml
        end
        builder.to_query do |table, _context|
          table[:role]
            .gteq(self[:role].unwrap)
            .and(table[:email].eq(self[:email].unwrap))
        end
        builder.test do |record|
          record.role >= self[:role].unwrap &&
          record.email == self[:email].unwrap
        end
        builder.build
      end

      def get_scalar_predicate
        CustomPredicateBuilder.instance(:downcase_string, altn: :dc).include do
          type :downcase_string do
            postprocess do |parameter, _|
              next unless parameter.is_definite?
              next if parameter.unwrap =~ /[a-z]{2}-[a-z]{1}\d\d/

              parameter.set_value nil
            end
          end

          to_query do |table, _context|
            next nil if unwrap.nil?

            table[:external_id].eq(unwrap)
          end

          optional
        end.build
      end

      def test_scalar_custom_predicate_works
        d = get_scalar_predicate
        _, p = d.from_hash({ dc: 'AB-C40' })
        assert_equal "users.external_id = 'ab-c40'", p.to_query(User.arel_table).to_sql.unquote
      end

      def test_scalar_custom_predicate_with_invalid_input_returns_nil_from_to_query
        d = get_scalar_predicate
        _, p = d.from_hash({ dc: 'XYZ' })
        assert_nil p.to_query(User.arel_table)
      end

      def test_to_query_works
        pre = get_predicate.create
        pre.data[:role] = 5
        pre.data[:email] = 'abc@d.ef'

        query = pre.to_query(User.arel_table)
        assert_equal "users.role >= 5 AND users.email = 'abc@d.ef'", query.to_sql.unquote
      end

      def test_test_works
        pre = get_predicate.create
        pre.data[:role] = 5
        pre.data[:email] = 'true@e.cz'

        u1 = User.new id: 1, email: 'true@e.cz', role: 5
        u2 = User.new id: 2, email: 'true@e.cz', role: 4
        u3 = User.new id: 3, email: 'false@e.cz', role: 5

        assert pre.test(u1)
        refute pre.test(u2)
        refute pre.test(u3)
      end

      def test_string_is_acceptable_return_value_from_to_query
        d = CustomPredicateBuilder.instance(:string_query).include do
          type :symbol do
            constrain :enum, [:registered, :visitor]
          end

          to_query do |_table, _context|
            "users.info -> 'status' = '#{unwrap}'"
          end
        end.build

        _, p = d.from_hash({ string_query: 'visitor' })
        arel = p.to_query(User.arel_table, context: Restriction.blanket_permission)
        assert_equal "(users.info -> 'status' = 'visitor')", arel.to_sql.unquote
      end
    end
  end
end