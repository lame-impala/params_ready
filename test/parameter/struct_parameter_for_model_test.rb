require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/struct_parameter'
require_relative '../../lib/params_ready/input_context'

module ParamsReady
  module Parameter
    module ForModelTest
      def assert_equal_for_unfrozen_duplicate_and_frozen(expected, parameter, &block)
        assert_equal expected, block.call(parameter), 'Unfrozen'
        assert_equal expected, block.call(parameter.freeze), 'Frozen'
        assert_equal expected, block.call(parameter.dup), 'Duplicate'
        assert_equal expected, block.call(parameter.dup.freeze), 'Frozen duplicate'
      end

      def assert_for_model_equal(expected, parameter, format: :update)
        assert_equal_for_unfrozen_duplicate_and_frozen(expected, parameter) do |text_object|
          text_object.for_model format
        end
      end
    end

    class BehaviourWithAttributesIntent < Minitest::Test
      include ForModelTest

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
        assert_for_model_equal({ detail: 'N/A', name: nil }, p)
      end

      def test_undefined_values_are_omitted_from_attributes
        d = get_complex_param_definition
        _, p = d.from_hash(nil)
        assert_for_model_equal({}, p)

        exp = { detail: 'Info' }
        format = Format.instance(:backend)
        _, p = d.from_hash({ parameter: exp }, context: format)
        assert_for_model_equal exp, p

        exp[:roles] = [1, 2, 4]
        _, p = d.from_hash({ parameter: exp }, context: format)
        assert_for_model_equal exp, p

        exp[:actions] = { view: true }
        _, p = d.from_hash({ parameter: exp }, context: format)
        assert_for_model_equal exp, p

        exp[:actions][:edit] = true
        _, p = d.from_hash({ parameter: exp }, context: format)
        assert_for_model_equal exp, p

        exp[:score] = [10, 3]
        _, p = d.from_hash({ parameter: exp }, context: Format.instance(:backend))
        assert_for_model_equal exp, p

        exp[:evaluation] = { note: 'Ok'}
        _, p = d.from_hash({ parameter: exp }, context: Format.instance(:backend))
        assert_for_model_equal exp, p
      end

      def test_nil_values_are_not_omitted_from_attributes
        d = get_complex_param_definition
        _, p = d.from_hash(nil)
        assert_for_model_equal({}, p)

        exp = {
          detail: nil,
          roles: nil,
          actions: { view: true, edit: nil },
          score: nil,
          evaluation: nil
        }
        _, p = d.from_hash({ parameter: exp }, context: Format.instance(:backend))
        assert_for_model_equal exp, p
      end
    end

    class StructParameterForModelTest < Minitest::Test
      include ForModelTest

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
        assert_for_model_equal exp, p, format: :create
      end

      def test_optional_default_is_used_on_create
        input = { name: 'John', ranking: 0, owner_id: 1 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 2, ranking: 0, owner_id: 1 }
        assert_for_model_equal exp, p, format: :create
      end

      def test_optional_parameter_used_on_create
        input = { name: 'John', role: 4, owner_id: 1 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 4, ranking: nil, owner_id: 1 }
        assert_for_model_equal exp, p, format: :create
      end

      def test_mandatory_default_is_used_on_create
        input = { name: 'John', role: 4, ranking: 0 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 4, ranking: 0, owner_id: nil }
        assert_for_model_equal exp, p, format: :create
      end

      def test_all_definite_inputs_are_used_on_update
        input = { name: 'John', role: 4, ranking: 0, owner_id: nil }
        _, p = get_def.from_input(input)
        exp = input
        assert_for_model_equal exp, p, format: :update
      end

      def test_optional_default_is_not_used_on_update
        input = { name: 'John', ranking: 0, owner_id: 2 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', ranking: 0, owner_id: 2 }
        assert_for_model_equal exp, p, format: :update
      end

      def test_optional_parameter_is_not_used_on_update
        input = { name: 'John', role: 4, owner_id: 2 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 4, owner_id: 2 }
        assert_for_model_equal exp, p, format: :update
      end

      def test_mandatory_default_is_used_on_update
        input = { name: 'John', role: 4, ranking: 0 }
        _, p = get_def.from_input(input)
        exp = { name: 'John', role: 4, ranking: 0, owner_id: nil }
        assert_for_model_equal exp, p, format: :update
      end
    end
  end
end