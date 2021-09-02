require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class StructExamples < Minitest::Test
      def test_example_hash_definition_using_convenience_methods_is_legal
        definition = Builder.define_hash :parameter do
          add(:boolean, :checked) do
            default false
          end
          add(:string, :search) do
            optional
          end
          add(:integer, :detail)
          optional
        end
        _, param = definition.from_hash({ parameter: { detail: 5 }})
        assert param[:checked].default_defined?
        assert param[:search].optional?
        assert_equal 5, param[:detail].unwrap
      end

      def test_example_hash_definition_using_ready_made_definition_is_legal
        checked = Builder.define_boolean :checked do
          default true
        end
        search = Builder.define_string :search do
          optional
        end

        parameter = Builder.define_hash(:action) do
          add checked
          add search
        end.create

        parameter[:search] = 'foo'
        assert_equal 'foo', parameter[:search].unwrap
        assert_equal({ checked: true, search: 'foo' }, parameter.unwrap)
      end

      def test_inferred_default_works
        parameter = Builder.define_hash :parameter do
          add :integer, :int do
            default 5
          end
          add :string, :str do
            optional
          end
          default :inferred
        end.create

        assert_equal({ parameter: { int: 5, str: nil }}, parameter.to_hash(:backend))
      end

      def test_base64_marshaller_works
        definition = Builder.define_hash :parameter do
          add :integer, :int
          add :string, :str
          marshal using: :base64
        end

        _, parameter = definition.from_input({ int: 1, str: 'foo' }, context: :backend)

        base64 = 'eyJpbnQiOiIxIiwic3RyIjoiZm9vIn0='
        assert_equal base64, parameter.for_output(:frontend)
        assert_equal parameter, definition.from_input(base64)[1]
      end
    end
  end
end

