require_relative '../test_helper'
require_relative '../../lib/params_ready/query/nullness_predicate'

module ParamsReady
  module Query
    class NullnessPredicateTest < Minitest::Test
      def get_predicate_definition(optional: false, default: nil)
        builder = NullnessPredicateBuilder.instance :profile_id_is_null, altn: :prf_id_is_nl, attr: :id
        builder.arel_table Profile.arel_table
        builder.associations :profile
        builder.optional if optional
        builder.default(default) unless default.nil?
        definition = builder.build
        definition
      end

      def get_predicate(*args)
        get_predicate_definition(*args).create
      end

      def get_predicate_for_computed_column
        NullnessPredicateBuilder.instance(:sum).include do
          arel_table :none
        end.build.create
      end

      def test_predicate_can_be_optional
        definition = get_predicate_definition(optional: true)
        _, predicate = definition.from_hash({})
        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        assert_equal({ profile_id_is_null: nil }, predicate.to_hash_if_eligible(Intent.instance(:backend)))
        assert_nil predicate.unwrap
        assert_nil predicate.to_query_if_eligible(:whatever, context: Restriction.blanket_permission)
        assert_nil predicate.test(:whatever)
      end

      def test_predicate_can_have_default
        definition = get_predicate_definition default: true
        _, predicate = definition.from_hash({})
        assert_nil predicate.to_hash_if_eligible(Intent.instance(:frontend))
        assert_equal({ profile_id_is_null: true }, predicate.to_hash_if_eligible(Intent.instance(:backend)))
        assert_equal true, predicate.unwrap
        assert_equal '"profiles"."id" IS NULL', predicate.to_query(User.arel_table).to_sql
        u = User.new(id: 2, email: 'no.profile@example.com', role: 'client')
        assert predicate.test(u)
      end

      def test_delegating_parameter_works
        predicate = get_predicate
        predicate.set_value true
        clone = predicate.dup
        assert_equal clone, predicate
        assert clone.is_definite?
        refute clone.is_nil?
        refute clone.is_undefined?
        refute clone.is_default?
        assert_equal :profile_id_is_null, clone.name
        assert_equal :prf_id_is_nl, clone.altn
        assert_equal(true, clone.unwrap)
        assert_equal(true, clone.format(Intent.instance(:backend)))
        assert_equal({ profile_id_is_null: true }, clone.to_hash_if_eligible)

        clone.set_from_hash({ prf_id_is_nl: false }, context: Format.instance(:frontend))
        assert_equal(false, clone.unwrap)
      end

      def test_query_is_correct
        predicate = get_predicate
        predicate.set_value true
        assert_equal '"profiles"."id" IS NULL', predicate.to_query(User.arel_table).to_sql
        predicate.set_value false
        assert_equal 'NOT ("profiles"."id" IS NULL)', predicate.to_query(User.arel_table).to_sql
      end

      def test_query_is_correct_for_computed_column
        predicate = get_predicate_for_computed_column
        predicate.set_value true
        assert_equal 'sum IS NULL', predicate.to_query(User.arel_table).to_sql
        predicate.set_value false
        assert_equal 'NOT (sum IS NULL)', predicate.to_query(User.arel_table).to_sql
      end

      def test_test_works
        u1 = User.new(id: 1, email: 'no.profile@example.com', role: 'client')
        profile = Profile.new id: 1, about: 'This is my profile'
        u2 = User.new(id: 2, email: 'with.profile@example.com', role: 'client', profile: profile)
        predicate = get_predicate
        predicate.set_value true
        assert predicate.test u1
        refute predicate.test u2
        predicate.set_value false
        refute predicate.test u1
        assert predicate.test u2
      end
    end
  end
end