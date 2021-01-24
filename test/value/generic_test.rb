require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/value_parameter'

module ParamsReady
  module Value
    class GenericTest < Minitest::Test
      def test_generic_coder_can_be_defined
        d = Builder.define_value :object do
          coerce do |v, _|
            DummyObject.new(v)
          end

          format do |v, _|
            v.format
          end
        end

        input = { object: 'FOO' }
        _, p = d.from_hash(input)
        assert_equal "Wrapped value: 'FOO'", p.unwrap.say
        hash = p.to_hash(:frontend)
        exp = { object: 'FOO' }
        assert_equal exp, hash
      end

      def test_requires_strict_default
        err = assert_raises do
          Builder.define_value :object do
            coerce do |v, _|
              DummyObject.new(v)
            end

            format do |v, _|
              v.format
            end
            default 'FOO'
          end
        end
        exp = "Invalid default: input 'FOO' (String) coerced to 'DummyObject(FOO)' (DummyObject)"
        assert_equal exp, err.message
      end

      def test_strict_default_accepted
        p = Builder.define_value :object do
          coerce do |v, _|
            next v if v.is_a? DummyObject

            DummyObject.new(v)
          end

          format do |v, _|
            v.format
          end
          default DummyObject.new('FOO')
        end.create

        assert_equal 'FOO', p.unwrap.format
      end

      def test_raises_coercion_error_if_coercion_fails
        p = Builder.define_value :object do
          coerce do |v, _|
            raise 'BOO'
          end

          format do |v, _|
            v.format
          end
        end.create

        err = assert_raises(CoercionError) do
          p.set_value :anything
        end

        assert_equal "can't coerce 'anything' into object", err.message
      end

      def test_uses_default_type_identifier_if_unset
        _, p = Builder.define_value :object do
          coerce do |v, _|
            next v if v.is_a? DummyObject

            DummyObject.new(v)
          end

          format do |v, _|
            v.format
          end
        end.from_input 'FOO'

        f = Format.new(marshal: { only: [:value] }, naming_scheme: :standard, remap: :false, omit: [], local: false)
        assert_equal 'FOO', p.format(f)
      end

      def test_uses_type_identifier_if_set
        _, p = Builder.define_value :object do
          coerce do |v, _|
            next v if v.is_a? DummyObject

            DummyObject.new(v)
          end

          format do |v, _|
            v.format
          end

          type_identifier :dummy
        end.from_input 'FOO'

        f = Format.new(marshal: { only: [:dummy] }, naming_scheme: :standard, remap: :false, omit: [], local: false)
        assert_equal 'FOO', p.format(f)
      end
    end
  end
end
