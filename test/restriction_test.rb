require_relative 'test_helper'
require_relative '../lib/params_ready/query/relation.rb'
require_relative '../lib/params_ready/query/variable_operator_predicate.rb'
require_relative '../lib/params_ready/query/array_grouping.rb'
require_relative '../lib/params_ready/query/polymorph_predicate.rb'
require_relative '../lib/params_ready/query/exists_predicate.rb'
require_relative '../lib/params_ready/restriction.rb'
require_relative '../lib/params_ready/input_context.rb'
require_relative '../lib/params_ready/query_context.rb'

module ParamsReady
  class Restriction
    class AllowlistTest < Minitest::Test
      def value1
        {
          users: {
            user_filters: {
              email_like: '@example.com',
              role_variable_operator: {
                value: 10,
                operator: :less_than_or_equal
              },
              operator: :and
            },
            subscriptions_owners: {
              array: [
                {
                  subscription_exists: {
                    valid_equal: true,
                    channel_equal: 0
                  }
                },
                {
                  audience_variable_operator: {
                    operator: :greater_than_or_equal,
                    value: 100
                  }
                }
              ],
              operator: :and
            }
          }
        }
      end

      def get_relation
        Builder.define_relation(:users, altn: :uu) do
          model User
          add_predicate :structured_grouping_predicate, :user_filters, altn: :uf do
            fixed_operator_predicate :email_like, altn: :eml_lk, attr: :email do
              operator :like
              type :value, :string
            end
            variable_operator_predicate :role_variable_operator, altn: :rl_vop, attr: :role do
              operators :equal, :greater_than_or_equal, :less_than_or_equal
              type :value, :integer
            end
            operator do
              default :and
            end
          end

          array_grouping_predicate :subscriptions_owners, altn: :so do
            prototype :polymorph_predicate, :polymorph, altn: :pm do
              type :exists_predicate, :subscription_exists, altn: :s do
                fixed_operator_predicate :valid_equal, altn: :vld_eq, attr: :valid do
                  operator :equal
                  type :value, :boolean
                end
                fixed_operator_predicate :channel_equal, altn: :cnl_eq, attr: :channel do
                  operator :equal
                  type :value, :integer
                end
                operator do
                  local :and
                end
                arel_table Subscription.arel_table
                related do
                  on(:id).eq(:users_id)
                end
              end
              type :variable_operator_predicate, :audience_variable_operator, altn: :au_vop, attr: :audience do
                operators :equal, :greater_than_or_equal, :less_than_or_equal
                type :value, :integer
              end
            end
            operator do
              default :and
            end
          end
          operator do
            local :and
          end
        end
      end

      def test_with_blanket_permissions_all_predicates_apply
        d = get_relation
        _, r = d.from_hash(value1, context: Format.instance(:backend))
        exp = <<-SQL
          ((users.email LIKE '%@example.com%' 
            AND users.role <= 10) 
            AND (EXISTS (SELECT * FROM subscriptions 
              WHERE (subscriptions.valid = 1 
                AND subscriptions.channel = 0) 
              AND (users.id = subscriptions.users_id) LIMIT 1) 
            AND users.audience >= 100))
        SQL
        assert_equal exp.unformat, r.to_query(User.arel_table).to_sql.unquote
      end

      def test_with_all_permitting_restriction_all_predicates_apply
        restriction = Restriction.permit(
            { user_filters: [:email_like, { role_variable_operator: [:operator, :value] },  :operator] },
            { subscriptions_owners: [{ array: [ { subscription_exists: [:channel_equal, :valid_equal] }, { audience_variable_operator: [:operator, :value] }] }, :operator ] }
        )
        d = get_relation
        _, r = d.from_hash(value1, context: Format.instance(:backend))
        exp = <<-SQL
          ((users.email LIKE '%@example.com%' 
            AND users.role <= 10) 
            AND (EXISTS (SELECT * FROM subscriptions 
              WHERE (subscriptions.valid = 1 
                AND subscriptions.channel = 0) 
              AND (users.id = subscriptions.users_id) LIMIT 1) 
            AND users.audience >= 100))
        SQL
        with_query_context restrictions: [restriction, Denylist.new] do |context|
          sql = r.to_query(User.arel_table, context: context).to_sql.unquote
          assert_equal exp.unformat, sql
        end
      end

      def test_with_selective_restriction_correct_predicates_apply
        allowlist = Restriction.permit(
          { user_filters: [:email_like, { role_variable_operator: [:operator, :value] },  :operator] },
          { subscriptions_owners: [{ array: [ { subscription_exists: [:channel_equal] }] }, :operator ] }
        )
        denylist = Restriction.prohibit(
          subscriptions_owners: [{ array: [ { subscription_exists: [:valid_equal] }, :audience_variable_operator ] }]
        )
        d = get_relation
        _, r = d.from_hash(value1, context: Format.instance(:backend))
        exp = <<-SQL
          ((users.email LIKE '%@example.com%' 
            AND users.role <= 10) 
            AND (EXISTS (SELECT * FROM subscriptions 
              WHERE (subscriptions.channel = 0) 
              AND (users.id = subscriptions.users_id) LIMIT 1)))
        SQL
        with_query_context restrictions: [allowlist, denylist] do |context|
          sql = r.to_query(User.arel_table, context: context).to_sql.unquote
          assert_equal exp.unformat, sql
        end
      end

      def test_build_query_works_with_selective_restriction
        allowlist = Restriction.permit(
            { user_filters: [:email_like, { role_variable_operator: [:operator, :value] },  :operator] },
            { subscriptions_owners: [{ array: [ { subscription_exists: [:channel_equal] }] }, :operator ] }
        )
        denylist = Restriction.prohibit(
          subscriptions_owners: [{ array: [ { subscription_exists: [:valid_equal] }, :audience_variable_operator ] }]
        )
        d = get_relation
        _, r = d.from_hash(value1, context: Format.instance(:backend))
        exp = <<-SQL
          SELECT * FROM users WHERE
          ((users.email LIKE '%@example.com%' 
            AND users.role <= 10) 
            AND (EXISTS (SELECT * FROM subscriptions 
              WHERE (subscriptions.channel = 0) 
              AND (users.id = subscriptions.users_id) LIMIT 1)))
        SQL
        with_query_context restrictions: [allowlist, denylist] do |context|
          sql = r.build_select(context: context).to_sql.unquote
          assert_equal exp.unformat, sql
        end
      end

      def test_restriction_equals_to_self
        al = Restriction.permit(:a, b: [:c, :d])
        assert_equal al, al
      end

      def test_restriction_equals_to_identical
        al1 = Restriction.permit(:a, b: [:c, :d])
        al2 = Restriction.permit(:a, b: [:c, :d])
        assert_equal al1, al2
      end

      def test_blanket_permission_equals_to_identical
        al1 = Restriction.permit(Restriction::Everything)
        al2 = Restriction.permit(Restriction::Everything)
        assert_equal al1, al2
      end

      def test_blanket_permission_equals_not_to_different
        al1 = Restriction.permit(:a, b: [:c, :d])
        al2 = Restriction.permit(:a, b: [:c, :d, :e])
        assert_operator al1, :!=, al2
      end
    end
  end
end