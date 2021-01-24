require_relative '../../lib/params_ready/helpers/key_map'
require_relative '../test_helper'

module ParamsReady
  module Helpers
    class KeyMapTest < Minitest::Test
      def alternative
        {
          data: {
            attributes: { 'product-name': 'Foo', 'product-price': 100 },
            associations: {
              'product-type': { data: { ID: 1 }}
            },
            accessories: [
              { data: { ID: 5, quantity: 2 }}
            ]
          },
          'device-uid': '6a0f9f26'
        }
      end

      def alternative_values_missing
        {
          data: {
            attributes: { 'product-name': 'Foo', 'product-price': nil },
            associations: {
              'product-type': { data: {}}
            },
            accessories: [
              { data: { ID: 5 }}
            ]
          }
        }
      end

      def string_alternative
        {
          'data' => {
            'attributes' => { 'product-name' => 'Foo', 'product-price' => 100 },
            'associations' => {
              'product-type' => { 'data' => { 'ID' => 1 }}
            },
            'accessories' => [
              { 'data' => { 'ID' => 5, 'quantity' => 2 }}
            ]
          },
          'device-uid' => '6a0f9f26'
        }
      end

      def standard
        {
          name: 'Foo',
          price: 100,
          accessory_attributes: [
            data: { ID: 5, quantity: 2 }
          ],
          product_type_id: 1,
          device_uid: '6a0f9f26'
        }
      end

      def mapping
        km = KeyMap.new
        km.map [:data, :attributes, [:'product-name', :'product-price']], to: [[:name, :price]]
        km.map [:data, [:accessories]], to: [[:accessory_attributes]]
        km.map [:data, :associations, :'product-type', :data, [:ID]], to: [[:product_type_id]]
        km.map [[:'device-uid']], to: [[:device_uid]]
      end

      def test_mapping_match_operator_works
        proto = KeyMap::Mapping.new [:A, :B], [:C, :D], [:a], [:c, :d]
        matching = KeyMap::Mapping.new [:A, :B], [:E, :F], [:a], [:e, :f]
        alt_not_matching = KeyMap::Mapping.new [:A, :G], [:C, :D], [:a], [:c, :d]
        std_not_matching = KeyMap::Mapping.new [:A, :B], [:C, :D], [:g], [:c, :d]
        assert proto =~ matching
        assert matching =~ proto
        refute proto =~ alt_not_matching
        refute alt_not_matching =~ proto
        refute proto =~ std_not_matching
        refute std_not_matching =~ proto
      end

      def test_mapping_takes_over_names_on_merge
        proto = KeyMap::Mapping.new [:A, :B], [:C, :D], [:a], [:c, :d]
        matching = KeyMap::Mapping.new [:A, :B], [:E, :F], [:a], [:e, :f]
        proto.merge!(matching)
        assert_equal [:C, :D, :E, :F], proto.send(:alt).names
        assert_equal [:c, :d, :e, :f], proto.send(:std).names
      end

      def test_mappings_are_reused_withing_key_map
        km = KeyMap.new
        km.map [:data, :attributes, [:'product-name']], to: [[:name]]
        km.map [:data, [:accessories]], to: [[:accessory_attributes]]
        km.map [:data, :attributes, [:'product-price']], to: [[:price]]
        assert_equal 2, km.instance_variable_get(:@mappings).length
        first = km.instance_variable_get(:@mappings).first
        assert_equal [:'product-name', :'product-price'], first.send(:alt).names
        assert_equal [:name, :price], first.send(:std).names
      end

      def test_to_standard_works
        km = mapping

        result = km.to_standard(alternative)
        assert_equal standard, result
      end

      def test_to_standard_works_with_string_keys
        km = mapping
        input = string_alternative
        result = km.to_standard(input)
        string_standard = standard
        string_standard[:accessory_attributes][0] = input['data']['accessories'][0]
        assert_equal string_standard, result
      end

      def test_to_standard_works_with_missing_values
        km = mapping
        input = alternative_values_missing
        result = km.to_standard(input)
        standard = { name: "Foo", price: nil, accessory_attributes: [{ data: { ID: 5 }}]}
        assert_equal standard, result
      end

      def test_last_defined_value_is_held_on_conflict
        km = KeyMap.new
        km.map [:data, [:alt_a, :alt_b, :alt_a]], to: [[:std_a, :std_a, :std_b]]
        input = { data: { alt_a: 'FOO', alt_b: 'BAR' }}
        output = km.to_standard(input)
        assert_equal({ std_a: 'BAR', std_b: 'FOO' }, output)
        assert_equal(input, km.to_alternative(output))
      end

      def test_merges_mappings_sharing_a_branch
        km = KeyMap.new
        km.map [:data, :nested_a, [:a1]], to: [:param_a, [:first]]
        km.map [:data, :nested_b, [:b1]], to: [:param_b, [:first]]
        km.map [:data, :shared, [:a2]], to: [:param_a, [:second]]
        km.map [:data, :shared, [:b2]], to: [:param_b, [:second]]
        input = { data: { nested_a: { a1: 1 }, nested_b: { b1: 3 }, shared: { a2: 2, b2: 4 }}}
        output = km.to_standard(input)
        assert_equal({ param_a: { first: 1, second: 2}, param_b: {first: 3, second: 4 }}, output)
        assert_equal(input, km.to_alternative(output))
      end

      def test_to_alternative_works
        km = mapping
        result = km.to_alternative(standard)
        assert_equal alternative, result
      end
    end
  end
end