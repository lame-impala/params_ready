require_relative '../test_helper'
require_relative '../../lib/params_ready/ordering/ordering'
require_relative '../../lib/params_ready/value/validator'
require_relative '../../lib/params_ready/input_context'

module ParamsReady
  module Ordering
    class OrderingTest < Minitest::Test
      def get_param_definition(null_handling_policy: :default)
        email = Column.new :asc, arel_table: nil, expression: nil, nulls: null_handling_policy
        name = Column.new :asc, arel_table: nil, expression: nil, nulls: null_handling_policy
        hits = Column.new :desc, arel_table: nil, expression: nil, nulls: null_handling_policy
        OrderingParameterDefinition.new({ email: email, name: name, hits: hits }, [[:email, :asc], [:name, :desc]]).finish
      end

      def get_param(*args)
        get_param_definition(*args).create
      end

      def test_ordering_defaults_to_empty_array
        p = OrderingParameterBuilder.instance.include do
          column :id, :asc
        end.build.create

        assert_equal [], p.format(Intent.instance(:backend))
        assert_equal '', p.format(Intent.instance(:frontend))
      end

      def test_builder_raises_if_no_columns_defined
        err = assert_raises(ParamsReadyError) do
          p = OrderingParameterBuilder.instance.build
        end
        assert_equal 'No ordering column defined', err.message
      end

      def test_canonicalization_works
        definition = begin
          builder = OrderingParameterBuilder.instance
          builder.column :email, :asc
          builder.column :role, :desc
          builder.default [:email, :asc], [:role, :desc]
          builder.build
        end
        canonical, _validator = definition.try_canonicalize "email-desc|role-asc", Format.instance(:frontend)
        assert_equal :email, canonical[0].first.unwrap
        assert_equal :desc, canonical[0].second.unwrap
        assert_equal :role, canonical[1].first.unwrap
        assert_equal :asc, canonical[1].second.unwrap
      end

      def test_ordering_works
        d = get_param_definition
        _, ordering = d.from_hash({ord: "email-desc|hits-desc"})
        assert_equal [[:email, :desc], [:hits, :desc]], ordering.to_array
        toggled = ordering.toggled_order :hits
        assert_equal [[:hits, :asc], [:email, :desc]], toggled.to_array
        toggled = toggled.toggled_order :email
        assert_equal [[:email, :asc], [:hits, :asc]], toggled.to_array
        toggled = ordering.toggled_order :email
        assert_equal [[:email, :asc], [:hits, :desc]], toggled.to_array
        toggled = toggled.toggled_order :name
        assert_equal [[:name, :asc], [:email, :asc], [:hits, :desc]], toggled.to_array
      end

      def test_inversion_works
        d = get_param_definition
        _, ordering = d.from_hash({ord: "email-desc|hits-asc"})
        inverted = ordering.inverted_order
        assert_equal [[:email, :asc], [:hits, :desc]], inverted.to_array
      end

      def test_order_for_column_is_found
        d = get_param_definition
        _, ordering = d.from_hash({ord: "email-desc|hits-asc"})
        assert_equal :desc, ordering.order_for(:email)
        assert_equal :asc, ordering.order_for(:hits)
        assert_equal :none, ordering.order_for(:name)
      end

      def test_exports_to_hash_with_columns_as_keys
        d = get_param_definition
        _, ordering = d.from_hash({ord: "email-desc|hits-asc"})
        hash = ordering.by_columns
        assert_equal :desc, hash[:email]
        assert_equal :asc, hash[:hits]
        assert_equal :none, hash[:anything_else]
      end

      def test_reordering_works
        d = get_param_definition
        _, ordering = d.from_hash({ord: "email-desc|hits-desc"})
        assert_equal [[:email, :desc], [:hits, :desc]], ordering.to_array
        reordered = ordering.reordered :hits, :asc
        assert_equal [[:hits, :asc], [:email, :desc]], reordered.to_array
        reordered = ordering.reordered :email, :desc
        assert_equal [[:email, :desc], [:hits, :desc]], reordered.to_array
        reordered = reordered.reordered :email, :none
        assert_equal [[:hits, :desc]], reordered.to_array
        reordered = reordered.reordered :name, :asc
        assert_equal [[:name, :asc], [:hits, :desc]], reordered.to_array
      end

      def test_duplicates_are_removed_from_input_retaining_the_prior_occurrences
        d = get_param_definition
        _, ordering = d.from_hash({ord: "email-desc|hits-desc|hits-asc|email-asc"})
        assert_equal [[:email, :desc], [:hits, :desc]], ordering.to_array
        _, ordering = d.from_hash({ord: "email-desc|hits-desc|email-asc|hits-asc"})
        assert_equal [[:email, :desc], [:hits, :desc]], ordering.to_array
      end

      def test_to_hash_if_eligible_returns_nil_if_value_is_default
        ordering = get_param
        assert_nil ordering.to_hash_if_eligible(Intent.instance(:minify_only))
      end

      def test_to_hash_if_eligible_writes_delimited_string_if_marshal_is_true
        d = get_param_definition
        _, ordering = d.from_hash({ord: "email-desc|hits-asc"})
        assert_equal({ ord: 'email-desc|hits-asc' }, ordering.to_hash_if_eligible(Intent.instance(:frontend)))
      end

      def test_to_hash_if_eligible_writes_array_if_marshal_is_false
        d = get_param_definition
        _, ordering = d.from_hash({ord: "email-desc|hits-asc"})
        assert_equal({ ordering: [[:email, :desc], [:hits, :asc]] }, ordering.to_hash_if_eligible(Intent.instance(:backend)))
      end

      def test_nulls_last_option_works
        d = get_param_definition null_handling_policy: :last
        _, ordering = d.from_hash({ord: 'email-desc|hits-asc'})
        table = User.arel_table
        query = table.project(Arel.star).order(ordering.to_arel(table))
        exp = <<~SQL
          SELECT * FROM users
          ORDER BY CASE WHEN users.email IS NULL THEN 1 ELSE 0 END,
          users.email DESC,
          CASE WHEN users.hits IS NULL THEN 1 ELSE 0 END,
          users.hits ASC
        SQL
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def test_nulls_last_option_works_with_inverted_ordering
        d = get_param_definition null_handling_policy: :last
        _, ordering = d.from_hash({ord: 'email-desc|hits-asc'})
        table = User.arel_table
        query = table.project(Arel.star).order(ordering.to_arel(table, inverted: true))
        exp = <<~SQL
          SELECT * FROM users
          ORDER BY CASE WHEN users.email IS NULL THEN 0 ELSE 1 END,
          users.email ASC,
          CASE WHEN users.hits IS NULL THEN 0 ELSE 1 END,
          users.hits DESC
        SQL
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def test_nulls_first_option_works
        d = get_param_definition null_handling_policy: :first
        _, ordering = d.from_hash({ ord: 'email-desc|hits-asc' })
        table = User.arel_table
        query = table.project(Arel.star).order(ordering.to_arel(table))
        exp = <<~SQL
          SELECT * FROM users
          ORDER BY CASE WHEN users.email IS NULL THEN 0 ELSE 1 END,
          users.email DESC,
          CASE WHEN users.hits IS NULL THEN 0 ELSE 1 END,
          users.hits ASC
        SQL
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def test_nulls_first_option_works_with_inverted_ordering
        d = get_param_definition null_handling_policy: :first
        _, ordering = d.from_hash({ ord: 'email-desc|hits-asc' })
        table = User.arel_table
        query = table.project(Arel.star).order(ordering.to_arel(table, inverted: true))
        exp = <<~SQL
          SELECT * FROM users
          ORDER BY CASE WHEN users.email IS NULL THEN 1 ELSE 0 END,
          users.email ASC,
          CASE WHEN users.hits IS NULL THEN 1 ELSE 0 END,
          users.hits DESC
        SQL
        assert_equal exp.unformat, query.to_sql.unquote
      end

      def expected_sql_using_expression(expr)
        exp = <<~SQL
          SELECT * FROM "users"
          ORDER BY CASE WHEN #{expr} IS NULL THEN 1 ELSE 0 END,
          #{expr} ASC,
          "users"."email" ASC
        SQL
        exp.unformat
      end

      def get_ordering_using_expression(expr)
        d = OrderingParameterBuilder.instance.include do
          column :email, :asc
          column :name, :asc, arel_table: :none, nulls: :last, expression: expr
          default [:email, :asc]
        end.build
        _, ordering = d.from_hash({ ord: 'name-asc|email-asc' })
        ordering
      end

      def test_expression_option_works_with_string
        expr = 'users.name COLLATE "C"'
        ordering = get_ordering_using_expression expr

        table = User.arel_table
        query = table.project(Arel.star).order(ordering.to_arel(table))

        assert_equal expected_sql_using_expression(expr), query.to_sql
      end

      def test_expression_option_works_with_sql_literal
        expr = 'users.name COLLATE "C"'
        ordering = get_ordering_using_expression Arel::Nodes::SqlLiteral.new(expr)

        table = User.arel_table
        query = table.project(Arel.star).order(ordering.to_arel(table))

        assert_equal expected_sql_using_expression(expr), query.to_sql
      end

      def test_expression_option_works_with_arel_attribute
        table = User.arel_table
        ordering = get_ordering_using_expression table[:name]

        query = table.project(Arel.star).order(ordering.to_arel(table))

        assert_equal expected_sql_using_expression('"users"."name"'), query.to_sql
      end

      def test_expression_option_works_with_proc_returning_string
        expr_proc = proc { |_table, context|
          coll = context[:coll]
          "users.name COLLATE \"#{coll}\""
        }
        ordering = get_ordering_using_expression expr_proc

        context = QueryContext.new(Restriction.blanket_permission, { coll: 'C' })
        table = User.arel_table
        query = table.project(Arel.star).order(ordering.to_arel(table, context: context))

        assert_equal expected_sql_using_expression('users.name COLLATE "C"'), query.to_sql
      end

      def test_expression_option_works_with_proc_returning_arel
        expr_proc = proc { |_table, context|
          coll = context[:coll]
          Arel::Nodes::SqlLiteral.new("users.name COLLATE \"#{coll}\"")
        }
        ordering = get_ordering_using_expression expr_proc
        context = QueryContext.new(Restriction.blanket_permission, { coll: 'C' })
        table = User.arel_table
        query = table.project(Arel.star).order(ordering.to_arel(table, context: context))

        assert_equal expected_sql_using_expression('users.name COLLATE "C"'), query.to_sql
      end
    end

    class OrderingWithRequiredColumnsTest < Minitest::Test
      def get_def
        OrderingParameterBuilder.instance.include do
          column :id, :asc, required: true
          column :created_at, :asc, required: true
          column :name, :asc
          column :ranking, :desc
          default [:name, :asc]
        end.build
      end

      def test_required_columns_are_set_correctly
        d = get_def

        rq = d.instance_variable_get(:@required_columns)
        assert_equal [:id, :created_at], rq
        assert rq.frozen?
      end

      def test_required_columns_are_in_the_default
        d = get_def
        default = d.default
        assert_equal([[:name, :asc], [:id, :asc], [:created_at, :asc]], default.map(&:unwrap))
      end

      def test_required_columns_are_appended_if_missing
        d = get_def
        _, p = d.from_input('name-desc|ranking-desc')
        assert_equal([[:name, :desc], [:ranking, :desc], [:id, :asc], [:created_at, :asc]], p.unwrap(&:unwrap))
      end

      def test_required_columns_are_not_appended_if_present
        d = get_def
        _, p = d.from_input('id-desc|name-desc|ranking-desc')
        assert_equal([[:id, :desc], [:name, :desc], [:ranking, :desc], [:created_at, :asc]], p.unwrap(&:unwrap))
      end

      def test_required_columns_override_restriction
        d = get_def
        _, p = d.from_input('id-desc|name-desc|ranking-desc')

        intent = Intent.instance(:backend).prohibit(:id)
        arr = p.to_array(intent)
        assert_equal([[:id, :desc], [:name, :desc], [:ranking, :desc], [:created_at, :asc]], arr)
      end
    end
  end
end