require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/value_parameter'

module ParamsReady
  module Value
    class CustomTest < Minitest::Test
      class CustomCoder
        include Coercion

        def coerce(v, _)
          DummyObject.new(v)
        end

        def format(v, _)
          v.format
        end

        def strict_default?
          false
        end
      end

      def test_custom_coder_can_be_defined
        coder = CustomCoder.new
        d = Builder.define_value :custom, coder
        input = { custom: 'FOO' }
        _, p = d.from_hash(input)
        assert_equal "Wrapped value: 'FOO'", p.unwrap.say
        hash = p.to_hash(:frontend)
        exp = { custom: 'FOO' }
        assert_equal exp, hash
      end

      def test_strict_default_policy_can_be_relaxed
        coder = CustomCoder.new
        d = Builder.define_value :custom, coder do
          default 'BAR'
        end
        assert_equal 'BAR', d.default.format
      end
    end

    class InstantiableCoderTest < Minitest::Test
      class CoderFactory < Coder::Instantiable
        def initialize(value_class:)
          @value_class = value_class
        end

        def coerce(v, _)
          @value_class.new(v)
        end

        def format(v, _)
          v.format
        end

        def self.strict_default?
          false
        end

        type_identifier :dummy

        Parameter::ValueParameterBuilder.register_coder :instantiable, CoderFactory
      end

      def test_responds_to_value_class_name
        c = CoderFactory.new(value_class: DummyObject)
        assert_equal 'Factory', c.value_class_name
      end

      def test_works_as_a_child_in_hash_parameter
        d = Builder.define_hash :hash do
          add :instantiable, :instantiable, value_class: DummyObject
        end
        _, p = d.from_input({ instantiable: 'FOO' })
        assert_equal "Wrapped value: 'FOO'", p[:instantiable].unwrap.say
        hash = p.for_output(:frontend)
        exp = { instantiable: 'FOO' }
        assert_equal exp, hash
      end

      def test_works_as_a_prototype_in_array_parameter
        d = Builder.define_array :array do
          prototype :instantiable, value_class: DummyObject
        end
        _, p = d.from_hash({ array: ['FOO'] }, context: :frontend)
        assert_equal "Wrapped value: 'FOO'", p[0].unwrap.say
        hash = p.to_hash(:frontend)
        exp = { array: { '0' => 'FOO', 'cnt' => '1' }}
        assert_equal exp, hash
      end

      def test_type_identifier_can_be_defined
        d = Builder.define_instantiable :instantiable, value_class: DummyObject
        coder = d.instance_variable_get(:@coder)
        assert_equal :dummy, coder.type_identifier
      end

      def test_instantiable_coder_can_be_defined
        d = Builder.define_instantiable :instantiable, value_class: DummyObject

        input = { instantiable: 'FOO' }
        _, p = d.from_hash(input)
        assert_equal "Wrapped value: 'FOO'", p.unwrap.say
        hash = p.to_hash(:frontend)
        exp = { instantiable: 'FOO' }
        assert_equal exp, hash
      end

      def test_strict_default_policy_can_be_relaxed
        d = Builder.define_instantiable :instantiable, value_class: DummyObject do
          default 'FOO'
        end
        assert_equal 'FOO', d.default.format
      end
    end

    class GenericTest < Minitest::Test
      def test_generic_coder_does_not_accept_options
        err = assert_raises(ParamsReadyError) do
          d = Builder.define_value :object, option: :option
        end
        assert_equal 'Expected option hash to be empty', err.message
      end

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
        exp = "Invalid default: input 'FOO'/String (expected 'DummyObject(FOO)'/DummyObject)"
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
