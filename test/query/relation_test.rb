require_relative '../test_helper'
require_relative '../../lib/params_ready/query/relation'
require_relative '../../lib/params_ready/input_context'
require_relative '../../lib/params_ready/query/fixed_operator_predicate'
require_relative '../../lib/params_ready/output_parameters'

module ParamsReady
  module Query
    class RelationTest < Minitest::Test
      def get_def(optional: false, relation_default: Extensions::Undefined, max_limit: nil)
        Builder.define_relation(:users, altn: :usr) do
          add :string, :string, altn: :str do
            constrain :enum, %w(foo bar baz)
            default 'foo'
          end

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

          paginate(100, max_limit)
          order do
            column :email, :asc, required: true
            column :name, :asc
            column :hits, :desc
            default [:email, :asc], [:name, :asc]
          end
          optional() if optional
          default(relation_default) unless relation_default == Extensions::Undefined
        end
      end

      def get_relation(*args)
        relation = get_def(*args).create
        relation
      end

      def input_data
        { email_like: '@example.com', name_like: 'Doe' }
      end

      def test_required_ordering_column_overrides_prohibited_ordering
        _, relation = get_def.from_input(input_data)
        scope = DummyScope.new(User)
        intent = Intent.instance(:frontend).prohibit(:email_like, :ordering)
        wrapped = OutputParameters.decorate relation.freeze, intent
        result = wrapped.build_relation scope: scope
        hash = result.to_hash
        assert_equal "(users.name_like LIKE '%Doe%')", hash[:where].first.to_sql.unquote
        assert_equal 1, hash[:ordering].length
        assert_equal 'users.email ASC', hash[:ordering][0].to_sql.unquote
      end

      def test_required_ordering_column_overrides_prohibited_column
        _, relation = get_def.from_input(input_data)
        scope = DummyScope.new(User)
        intent = Intent.instance(:frontend).prohibit(:email_like, ordering: [:email, :name])
        wrapped = OutputParameters.decorate relation.freeze, intent
        result = wrapped.build_relation scope: scope
        hash = result.to_hash
        assert_equal "(users.name_like LIKE '%Doe%')", hash[:where].first.to_sql.unquote
        assert_equal 1, hash[:ordering].length
        assert_equal 'users.email ASC', hash[:ordering][0].to_sql.unquote
      end

      def test_perform_count_works_with_output_parameters
        _, relation = get_def.from_input(input_data)
        scope = DummyScope.new(User)

        wrapped = OutputParameters.decorate relation.freeze, :frontend, Restriction.prohibit(:email_like, ordering: :email)
        _count = wrapped.perform_count scope: scope
        hash = scope.to_hash
        assert_equal "(users.name_like LIKE '%Doe%')", hash[:where].first.to_sql.unquote
      end

      def test_build_select_works_with_output_parameters
        _, relation = get_def.from_input(input_data)
        intent = Intent.instance(:frontend).prohibit(:email_like, ordering: [:email, :name])
        wrapped = OutputParameters.decorate relation.freeze, intent
        arel = wrapped.build_select model_class: User
        exp = <<~SQL
          SELECT * FROM users 
          WHERE (users.name_like LIKE '%Doe%') 
          ORDER BY users.email ASC 
          LIMIT 100 OFFSET 0
        SQL
        assert_equal exp.unformat, arel.to_sql.unquote
      end

      def test_relation_basic_accessors_work
        d = get_def
        _, relation = d.from_hash({})
        assert_equal [[:email, :asc], [:name, :asc]], relation[:ordering].to_array
        assert_equal 0, relation.offset
        assert_equal 100, relation.limit
        assert_equal 1, relation.page_no
        refute relation.has_previous?
        assert relation.has_next?(count: 500)
        # Besides predicates, relation can have regular parameters too
        assert_equal 'foo', relation[:string].unwrap
      end

      def test_paginating_works
        d = get_def
        _, relation = d.from_hash({})
        assert_nil relation.previous_page
        last_page = relation.last_page(count: 500)
        assert_equal 400, last_page.offset
        assert_equal 100, last_page.limit

        next_page = relation.next_page(count: 500)
        assert_equal 100, next_page.offset
        assert_equal 100, next_page.limit
        assert_equal 2, next_page.page_no
        assert next_page.has_previous?
        refute_nil next_page.previous_page
        assert next_page.has_next?(count: 500)

        first = next_page.first
        assert_equal({}, first)

        next_page[:pagination].limit = 23
        first = next_page.first
        assert_equal({ pgn: '0-23' }, first)
      end

      def test_max_limit_can_be_set_for_pagination
        d = get_def max_limit: 500
        _, relation = d.from_hash({ usr: { pgn: [57, 99] }})
        assert_equal 99, relation.limit
        _, relation = d.from_hash({ usr: { pgn: [57, 501] }})
        assert_equal 500, relation.limit
      end

      def test_ordering_works
        d = get_def
        _, relation = d.from_hash({})
        relation[:pagination].offset = 100
        relation.freeze
        toggled = relation.toggled_order :email
        assert_equal 0, toggled.offset
        assert_equal [[:email, :desc], [:name, :asc]], toggled[:ordering].to_array

        toggled = relation.reordered :name, :desc
        assert_equal 0, toggled.offset
        assert_equal [[:name, :desc], [:email, :asc]], toggled[:ordering].to_array
      end

      def test_limited_at_works
        d = get_def
        _, relation = d.from_hash({})
        relation.freeze
        new_limit = relation.limited_at(55)
        assert_equal 55, new_limit[:pagination].limit
      end
    end
  end
end