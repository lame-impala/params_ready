require_relative '../test_helper'
require_relative '../../lib/params_ready/value/coder'
require_relative '../../lib/params_ready/value/custom'
require_relative '../../lib/params_ready/parameter/array_parameter'
require_relative '../../lib/params_ready/parameter/polymorph_parameter'
require_relative '../../lib/params_ready/input_context'
require_relative '../../lib/params_ready/result'
require_relative '../../lib/params_ready/output_parameters'

module ParamsReady
  module Parameter
    class ArrayParameterWithPolymorphElementTest < Minitest::Test
      def build_param
        Builder.define_array :array_parameter do
          prototype :polymorph do
            identifier :ppt
            type :integer, :first
            type :string, :second
          end
        end
      end

      def test_restriction_works_with_polymorph
        d = build_param
        _, p = d.from_hash({ array_parameter: [ { first: 5 }, { second: 'FOO' }]})

        assert_equal 5, p[0][:first].unwrap
        assert_equal 'FOO', p[1][:second].unwrap
        al = Restriction.permit(array_parameter: [:first])

        act = p.to_hash(:backend, restriction: al)
        assert_equal({ array_parameter: [{ first: 5 }, nil] }, act)

        dl = Restriction.prohibit(array_parameter: [:second])
        act = p.to_hash(:backend, restriction: dl)
        assert_equal({ array_parameter: [{ first: 5 }, nil] }, act)
      end
    end

    class ArrayParameterTest < Minitest::Test
      def build_param(proto_type:, proto_name:, proto_altn:, default: Extensions::Undefined, optional: false, compact: false, &block)
        Builder.define_array :parameter, altn: :param do
          prototype proto_type, proto_name, altn: proto_altn do
            self.instance_eval(&block) unless block.nil?
          end
          default(default) unless default == Extensions::Undefined
          self.optional if optional
          self.compact if compact
        end
      end

      def get_param(proto:, default: Extensions::Undefined, optional: false)
        Builder.define_parameter :array, :parameter, altn: :param do
          prototype proto
          default(default) unless default == Extensions::Undefined
          self.optional if optional
        end.create
      end

      def test_dummy_count_parameter_is_created_for_output
        p = Builder.define_array(:array_param) do
          prototype :integer
        end.create
        p.set_value [1, 3, 7]
        decorated = OutputParameters.decorate(p.freeze)
        assert_equal 3, decorated[:cnt].unwrap
        assert_equal 'array_param[cnt]', decorated[:cnt].scoped_name
        assert_equal 'array_param_cnt', decorated[:cnt].scoped_id
      end

      def test_default_can_not_be_set_before_prototype_has_been_defined
        err = assert_raises do
          Builder.define_array :faulty do
            default [0]
            prototype :integer
          end
        end

        assert_equal "Can't set default before prototype has been defined", err.message
      end

      def test_prototype_can_only_be_set_once
        err = assert_raises do
          Builder.define_array :faulty do
            prototype :integer
            prototype :string
          end
        end

        assert_equal "Variable 'prototype' already set", err.message
      end

      def test_to_hash_if_eligible_omits_default_values_if_intent_set_to_minify
        p = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm) do
          default 3
        end.create
        p << 1 << 3 << 2

        intent = Intent.instance(:minify_only)
        hash = p.to_hash_if_eligible(intent)
        assert_equal({ parameter: [1, nil, 2] }, hash)
      end

      def test_to_hash_if_eligible_includes_default_values_if_intent_set_not_to_minify
        p = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm) do
          default 3
        end.create
        p << 1 << 3 << 2

        intent = Intent.instance(:marshal_alternative)
        hash = p.to_hash_if_eligible(intent)
        assert_equal({ param: { '0' => '1', '1' => '3', '2' => '2', 'cnt' => '3' }}, hash)
      end

      def test_to_hash_if_eligible_returns_nil_if_value_is_default_and_intent_set_to_minify
        p = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm, default: [1, 2, 3]) do
          default 3
        end.create

        intent = Intent.instance(:minify_only)
        assert_nil(p.to_hash_if_eligible(intent))
      end

      def test_to_hash_if_eligible_writes_full_array_value_is_default_but_intent_not_set_to_minify
        p = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm, default: [1, 2, 3]) do
          default 3
        end.create

        intent = Intent.instance(:marshal_alternative)
        hash = p.to_hash_if_eligible(intent)
        assert_equal({ param: { '0' => '1', '1' => '2', '2' => '3', 'cnt' => '3' }}, hash)
      end

      def test_from_hash_raises_with_obligatory_parameter_when_hash_is_nil
        d, _ = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm) do
          default 3
        end

        hash = {}
        r, _ = d.from_hash(hash)
        assert_equal("errors for parameter -- parameter: value is nil", r.error.message)
      end

      def test_from_hash_uses_default_when_hash_is_nil
        d = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm, default: [1, 2, 3]) do
          default 3
        end
        hash = {}
        _, p = d.from_hash(hash)
        assert_equal(3, p.length)
        assert_equal(3, p[2].unwrap)
      end

      def test_from_hash_uses_element_default_when_indexes_are_missing
        d = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm, default: [1, 2, 3]) do
          default 3
        end
        hash = { param: { '1' => 0, '2' => 8, cnt: 3 }}
        _, p = d.from_hash(hash)
        assert_equal(3, p.length)
        assert_equal(3, p[0].unwrap)
        assert_equal(0, p[1].unwrap)
        assert_equal(8, p[2].unwrap)
      end

      def test_basic_array_functionality_is_delegated_to_bare_value
        p = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm) do
          default 3
        end.create
        exc = assert_raises do
          p.length
        end
        assert_equal("parameter: value is nil", exc.message)
        p.set_value [1, 2, 3]
        assert_equal(3, p.length)
        assert_equal(6, p.reduce(0) { |acc, val| acc + val.unwrap })
        hash = {}

        p.each_with_index do |elm, index|
          hash[index] = "#{elm.unwrap}"
        end
        exp = { 0 => '1', 1 => '2', 2 => '3' }
        assert_equal exp, hash
      end

      def test_generic_value_works_as_prototype
        d = Builder.define_array :array_parameter do
          prototype :value do
            coerce do |v, _|
              next v if v.is_a? DummyObject

              DummyObject.new(v)
            end

            format do |v, _|
              v.format
            end

            default DummyObject.new('FOO')
          end
        end

        _, p = d.from_hash({ array_parameter: { '0' => 'X', '2' => 'Y', 'cnt' => 3 }})
        assert_equal 3, p.length
        assert_equal 'X', p[0].unwrap.format
        assert_equal 'FOO', p[1].unwrap.format
        assert_equal 'Y', p[2].unwrap.format
      end

      def test_uninitialized_array_parameter_raises_when_element_queried
        p = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm) do
          default 3
        end.create
        exc = assert_raises do
          p[0]
        end
        assert_equal("parameter: value is nil", exc.message)
      end

      def test_array_parameter_is_initialized_on_assignment
        p = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm).create
        p << 10
        assert_equal 10, p[0].unwrap
        assert_nil p[1]
      end

      def test_uninitialized_optional_array_parameter_returns_nil_when_element_queried
        p = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm, optional: true) do
          default 3
        end.create
        assert_nil p[0]
      end

      def test_uninitialized_optional_array_parameter_returns_what_is_in_default_when_element_queried
        p = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm, default: [1, 2, 3]) do
          default 3
        end.create
        assert_equal 1, p[0].unwrap
        assert_equal 3, p[2].unwrap
        assert_nil p[3]
      end

      def test_compact_array_works_with_hash_input
        d = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm, compact: true)
        _, p = d.from_hash({ param: { '0' => 5, '99' => 8, '170' => 3}})
        assert_equal [5, 8, 3], p.unwrap
      end

      def test_compact_array_works_with_array_input
        d = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm, compact: true)
        _, p = d.from_hash({ param: [nil, 5, 8, nil, 3, nil]})
        assert_equal [5, 8, 3], p.unwrap
      end

      def test_compact_is_marshalled_to_array
        d = build_param(proto_type: :integer, proto_name: :number, proto_altn: :nm, compact: true)
        _, p = d.from_hash({ param: [1, 2, 3] })
        assert_equal({ param: %w[1 2 3]}, p.to_hash(:frontend))
      end

      def test_compact_array_filters_empty_values
        d = Builder.define_array :filtering_empty do
          prototype :non_empty_string do
            optional
          end
          compact
        end

        _, p = d.from_hash({ filtering_empty: ['a', 'b', '', nil] })

        assert_equal %w[a b], p.unwrap
      end

      def test_array_can_be_set_to_marshal_to_string
        d = Builder.define_array :stringy do
          prototype :string

          marshal using: :string, separator: '; ', split_pattern: /[,;]/
        end

        _, p = d.from_input('a; b, c')
        assert_equal %w[a b c], p.unwrap
        assert_equal 'a; b; c', p.format(Format.instance(:frontend))
      end

      def test_equals_works_with_array_parameter
        proto1 = Builder.define_integer :number, altn: :nm do
          default 3
        end
        proto2 = Builder.define_integer :number, altn: :nm do
          default 3
        end

        aparam1a = get_param proto: proto1
        aparam1b = aparam1a.dup
        aparam2 = get_param proto: proto2

        assert aparam1a.match?(aparam1b)
        refute aparam1a.match?(aparam2)
        refute aparam2.match?(aparam1b)

        refute aparam1a == aparam1b
        refute aparam1a == aparam2
        refute aparam2 == aparam1b

        aparam1a << 1 << 2
        aparam1b << 1 << 2
        aparam2 << 1 << 2

        assert aparam1a == aparam1b
        refute aparam1a == aparam2
        refute aparam2 == aparam1b

        aparam1a << 3

        refute aparam1a == aparam1b
      end
    end

    class ArrayParameterUpdateInTest < Minitest::Test
      def get_def
        Builder.define_array :updating do
          prototype :struct do
            add :integer, :detail
            add :string, :search
          end
        end
      end

      def initial_value
        { updating: [{ detail: 1, search: 'a'}, { detail: 2, search: 'b' }] }
      end

      def update_value
        [{ detail: 2, search: 'b' }, { detail: 1, search: 'c' }]
      end

      def test_update_if_applicable_works_if_called_on_unfrozen_self
        d = get_def
        _, p = d.from_hash(initial_value)

        changed, u = p.update_if_applicable(update_value, [])
        assert changed
        assert_equal({ detail: 2, search: 'b'}, u[0].unwrap)
        assert_equal({ detail: 1, search: 'c'}, u[1].unwrap)
        assert_different u, p
        refute u.frozen?
        refute u[0].frozen?
        refute u[1].frozen?
      end

      def test_update_if_applicable_works_if_called_on_frozen_self
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable(update_value, [])
        assert changed
        assert_equal({ detail: 2, search: 'b'}, u[0].unwrap)
        assert_equal({ detail: 1, search: 'c'}, u[1].unwrap)
        assert_different u, p
        assert_different u[0], p[0]
        assert_different u[1], p[1]

        assert u.frozen?
        assert u[0].frozen?
        assert u[1].frozen?
      end

      def test_update_if_applicable_works_if_called_on_complex_child_of_unfrozen_parameter
        d = get_def
        _, p = d.from_hash(initial_value)

        changed, u = p.update_if_applicable(update_value[0], [0])
        assert changed
        assert_equal({ detail: 2, search: 'b'}, u[0].unwrap)
        assert_equal({ detail: 2, search: 'b'}, u[1].unwrap)
        assert_different u, p
        assert_different u[0], p[0]
        assert_different u[1], p[1]
        refute u.frozen?
        refute u[0].frozen?
        refute u[1].frozen?
      end

      def test_update_if_applicable_works_if_called_on_complex_child_of_unfrozen_parameter_with_different_value
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable(update_value[0], [0])
        assert changed
        assert_equal({ detail: 2, search: 'b'}, u[0].unwrap)
        assert_equal({ detail: 2, search: 'b'}, u[1].unwrap)
        assert_different u, p
        assert_different u[0], p[0]
        assert_same u[1], p[1]
        assert u.frozen?
        assert u[0].frozen?
        assert u[1].frozen?
      end

      def test_update_if_applicable_works_if_called_on_complex_child_of_unfrozen_parameter_with_same_value
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable(initial_value[:updating][0], [0])
        assert changed
        assert_equal({ detail: 1, search: 'a'}, u[0].unwrap)
        assert_equal({ detail: 2, search: 'b'}, u[1].unwrap)
        refute_same u, p
        refute_same u[0], p[0]
        assert_same u[1], p[1]
        assert u.frozen?
        assert u[0].frozen?
        assert u[1].frozen?
      end

      def test_update_if_applicable_works_if_called_on_atomic_descendant_of_unfrozen_parameter_with_different_value
        d = get_def
        _, p = d.from_hash(initial_value)

        changed, u = p.update_if_applicable(10, [0, :detail])
        assert changed
        assert_equal({ detail: 10, search: 'a'}, u[0].unwrap)
        assert_equal({ detail: 2, search: 'b'}, u[1].unwrap)
        refute_same u, p
        refute_same u[0], p[0]
        refute_same u[1], p[1]
        refute u.frozen?
        refute u[0].frozen?
        refute u[1].frozen?
      end

      def test_update_if_applicable_works_if_called_on_atomic_descendant_of_frozen_parameter_with_different_value
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable(10, [0, :detail])
        assert changed
        assert_equal({ detail: 10, search: 'a'}, u[0].unwrap)
        assert_equal({ detail: 2, search: 'b'}, u[1].unwrap)
        refute_same u, p
        refute_same u[0], p[0]
        refute_same u[0][:detail], p[0][:detail]
        assert_same u[0][:search], p[0][:search]
        assert_same u[1], p[1]
        assert u.frozen?
        assert u[0].frozen?
        assert u[1].frozen?
      end

      def test_update_if_applicable_works_if_called_on_atomic_descendant_of_frozen_parameter_with_same_value
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable(1, [0, :detail])
        refute changed
        assert_equal({ detail: 1, search: 'a'}, u[0].unwrap)
        assert_equal({ detail: 2, search: 'b'}, u[1].unwrap)
        assert_same u, p
        assert_same u[0], p[0]
        assert_same u[0][:detail], p[0][:detail]
        assert_same u[0][:search], p[0][:search]
        assert_same u[1], p[1]
        assert u.frozen?
        assert u[0].frozen?
        assert u[1].frozen?
      end
    end
  end
end
