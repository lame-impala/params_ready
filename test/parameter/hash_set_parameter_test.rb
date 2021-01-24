require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/hash_set_parameter'
require_relative '../../lib/params_ready/value/custom'
require_relative '../../lib/params_ready/input_context'
require_relative '../../lib/params_ready/output_parameters'
require_relative '../../lib/params_ready/result'

module ParamsReady
  module Parameter
    module HashSetParameterTestHelper
      def get_conversion_param_definition
        Builder.define_hash_set(:conversion) do
          add(:pending, val: 0) { optional }
          add(:processing, val: 1) { optional }
          add(:complete, val: 2) { optional }
        end
      end

      def get_conversion_param
        get_conversion_param_definition.create
      end

      def get_param_definition(default: Extensions::Undefined, defaults: {}, optional: false, type: :boolean)
        d = Builder.define_hash_set(:parameter, altn: :param, type: type) do
          add(:pending, altn: :pen) do
            if defaults.key?(:pending)
              default(defaults[:pending])
            else
              optional()
            end
          end
          add(:processing, altn: :pro) do
            if defaults.key?(:processing)
              default(defaults[:processing])
            else
              optional()
            end
          end
          add(:complete, altn: :com) do
            if defaults.key?(:complete)
              default(defaults[:complete])
            else
              optional()
            end
          end
          self.default(default) unless default == Extensions::Undefined
          self.optional if optional
        end
      end

      def get_param(*args, **opts)
        get_param_definition(*args, **opts).create
      end
    end

    class HashSetConversionTest < Minitest::Test
      include HashSetParameterTestHelper

      def test_member_can_not_be_added_after_default_has_been_set
        err = assert_raises do
          Builder.define_hash_set(:faulty) do
            add(:pending, val: 0) { optional }
            default [:pending].to_set
            add(:processing, val: 1) { optional }
          end.create
        end

        assert_equal "Child can't be added after default has been set", err.message
      end

      def test_uniqueness_of_values_is_checked_for
        err = assert_raises do
          Builder.define_hash_set(:conversion) do
            add(:pending, val: 0) { optional }
            add(:processing, val: 0) { optional }
          end
        end
        assert_equal "Value '0' already taken by 'pending'", err.message
      end

      def test_conversion_from_set_works
        p = get_conversion_param
        p.set_value [1, 2].to_set
        assert_equal [1, 2].to_set, p.unwrap
      end

      def test_from_hash_works_for_conversion_parameter
        d = get_conversion_param_definition
        _, p = d.from_hash({ conversion: { pending: true, processing: true }})
        assert_equal [0, 1].to_set, p.unwrap
      end

      def test_to_hash_if_eligible_works_for_conversion_parameter
        p = get_conversion_param
        p.set_value [0, 2].to_set
        exp = { conversion: { pending: 'true', processing: 'false', complete: 'true' }}
        assert_equal exp, p.to_hash_if_eligible(Intent.instance(:frontend))
      end
    end

    class HashSetParameterTest < Minitest::Test
      include HashSetParameterTestHelper

      def test_uninitialized_hash_set_parameter_raises_when_child_queried
        p = get_param
        exc = assert_raises do
          p[:pending]
        end
        assert_equal("parameter: value is nil", exc.message)
      end

      def test_uninitialized_hash_set_parameter_returns_false_to_member?
        p = get_param
        assert_equal false, p.member?(:pending)
      end

      def test_uninitialized_hash_set_parameter_is_initialized_by_assignment
        p = get_param
        p[:pending] = true
        assert_equal(true, p[:pending].unwrap)
      end

      def test_uninitialized_optional_hash_set_parameter_returns_nil_when_child_queried
        p = get_param optional: true
        assert_nil(p[:checked])
      end

      def test_hash_set_parameter_raises_when_nonexistent_child_queried_by_member?
        p = get_param optional: true
        err = assert_raises do
          p.member? :foo
        end
        assert_equal "Key not defined: 'foo'", err.message
      end

      def test_hash_set_parameter_writes_nil_if_value_is_default
        p = get_param default: %i[pending processing].to_set
        assert_equal true, p[:pending].unwrap
        assert_equal true, p[:processing].unwrap
        assert_equal false, p[:complete].unwrap
        assert_nil(p.to_hash_if_eligible(Intent.instance(:frontend)))
      end

      def test_hash_set_parameter_writes_everything_if_value_is_default_and_default_not_omitted
        p = get_param default: %i[pending processing].to_set
        exp = {
          parameter: {
            pending: 'true',
            processing: 'true',
            complete: 'false'
          }
        }
        assert_equal(exp, p.to_hash_if_eligible(Intent.instance(:marshal_only)))
      end

      def test_hash_set_parameter_rejects_default_set_with_extra_elements
        err = assert_raises do
          get_param default: %i[bogus].to_set
        end
        assert_equal "Invalid default: extra elements found -- 'bogus'", err.message
      end

      def test_hash_set_parameter_omits_default_values_on_write_if_some_values_differ_from_default
        p = get_param defaults: { pending: false, processing: true, complete: true }
        p[:pending] = true
        p[:processing] = false
        p[:complete] = true

        assert_equal({ param: { pen: 'true', pro: 'false' }}, p.to_hash_if_eligible(Intent.instance(:frontend)))
      end

      def test_hash_set_parameter_set_to_correct_values_or_defaults_from_populated_hash
        d = get_param_definition defaults: { pending: false, processing: true, complete: true }
        h = { param: { pen: 'true', pro: 'false' }}
        _, p = d.from_hash(h)
        assert_equal true, p[:pending].unwrap
        assert_equal false, p[:processing].unwrap
        assert_equal true, p[:complete].unwrap
      end
    end

    class HashSetWithSubtypeCoder < Minitest::Test
      include HashSetParameterTestHelper

      def test_hashset_can_be_set_to_use_subtype_coder
        p = get_param type: :checkbox_boolean
        p[:pending] = true
        p[:processing] = nil
        p[:complete] = false
        assert_equal({ parameter: { pending: 'true', processing: nil, complete: nil }}, p.to_hash(:marshal_only))
      end

      def test_checkbox_boolean_hash_set_returns_nil_for_output_format_if_false
        p = get_param type: :checkbox_boolean
        p[:pending] = true
        p[:processing] = nil
        p[:complete] = false
        o = OutputParameters.new p.freeze, :frontend
        assert_equal 'true', o[:pending].format(Format.instance(:frontend))
        assert_nil o[:processing].format(Format.instance(:frontend))
        assert_nil o[:complete].format(Format.instance(:frontend))
      end
    end

    class HashSetDefaultBehaviour < Minitest::Test
      include HashSetParameterTestHelper

      def test_default_hash_set_param_writes_placeholder_if_values_eq_defaults_and_not_overall_default_and_formatting_is_frontend
        p = get_param defaults: { pending: true, processing: true, complete: false }, default: %i[pending].to_set
        p[:pending] = true
        p[:processing] = true
        p[:complete] = false
        assert_equal({param: '0'}, p.to_hash_if_eligible(Intent.instance(:frontend)))
      end

      def test_default_hash_set_param_writes_nil_if_values_eq_overall_default_and_formatting_is_frontend
        p = get_param default: %i[pending processing].to_set
        p[:pending] = true
        p[:processing] = true
        p[:complete] = false
        assert_nil p.to_hash_if_eligible(Intent.instance(:frontend))
      end

      def test_default_hash_set_param_sets_to_overall_default_if_set_from_nil
        d = get_param_definition default: %i[pending processing].to_set
        _, p = d.from_hash({ param: nil })
        assert_equal true, p[:pending].unwrap
        assert_equal true, p[:processing].unwrap
        assert_equal false, p[:complete].unwrap
      end
    end

    class HashSetRestrictionBehaviour < Minitest::Test
      include HashSetParameterTestHelper

      def test_only_allowed_values_appear_in_the_set
        p = get_param

        p[:pending] = true
        p[:processing] = true
        p[:complete] = false

        al = Restriction.permit(parameter: [:pending, :complete])
        assert_equal({ parameter: [:pending].to_set }, p.to_hash(:backend, restriction: al))
      end

      def test_only_not_prohibited_values_appear_in_the_set
        p = get_param

        p[:pending] = true
        p[:processing] = true
        p[:complete] = false

        dl = Restriction.prohibit(parameter: [:processing])
        assert_equal({ parameter: [:pending].to_set }, p.to_hash(:backend, restriction: dl))
      end
    end

    class HashSetOptionalBehaviour < Minitest::Test
      include HashSetParameterTestHelper

      def test_uninitialized_optional_hash_set_writes_hash_with_nil_value_with_backend_intent
        p = get_param optional: true
        assert_equal({ parameter: nil }, p.to_hash_if_eligible(Intent.instance(:backend)))
      end

      def test_uninitialized_optional_hash_set_writes_nil_with_frontend_intent
        p = get_param optional: true
        assert_nil p.to_hash_if_eligible(Intent.instance(:frontend))
      end

      def test_optional_hash_set_param_writes_full_set_with_minify_option_if_values_eq_defaults_and_formatting_is_backend
        p = get_param optional: true, defaults: { pending: true, processing: true, complete: true }
        p[:pending] = true
        p[:processing] = true
        p[:complete] = true
        assert_equal({ parameter: %i[pending processing complete].to_set}, p.to_hash_if_eligible(Intent.instance(:minify_only)))
      end

      def test_optional_hash_set_param_writes_placeholder_if_values_eq_defaults_and_not_overall_default_and_formatting_is_frontend
        p = get_param optional: true, defaults: { pending: true, processing: true, complete: false }
        p[:pending] = true
        p[:processing] = true
        p[:complete] = false
        assert_equal({ param: '0'}, p.to_hash_if_eligible(Intent.instance(:frontend)))
      end

      def test_optional_hash_param_writes_nil_if_not_set_and_formatting_is_frontend
        p = get_param optional: true
        assert_nil p.to_hash_if_eligible(Intent.instance(:frontend))
      end

      def test_optional_hash_set_param_sets_children_to_defaults_if_set_from_empty_hash
        d = get_param_definition defaults: { pending: true, processing: true }
        _, p = d.from_hash({ param: {}})
        assert_equal true, p[:pending].unwrap
        assert_equal true, p[:processing].unwrap
        assert_nil p[:complete].unwrap
      end

      def test_optional_hash_set_param_sets_children_to_defaults_if_set_with_placeholder
        d = get_param_definition defaults: { pending: true, processing: true }
        _, p = d.from_hash({ param: '0' })
        assert_equal true, p[:pending].unwrap
        assert_equal true, p[:processing].unwrap
        assert_nil p[:complete].unwrap
      end

      def test_optional_hash_set_param_sets_to_nil_if_set_from_nil
        d = get_param_definition optional: true
        _, p = d.from_hash({ param: nil })
        refute p.is_definite?
        assert_nil p[:pending]
        assert_nil p[:processing]
        assert_nil p[:complete]
      end

      def test_unwrap_returns_set_with_backend_names
        p = get_param
        p[:pending] = true
        p[:processing] = true
        p[:complete] = false
        s = p.unwrap
        assert_equal %i[pending processing].to_set, s
      end
    end
  end
end