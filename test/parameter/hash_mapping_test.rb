require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/struct_parameter'
require_relative '../../lib/params_ready/input_context'

module ParamsReady
  module Parameter
    module StructParameterNameMappingTestHelper
      def input
        {
          data: {
            attributes: {
              name: 'Foo',
              price: 100
            },
            associations: {
              'object-type': {
                data: {
                  id: 1
                }
              }
            },
            accessories: [
              {
                data: {
                  id: 5,
                  quantity: 2
                }
              }
            ]
          }
        }
      end
    end

    class StructParameterAltnMapping < Minitest::Test
      include StructParameterNameMappingTestHelper

      def get_def
        Builder.define_hash(:parameter, altn: [:parameter, :data]) do
          add :string, :name, altn: [:attributes, :name]
          add :integer, :price, altn: [:attributes, :price]
          add :integer, :object_type_id, altn: [:associations, :'object-type', :data, :id]
          add :array, :accessory_attributes, altn: :accessories do
            prototype :hash do
              add :integer, :id, altn: [:data, :id]
              add :integer, :quantity, altn: [:data, :quantity]
            end
          end
        end
      end

      def test_maps_parameters_from_input_correctly
        d = get_def
        _, p = d.from_hash({ parameter: input }, context: :json)
        assert_equal 'Foo', p[:name].unwrap
        assert_equal 100, p[:price].unwrap
        assert_equal 1, p[:object_type_id].unwrap
        assert_equal 5, p[:accessory_attributes][0][:id].unwrap
        assert_equal 2, p[:accessory_attributes][0][:quantity].unwrap
      end

      def test_remaps_frontend_output
        d = get_def
        _, p = d.from_hash({ parameter: input }, context: :json)

        assert_equal({ parameter: input }, p.to_hash(:json))
      end
    end

    class StructParameterNameMapping < Minitest::Test
      include StructParameterNameMappingTestHelper

      def get_def
        Builder.define_hash(:parameter) do
          add :string, :name
          add :integer, :price
          add :integer, :object_type_id
          add :array, :accessory_attributes do
            prototype :hash do
              add :integer, :id
              add :integer, :quantity
              map [:data, [:id, :quantity]] => [[:id, :quantity]]
            end
          end

          map [:data, :attributes, [:name, :price]] => [[:name, :price]]
          map [:data, :associations, :'object-type', :data, [:id]] => [[:object_type_id]]
          map [:data, [:accessories]] => [[:accessory_attributes]]
        end
      end

      def test_maps_parameters_from_input_correctly
        d = get_def
        _, p = d.from_input(input, context: :json)
        assert_equal 'Foo', p[:name].unwrap
        assert_equal 100, p[:price].unwrap
        assert_equal 1, p[:object_type_id].unwrap
        assert_equal 5, p[:accessory_attributes][0][:id].unwrap
        assert_equal 2, p[:accessory_attributes][0][:quantity].unwrap
      end

      def test_no_remapping_on_backend
        d = get_def
        _, p = d.from_input(input, context: :json)
        exp = {
          parameter: {
            name: 'Foo',
            price: 100,
            object_type_id: 1,
            accessory_attributes: [
              { id: 5, quantity: 2 }
            ]
          }
        }
        assert_equal exp, p.to_hash(:backend)
      end

      def test_remaps_frontend_output
        d = get_def
        _, p = d.from_input(input, context: :json)

        assert_equal({ parameter: input }, p.to_hash(:json))
      end
    end

    class StructParameterNameSharing < Minitest::Test
      def test_shared_params_are_retrieved_from_hash
        d = Builder.define_hash(:parameter) do
          add :hash, :share_a, altn: :shared do
            add :integer, :a
            add :string, :ab
            add :hash, :shared do
              add :integer, :a
              add :string, :ab
            end
          end

          add :hash, :share_b, altn: :shared do
            add :integer, :b
            add :string, :ab
            add :hash, :shared do
              add :integer, :b
              add :string, :ab
            end
          end
        end

        hash = {
          parameter: {
            shared: {
              a: '5',
              b: '19',
              ab: 'FOO',
              shared: {
                a: '10',
                b: '277',
                ab: 'BAR'
              }
            }
          }
        }

        _, p = d.from_input(hash[:parameter]).freeze
        assert_equal 5, p[:share_a][:a].unwrap
        assert_equal 'FOO', p[:share_a][:ab].unwrap
        assert_equal 10, p[:share_a][:shared][:a].unwrap
        assert_equal 'BAR', p[:share_a][:shared][:ab].unwrap

        assert_equal 19, p[:share_b][:b].unwrap
        assert_equal 'FOO', p[:share_b][:ab].unwrap
        assert_equal 277, p[:share_b][:shared][:b].unwrap
        assert_equal 'BAR', p[:share_b][:shared][:ab].unwrap

        # Shared values will be rewritten by the
        # parameter which was defined later
        p = p.update_in('BAR', [:share_a, :ab])
        p = p.update_in('FOO', [:share_a, :shared, :ab])

        assert_equal hash, p.to_hash(:frontend), "DIFF: #{hash_diff(hash, p.to_hash(:frontend))}"
      end
    end
  end
end