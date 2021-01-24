require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class AttributeExamples < Minitest::Test
      def get_local_def
        Builder.define_hash :model do
          add :integer, :owner_id do
            local; optional
            populate do |context, parameter|
              next if context[:user_id].nil?

              parameter.set_value context[:user_id]
            end
          end
          add :string, :name
        end
      end

      def test_well_defined_local_parameter_writes_to_output_if_format_is_attributes
        definition = get_local_def
        context = InputContext.new(:frontend, { user_id: 5 })
        _, p = definition.from_input({ name: 'Foo' }, context: context)
        assert_equal({ owner_id: 5, name: 'Foo'}, p.for_model)
      end

      def test_well_defined_local_parameter_does_not_write_to_output_if_undefined
        definition = get_local_def
        context = InputContext.new(:frontend, {})
        _, p = definition.from_input({ name: 'Foo' }, context: context)
        assert_equal({ name: 'Foo'}, p.for_model)
      end

      def test_string_is_converted_to_valid_array
        definition = Builder.define_hash :model do
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
        assert_equal({to: %w[a@ex.com b@ex.com c@ex.com], from: 'd@ex.com'}, p.for_model)
      end

      def test_values_are_altered_in_postprocess_block
        definition = Builder.define_hash :model do
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
        assert_equal({ lower: 6, higher: 11 }, p.for_model)
      end
    end
  end
end
