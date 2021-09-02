require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/struct_parameter'
require_relative '../../lib/params_ready/input_context'

module ParamsReady
  module Parameter
    class BehaviourWithAttributesIntent < Minitest::Test
      def test_nil_values_are_not_omitted_if_default_is_nil
        d = Builder.define_struct(:parameter, altn: :parameter) do
          add(:string, :detail) do
            default 'N/A'
          end
          add(:string, :name) do
            default nil
          end
        end

        _, p = d.from_hash nil
        assert_equal({ detail: 'N/A', name: nil }, p.for_model)
      end

      def test_undefined_values_are_omitted_from_attributes
        d = get_complex_param_definition
        _, p = d.from_hash(nil)
        assert_equal({}, p.for_model)

        exp = { detail: 'Info' }
        format = Format.instance(:backend)
        _, p = d.from_hash({ parameter: exp }, context: format)
        assert_equal exp, p.for_model

        exp[:roles] = [1, 2, 4]
        _, p = d.from_hash({ parameter: exp }, context: format)
        assert_equal exp, p.for_model

        exp[:actions] = { view: true }
        _, p = d.from_hash({ parameter: exp }, context: format)
        assert_equal exp, p.for_model

        exp[:actions][:edit] = true
        _, p = d.from_hash({ parameter: exp }, context: format)
        assert_equal exp, p.for_model

        exp[:score] = [10, 3]
        _, p = d.from_hash({ parameter: exp }, context: Format.instance(:backend))
        assert_equal exp, p.for_model

        exp[:evaluation] = { note: 'Ok'}
        _, p = d.from_hash({ parameter: exp }, context: Format.instance(:backend))
        assert_equal exp, p.for_model
      end

      def test_nil_values_are_not_omitted_from_attributes
        d = get_complex_param_definition
        _, p = d.from_hash(nil)
        assert_equal({}, p.for_model)

        exp = {
          detail: nil,
          roles: nil,
          actions: { view: true, edit: nil },
          score: nil,
          evaluation: nil
        }
        _, p = d.from_hash({ parameter: exp }, context: Format.instance(:backend))
        p.to_hash_if_eligible(Intent.instance(:frontend))
        assert_equal exp, p.for_model
      end
    end

    class StructParameterForModelTest < Minitest::Test
      def get_def
        Builder.define_struct :model do
          add :string, :name
          add :integer, :role do
            default 2
            optional
          end
          add :integer, :ranking do
            optional
          end
          add :integer, :owner_id do
            default nil
          end
        end
      end

      def test_all_definite_inputs_are_used_on_create
        input = { name: 'John', role: 4, ranking: 0, owner_id: 1 }
        _, p = get_def.from_input(input)
        exp = input
        assert_equal exp, p.for_model(:create)
      end

      def test_optional_default_is_used_on_create
        input = { name: 'John', ranking: 0, owner_id: 1 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 2, ranking: 0, owner_id: 1 }
        assert_equal exp, p.for_model(:create)
      end

      def test_optional_parameter_used_on_create
        input = { name: 'John', role: 4, owner_id: 1 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 4, ranking: nil, owner_id: 1 }
        assert_equal exp, p.for_model(:create)
      end

      def test_mandatory_default_is_used_on_create
        input = { name: 'John', role: 4, ranking: 0 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 4, ranking: 0, owner_id: nil }
        assert_equal exp, p.for_model(:create)
      end

      def test_all_definite_inputs_are_used_on_update
        input = { name: 'John', role: 4, ranking: 0, owner_id: nil }
        _, p = get_def.from_input(input)
        exp = input
        assert_equal exp, p.for_model(:update)
      end

      def test_optional_default_is_not_used_on_update
        input = { name: 'John', ranking: 0, owner_id: 2 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', ranking: 0, owner_id: 2 }
        assert_equal exp, p.for_model(:update)
      end

      def test_optional_parameter_is_not_used_on_update
        input = { name: 'John', role: 4, owner_id: 2 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 4, owner_id: 2 }
        assert_equal exp, p.for_model(:update)
      end

      def test_mandatory_default_is_used_on_update
        input = { name: 'John', role: 4, ranking: 0 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 4, ranking: 0, owner_id: nil }
        assert_equal exp, p.for_model(:update)
      end
    end
  end
end