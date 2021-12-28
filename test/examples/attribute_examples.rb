require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class AttributeExamples < Minitest::Test
      def get_user_def
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

      def test_all_attributes_set_on_create_using_incomplete_input
        _, p = get_user_def.from_input({ name: 'Joe' })
        assert_equal( { name: 'Joe', role: 2, ranking: nil, owner_id: nil }, p.for_model(:create))
      end

      def test_optional_attributes_ommited_from_ouput_using_incomplete_input
        _, p = get_user_def.from_input({ name: 'Joe' })
        assert_equal( { name: 'Joe', owner_id: nil }, p.for_model(:update))
      end

      def get_local_def
        Builder.define_struct :model do
          add :string, :name
          add :integer, :owner_id do
            local; optional
            populate do |context, parameter|
              next if context[:user_id].nil?

              parameter.set_value context[:user_id]
            end
          end
        end
      end

      def test_well_defined_local_parameter_writes_to_output_if_format_is_update
        definition = get_local_def
        context = InputContext.new(:frontend, { user_id: 5 })
        _, p = definition.from_input({ name: 'Foo' }, context: context)
        assert_equal({ name: 'Foo', owner_id: 5 }, p.for_model(:update))
      end

      def test_well_defined_local_parameter_does_not_write_to_output_if_undefined
        definition = get_local_def
        context = InputContext.new(:frontend, {})
        _, p = definition.from_input({ name: 'Foo' }, context: context)
        assert_equal({ name: 'Foo'}, p.for_model(:update))
      end

      def test_string_is_converted_to_valid_array
        definition = Builder.define_struct :model do
          add :array, :to do
            prototype :string

            preprocess do |input, _context, _definition|
              next [] if input.nil?
              input.split(/[,;]/).map(&:strip).reject(&:empty?)
            end
          end
          add :string, :from
        end

        _, p = definition.from_input({ to: 'a@ex.com; b@ex.com, c@ex.com, ', from: 'd@ex.com' })
        assert_equal({to: %w[a@ex.com b@ex.com c@ex.com], from: 'd@ex.com'}, p.for_model(:create))
      end

      def test_values_are_altered_in_postprocess_block
        definition = Builder.define_struct :model do
          add :integer, :lower
          add :integer, :higher

          postprocess do |parameter, _context|
            lower = parameter[:lower].unwrap
            higher = parameter[:higher].unwrap
            return if lower < higher

            parameter[:higher] = lower
            parameter[:lower] = higher
          end
        end
        _, p = definition.from_input({ lower: 11, higher: 6 })
        assert_equal({ lower: 6, higher: 11 }, p.for_model(:create))
      end
    end
  end
end
