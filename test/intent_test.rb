require_relative 'test_helper'
require_relative '../lib/params_ready/intent'
require_relative '../lib/params_ready/parameter/value_parameter'
require_relative '../lib/params_ready/parameter/struct_parameter'

module ParamsReady
  class IntentTest < Minitest::Test
    def test_permit_returns_an_unpermitted_intent_if_restriction_empty
      intent = Intent.instance(:backend)
      permitted = intent.permit()
      assert_equal({}, permitted.restriction.restriction)
      permitted = intent.permit(*[])
      assert_equal({}, permitted.restriction.restriction)
    end

    def test_nested_parameters_unpermitted_if_empty_array_passed_in_as_list
      intent = Intent.instance(:backend)
      permitted = intent.permit(struct: [])
      param = Builder.define_struct :struct do
        add :string, :first
        add :string, :second
      end

      nested = permitted.for_children(param)
      refute(nested.name_permitted?(:first))
    end

    def test_allowlist_is_constructed_if_names_are_passed_in
      intent = Intent.instance(:backend)
      permitted = intent.permit(:first_scalar, :second_scalar, first_struct: [:first, second: [:a, :b]], second_struct: [:a, :b])
      exp = {
        first_scalar: Restriction::Everything,
        second_scalar: Restriction::Everything,
        first_struct: [:first, second: [:a, :b]],
        second_struct: [:a, :b]
      }
      assert_equal(exp, permitted.restriction.restriction)
    end

    def test_denylist_is_constructed_if_names_are_passed_in
      intent = Intent.instance(:backend)

      prohibited = intent.prohibit(:first_scalar, :second_scalar, first_struct: [:first, second: [:a, :b]], second_struct: [:a, :b])
      exp = {
        first_scalar: Restriction::Everything,
        second_scalar: Restriction::Everything,
        first_struct: [:first, second: [:a, :b]],
        second_struct: [:a, :b]
      }
      assert_equal(exp, prohibited.restriction.restriction)
    end

    def test_for_children_returns_self_if_restriction_permits_everything
      intent = Intent.instance(:backend)
      for_children = intent.for_children(DummyParam.new(:parameter, :p))
      assert_equal intent.object_id, for_children.object_id
    end

    def test_for_children_returns_all_permiting_intent_if_restriction_permits_everything
      intent = Intent.instance(:backend)
      for_children = intent.for_children(DummyParam.new(:parameter, :p))
      assert_equal intent.object_id, for_children.object_id
    end

    def test_for_children_constructs_new_intent_if_restriction_is_array
      intent = Intent.instance(:backend)
      permitted = intent.permit(:first_scalar, :second_scalar, first_hash: [:first, second: [:a, :b]], second_hash: [:a, :b])
      for_children = permitted.for_children(DummyParam.new(:first_hash, :fh))
      exp = {
        first: Restriction::Everything,
        second: [:a, :b]
      }
      assert_equal(exp, for_children.restriction.restriction)
    end

    def test_if_array_is_empty_for_a_child_its_children_are_unpermitted
      intent = Intent.instance(:backend)
      permitted = intent.permit(child: [])
      for_children = permitted.for_children(DummyParam.new(:child, :c))
      assert_equal({}, for_children.restriction.restriction)
      refute for_children.permitted? DummyParam.new(:whatever, :wtv)
    end

    def test_delegate_passes_parent_permissions_onto_a_child
      intent = Intent.instance(:backend)
      permitted = intent.permit(:first, array: [:a, :b])
      parent = DummyParam.new(:array, :arr)
      child =  DummyParam.new(:struct, :sct)
      delegated = permitted.delegate(parent, child.name)
      exp = { struct: [:a, :b] }
      assert_equal(exp, delegated.restriction.restriction)
    end

    def test_regex_as_restriction_works_for_root
      intent = Intent.instance(:backend).permit(/_id\z/)
      id = DummyParam.new(:owner_id, :oid)
      type = DummyParam.new(:owner_type, :otp)
      assert intent.permitted? id
      refute intent.permitted? type
      delegated = intent.delegate(id, type.name)
      assert_equal({ owner_type: Restriction::Everything }, delegated.restriction.restriction)
      for_children = intent.for_children(id)
      assert_equal(Restriction::Everything, for_children.restriction.restriction)
      err = assert_raises do
        intent.delegate(type, id)
      end
      assert_equal "Parameter 'owner_type' not permitted", err.message
      err = assert_raises do
        intent.for_children(type)
      end
      assert_equal "Parameter 'owner_type' not permitted", err.message
    end

    def get_json_param
      Builder.define_hash :json do
        add :integer, :integer do
          optional
        end
        add :decimal, :decimal do
          optional
        end
        add :boolean, :boolean do
          optional
        end
        add :symbol, :symbol do
          optional
        end
        add :date, :date do
          optional
        end
        add :array, :int_array do
          prototype :integer do
            optional
          end
        end
        add :array, :sym_array do
          prototype :symbol do
            optional
          end
        end
      end.create
    end

    def test_json_format_works_with_definite_value
      param = get_json_param
      param[:integer] = 5
      param[:decimal] = 5.0.to_d
      param[:boolean] = true
      param[:symbol] = :stuff
      param[:date] = Date.parse('2020-08-12')
      param[:int_array] = [1, 2]
      param[:sym_array] = [:a, :b]

      exp = {
        integer: 5,
        decimal: 5.0.to_d,
        boolean: true,
        symbol: 'stuff',
        date: '2020-08-12',
        int_array: [1, 2],
        sym_array: ['a', 'b']
      }
      intent = Intent.instance(:json)
      assert_equal exp, param.to_hash_if_eligible(intent)[:json]
    end

    def test_json_format_works_with_nil_value
      param = get_json_param
      param[:integer] = nil
      param[:decimal] = nil
      param[:boolean] = nil
      param[:symbol] = nil
      param[:date] = nil
      param[:int_array] = [nil, nil]
      param[:sym_array] = [nil, nil]

      exp = {
        integer: nil,
        decimal: nil,
        boolean: nil,
        symbol: nil,
        date: nil,
        int_array: [nil, nil],
        sym_array: [nil, nil]
      }
      intent = Intent.instance(:json)
      assert_equal exp, param.to_hash_if_eligible(intent)[:json]
    end

    def assert_intents_equal(i1, i2)
      assert_equal i1, i2, 'Intents expected to be equal'
      assert_equal i1.hash, i2.hash, 'Intent hashes expected to be equal'
      assert i1.eql?(i2), 'Intents expected to match'
      assert i2.eql?(i1), 'Intents expected to match'
    end

    def assert_intents_not_equal(i1, i2)
      assert_operator i1, :!=, i2, 'Intents expected not to be equal'
      assert_operator i1.hash, :!=, i2.hash, 'Intent hashes expected not to be equal'
      refute i1.eql?(i2), 'Intents expected not to match'
      refute i2.eql?(i1), 'Intents expected not to match'
    end

    def test_intent_equal_to_self
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      r = Restriction.prohibit(:a, b: [:c, :d])
      i = Intent.new(f, r)
      assert_intents_equal i, i
    end

    def test_intent_equal_to_clone
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      r = Restriction.prohibit(:a, b: [:c, :d])
      i1 = Intent.new(f, r)
      i2 = i1.clone restriction: r
      assert_intents_equal i1, i2
    end

    def test_intent_equal_to_identical
      f1 = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      f2 = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      r = Restriction.prohibit(:a, b: [:c, :d])
      i1 = Intent.new(f1, r)
      i2 = Intent.new(f2, r)
      assert_intents_equal i1, i2
    end

    def test_intent_not_equal_if_format_differs
      f1 = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      f2 = Format.new(marshal: { only: [:value, :number, :date] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      r = Restriction.prohibit(:a, b: [:c, :d])
      i1 = Intent.new(f1, r)
      i2 = Intent.new(f2, r)
      assert_intents_not_equal i1, i2
    end

    def test_intent_not_equal_if_restriction_differs
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      r1 = Restriction.prohibit(:a, b: [:c, :d])
      r2 = Restriction.prohibit(:a, b: [:c, :d, :e])
      i1 = Intent.new(f, r1)
      i2 = Intent.new(f, r2)
      assert_intents_not_equal i1, i2
    end

    def get_data_def
      Builder.define_hash :data do
        add :string, :key
      end
    end

    def test_intent_equal_if_data_equal
      f = Format.instance(:frontend)
      r = Restriction.prohibit(:a, b: [:c, :d])
      d = get_data_def
      _, p = d.from_input({ key: 'foo' })
      p.freeze
      i1 = Intent.new(f, r, data: p)
      i2 = Intent.new(f, r, data: p)
      assert_intents_equal i1, i2
    end

    def test_intent_not_equal_if_data_not_equal
      f = Format.instance(:frontend)
      r = Restriction.prohibit(:a, b: [:c, :d])
      d = get_data_def
      _, p1 = d.from_input({ key: 'foo' })
      p1.freeze
      _, p2 = d.from_input({ key: 'bar' })
      p2.freeze
      i1 = Intent.new(f, r, data: p1)
      i2 = Intent.new(f, r, data: p2)
      assert_intents_not_equal i1, i2
    end

    def test_data_are_passed_to_the_clone
      f = Format.instance(:frontend)
      r = Restriction.prohibit(:a, b: [:c, :d])
      d = get_data_def
      _, p = d.from_input({ key: 'foo' })
      p.freeze
      i1 = Intent.new(f, r, data: p)
      i2 = i1.clone(restriction: r)
      assert_intents_equal i1, i2
    end
  end
end
