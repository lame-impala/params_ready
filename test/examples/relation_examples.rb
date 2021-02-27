require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class RelationExamples < Minitest::Test
      def test_trivial_join_example_legal
        relation = Builder.define_relation :users do
          model User
          join_table Profile.arel_table, :outer do
            on(:id).eq(:user_id)
          end
          # ...
        end.create

        exp = <<~SQL
          SELECT * FROM users LEFT OUTER JOIN profiles ON users.id = profiles.user_id
        SQL
        assert_equal exp.unformat, relation.build_select.to_sql.unquote
      end

      def test_nontrivial_join_example_legal
        relation = Builder.define_relation :users do
          model User
          join_table Profile.arel_table, :inner do
            on("users.id = profiles.owner_id AND profiles.owner_type = 'User'")
          end
          # ...
        end.create

        exp = <<~SQL
          SELECT * FROM users INNER JOIN profiles ON (users.id = profiles.owner_id AND profiles.owner_type = 'User')
        SQL
        assert_equal exp.unformat, relation.build_select.to_sql.unquote
      end

      def get_def
        Builder.define_relation :users do
          model User
          operator { local :and }
          join_table Profile.arel_table, :outer do
            on(:user_id).eq(:id)
          end
          variable_operator_predicate :role_variable_operator, attr: :role do
            operators :equal, :greater_than_or_equal, :less_than_or_equal
            type :value, :integer
            optional
          end
          fixed_operator_predicate :name_like, attr: :name do
            arel_table Profile.arel_table
            operator :like
            type :value, :string
            optional
          end
          custom_predicate :active_custom_predicate do
            type :hash do
              add(:integer, :days_ago) { default 1 }
              add(:boolean, :checked) { optional }
              default :inferred
            end

            to_query do |table, context|
              next nil unless self[:checked].unwrap

              date = context[:date] - self[:days_ago].unwrap
              table[:last_access].gteq(date)
            end
          end
          array_grouping_predicate :having_subscriptions do
            operator do
              default :and
            end
            prototype :polymorph_predicate, :polymorph do
              type :exists_predicate, :subscription_category_exists do
                arel_table Subscription.arel_table
                related { on(:id).eq(:user_id) }
                fixed_operator_predicate :category_equal, attr: :category do
                  operator :equal
                  type :value, :string
                end
              end
              type :exists_predicate, :subscription_channel_exists do
                arel_table Subscription.arel_table
                related { on(:id).eq(:user_id) }
                fixed_operator_predicate :channel_equal, attr: :channel do
                  operator :equal
                  type :value, :integer
                end
              end
            end
            optional
          end
          paginate 100, 500
          order do
            column :created_at, :desc
            column :email, :asc
            column :name, :asc, arel_table: Profile.arel_table, nulls: :last
            column :ranking, :asc, arel_table: :none
            default [:created_at, :desc], [:email, :asc]
          end
        end
      end

      def input
        {
          role_variable_operator: { operator: :equal, value: 1 },
          name_like: 'Ben',
          active_custom_predicate: {
            checked: true,
            days_ago: 5
          },
          having_subscriptions: {
            array: [
              { subscription_category_exists: { category_equal: 'vip' }},
              { subscription_channel_exists: { channel_equal: 1 }}
            ],
            operator: :or
          },
          ordering: [[:name, :asc], [:email, :asc], [:ranking, :desc]]
        }
      end

      def test_example_relation_works
        definition = get_def
        _, relation = definition.from_input(input, context: Format.instance(:backend))

        date = Date.parse('2020-05-23')
        context = QueryContext.new(Restriction.blanket_permission, { date: date })
        query = relation.build_select(context: context)
        exp = <<~SQL
          SELECT * FROM users 
          LEFT OUTER JOIN profiles ON users.user_id = profiles.id 
          WHERE 
           (users.role = 1 
            AND profiles.name LIKE '%Ben%' 
            AND users.last_access >= '2020-05-18' 
            AND 
             (EXISTS 
               (SELECT * FROM subscriptions 
                WHERE (subscriptions.category = 'vip') 
                AND (users.id = subscriptions.user_id) LIMIT 1)
            OR EXISTS 
               (SELECT * FROM subscriptions 
                WHERE (subscriptions.channel = 1) 
                AND (users.id = subscriptions.user_id) LIMIT 1)))
          ORDER BY CASE WHEN profiles.name IS NULL THEN 1 ELSE 0 END, 
                             profiles.name ASC, 
                             users.email ASC, ranking DESC 
          LIMIT 100 OFFSET 0
        SQL
        assert_equal exp.unformat, query.to_sql.unquote

        exp = [[:name, :asc], [:ranking, :desc]]

        assert_equal exp, relation.reordered(:email, :none).to_hash(Format.instance(:backend))[:users][:ordering]

        params = relation.page(3, count: 1000).to_hash(Format.instance(:frontend))
        exp = '300-100'

        assert_equal exp, params[:users][:pgn]
      end

      def test_example_restriction_works
        definition = get_def
        _, relation = definition.from_input(input, context: Format.instance(:backend))

        context = QueryContext.new(Restriction.permit(:name_like, ordering: [:name]))
        query = relation.build_select(context: context)
        exp = <<~SQL
          SELECT * FROM users 
          LEFT OUTER JOIN profiles ON users.user_id = profiles.id 
          WHERE (profiles.name LIKE '%Ben%')
          ORDER BY CASE WHEN profiles.name IS NULL THEN 1 ELSE 0 END, 
                             profiles.name ASC 
          LIMIT 100 OFFSET 0
        SQL
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def test_ordering_examples
        definition = get_def
        _, relation = definition.from_input(input, context: Format.instance(:backend))

        t = relation.toggle(:email)
        r = relation.reorder(:email, :desc)
        exp = 'email-desc|name-asc|ranking-desc'

        assert_equal({ name: [:asc, 0], email: [:asc, 1], ranking: [:desc, 2] }, relation[:ordering].by_columns)
        assert_equal(exp, t[:ord])
        assert_equal(exp, r[:ord])
      end
    end
  end
end