require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class PredicateExamples < Minitest::Test
      def test_example_fixed_operator_example_works
        definition = Query::FixedOperatorPredicateBuilder.instance(:role_equal, attr: :role).include do
          operator :equal
          type(:value, :integer)
          default 0
          arel_table User.arel_table
        end.build

        _, p = definition.from_input(32)

        exp = "users.role = 32"
        assert_equal exp, p.to_query(User.arel_table).to_sql.unquote
      end

      def test_example_fixed_operator_example_using_expression_works
        definition = Query::FixedOperatorPredicateBuilder.instance(:activity_equal).include do
          operator :equal
          type(:value, :integer)
          default 0
          attribute name: :activity, expression: '(SELECT count(id) FROM activities WHERE activities.user_id = users.id)'
          arel_table :none
        end.build

        _, p = definition.from_input(32)
        exp = "(SELECT count(id) FROM activities WHERE activities.user_id = users.id) = 32"
        assert_equal exp, p.to_query(User.arel_table).to_sql.unquote
      end

      def test_example_fixed_operator_example_using_a_proc_works
        definition = Query::FixedOperatorPredicateBuilder.instance(:aggreagate_equal).include do
          operator :equal
          type(:value, :integer)
          default 0
          attribute name: :aggregate, expression: proc { |_table, context|
            "(SELECT count(id) FROM #{context[:table_name]} WHERE #{context[:table_name]}.user_id = users.id)"
          }
          arel_table :none
        end.build

        _, p = definition.from_input(32)
        exp = "(SELECT count(id) FROM activities WHERE activities.user_id = users.id) = 32"
        context = QueryContext.new(Restriction.blanket_permission, { table_name: :activities })
        assert_equal exp, p.to_query(User.arel_table, context: context).to_sql.unquote
      end

      def test_variable_operator_example_works
        role_variable_operator = Query::VariableOperatorPredicateBuilder.instance(
          :role_variable_operator,
          attr: :role
        ).include do
          operators :equal, :greater_than_or_equal, :less_than_or_equal
          type :value, :integer
          optional
        end.build.create

        role_variable_operator.set_value(operator: :greater_than_or_equal, value: 8)

        exp = { role_variable_operator: { op: :gteq, val: 8 }}
        assert_equal exp, role_variable_operator.to_hash(Format.instance(:json))
      end

      def test_exists_predicate_example_works
        definition = Query::ExistsPredicateBuilder.instance(:subscription_channel_exists).include do
          arel_table Subscription.arel_table
          related { on(:id).eq(:user_id) }
          fixed_operator_predicate :channel_equal, attr: :channel do
            operator :equal
            type :value, :integer
          end
        end.build
        _, subscription_channel_exists = definition.from_input({ channel_equal: 5 }, context: :backend)

        expected = <<~SQL
          EXISTS
           (SELECT * FROM subscriptions
           WHERE (subscriptions.channel = 5)
           AND (users.id = subscriptions.user_id)
           LIMIT 1)
        SQL
        sql = subscription_channel_exists.to_query(User.arel_table).to_sql
        assert_equal expected.unformat, sql.unquote
      end

      def test_exists_predicate_example_works_with_literal_related_clause
        definition = Query::ExistsPredicateBuilder.instance(:subscription_channel_exists).include do
          arel_table Subscription.arel_table
          related { on("users.id = subscriptions.subscriber_id AND subscriptions.subscriber_type = 'User'") }
          fixed_operator_predicate :channel_equal, attr: :channel do
            operator :equal
            type :value, :integer
          end
        end.build
        _, subscription_channel_exists = definition.from_input({ channel_equal: 5 }, context: :backend)

        expected = <<~SQL
          EXISTS
           (SELECT * FROM subscriptions
           WHERE (subscriptions.channel = 5)
           AND (users.id = subscriptions.subscriber_id AND subscriptions.subscriber_type = 'User')
           LIMIT 1)
        SQL
        sql = subscription_channel_exists.to_query(User.arel_table).to_sql
        assert_equal expected.unformat, sql.unquote
      end

      def test_example_nullness_predicate_definition_is_legal
        profile_null = Query::NullnessPredicateBuilder.instance(:id).include do
          arel_table Profile.arel_table
        end.build.create
        profile_null.set_value true
        assert_equal 'profiles.id IS NULL', profile_null.to_query(User.arel_table).to_sql.unquote
        profile_null.set_value false
        assert_equal 'NOT ("profiles"."id" IS NULL)', profile_null.to_query(User.arel_table).to_sql
      end

      def test_example_polymorph_definition_is_legal
        definition = Query::PolymorphPredicateBuilder.instance(:poly).include do
          type :fixed_operator_predicate, :name_like, attr: :name do
            type :value, :string
            operator :like
          end
          type :variable_operator_predicate, :role_vop, attr: :role do
            type :value, :integer
            operators :less_than_or_equal, :equal, :greater_than_or_equal
          end
        end.build

        _, p1 = definition.from_input({ name_like: 'Jane' })
        assert_equal "users.name LIKE '%Jane%'", p1.to_query(User.arel_table).to_sql.unquote

        _, p2 = definition.from_input({ role_vop: { val: 4, op: :lteq }})
        assert_equal "users.role <= 4", p2.to_query(User.arel_table).to_sql.unquote
      end

      def test_custom_predicate_example_works
        definition = Query::CustomPredicateBuilder.instance(:search_by_name).include do
          type :hash do
            add :string, :search
            add :symbol, :operator do
              constrain :enum, %i(equal like)
              default :equal
            end
          end
          to_query do |table, _context|
            search = self[:search].unwrap
            return if search.empty?

            column = table[:name]
            unaccent = Arel::Nodes::NamedFunction.new('unaccent', [column])
            if self[:operator].unwrap == :like
              unaccent.matches("%#{search}%")
            else
              unaccent.eq(search)
            end
          end
        end.build

        _, parameter = definition.from_input({ search: 'John', operator: 'like' })
        assert_equal "unaccent(users.name) LIKE '%John%'", parameter.to_query(User.arel_table).to_sql.unquote

        _, parameter = definition.from_input({ search: '', operator: 'like' })
        assert_nil parameter.to_query(User.arel_table)
      end

      def test_structured_grouping_example_works
        definition = Query::StructuredGroupingBuilder.instance(:grouping).include do
          operator
          fixed_operator_predicate :first_name_like, attr: :first_name do
            operator :like
            type :value, :string
            optional
          end

          fixed_operator_predicate :last_name_like, attr: :last_name do
            operator :like
            type :value, :string
            optional
          end
        end.build

        input = { operator: :and, first_name_like: 'John', last_name_like: 'Doe' }
        _, structured_grouping = definition.from_input(input, context: :backend)

        exp = <<~SQL
          (users.first_name LIKE '%John%' AND users.last_name LIKE '%Doe%')
        SQL

        query = structured_grouping.to_query(User.arel_table)
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def test_array_grouping_example_works
        definition = Query::ArrayGroupingBuilder.instance(:grouping).include do
          operator
          prototype :fixed_operator_predicate, :name do
            operator :like
            type :value, :string
          end
        end.build

        input = { operator: :or, array: %w[John Doe] }
        _, array_grouping = definition.from_input(input, context: :backend)

        exp = <<~SQL
          (users.name LIKE '%John%' OR users.name LIKE '%Doe%')
        SQL

        query = array_grouping.to_query(User.arel_table)
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def test_array_grouping_with_polymorph_example_works
        definition = Query::ArrayGroupingBuilder.instance(:grouping).include do
          operator
          prototype :polymorph_predicate do
            type :fixed_operator_predicate, :name_like, altn: :nlk, attr: :name do
              type :value, :string
              operator :like
            end
            type :variable_operator_predicate, :role_variable_operator, altn: :rvop, attr: :role do
              type :value, :integer
              operators :less_than_or_equal, :equal, :greater_than_or_equal
            end
          end
          optional
        end.build


        _, p = definition.from_input({ a: [{ nlk: 'Jane' }, { rvop: { val: 4, op: :lteq }}], op: :and })
        exp = <<~SQL
          (users.name LIKE '%Jane%' AND users.role <= 4)
        SQL

        assert_equal exp.unformat, p.to_query(User.arel_table).to_sql.unquote
      end
    end
  end
end