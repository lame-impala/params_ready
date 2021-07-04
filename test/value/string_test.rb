require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/value_parameter'
require_relative '../../lib/params_ready/result'

module ParamsReady
  class StringParameterTest < MiniTest::Test
    def get_def(default: Extensions::Undefined, optional: false)
      Builder.define_string :string, altn: :str do
        constrain :enum, %w(either or)
        default(default) unless default == Extensions::Undefined
        self.optional if optional
      end
    end

    def get_param(*args, **opts)
      get_def(*args, **opts).create
    end

    def test_coerces_from_string
      sparam = get_param
      validator = Result.new(sparam.name)
      result = sparam.set_value 'either', Format.instance(:backend), validator
      assert(result.ok?)
      assert_equal('either', sparam.unwrap)
    end

    def test_does_not_allow_invalid_default
      exp = assert_raises do
        sparam = get_param default: 'bogus'
      end
      assert_equal("Invalid default: value 'bogus' not in enum", exp.message)
    end

    def test_does_not_allow_non_matching_class_default
      exp = assert_raises do
        get_param default: :either
      end
      assert_equal("Invalid default: input 'either'/Symbol (expected 'either'/String)", exp.message)
    end

    def test_sets_with_correct_value_from_hash
      d = get_def
      hash = { string: 'either', other: 'bogus' }
      _, sparam = d.from_hash(hash, context: Format.instance(:backend))
      assert_equal('either', sparam.unwrap)
    end

    def test_parameter_raises_with_incorrect_value_set_from_hash
      d = get_def
      hash = { string: 'bogus', other: 'bogus' }
      r, _ = d.from_hash(hash, context: Format.instance(:backend))

      assert_equal("value 'bogus' not in enum", r.errors['string'][0].message)
    end

    def test_raises_with_nil_value_from_hash_if_no_default_defined
      d = get_def
      hash = {other: 'bogus'}
      r, _ = d.from_hash(hash)

      assert_equal("string: value is nil", r.errors['string'][0].message)
    end

    def test_set_to_default_with_nil_value_from_hash_if_default_defined
      d = get_def default: 'or'
      hash = {other: 'bogus'}
      _, sparam = d.from_hash(hash)
      assert_equal('or', sparam.unwrap)
    end

    def test_set_to_nil_with_nil_value_from_hash_if_optional
      d = get_def optional: true
      hash = {other: 'bogus'}
      _, sparam = d.from_hash(hash)
      assert_nil(sparam.unwrap)
    end

    def test_writes_to_hash_if_eligible
      sparam = get_param
      sparam.set_value 'either'
      assert_equal({string: 'either'}, sparam.to_hash_if_eligible())
      assert_equal({str: 'either'}, sparam.to_hash_if_eligible(Intent.instance(:frontend)))
    end

    def test_writes_nil_to_hash_if_eligible_for_optional_parameter
      sparam = get_param optional: true
      sparam.set_value nil
      assert_nil(sparam.to_hash_if_eligible(Intent.instance(:minify_only)))
      assert_equal({str: nil}, sparam.to_hash_if_eligible(Intent.instance(:alternative_only)))
    end

    def test_unset_parameter_writes_nil_to_hash_if_eligible_for_default_having_parameter
      sparam = get_param default: 'or'
      assert_nil(sparam.to_hash_if_eligible(Intent.instance(:minify_only)))
    end

    def test_unset_parameter_writes_default_to_hash_with_always_flag
      sparam = get_param default: 'or'
      assert_equal({string: 'or'}, sparam.to_hash_if_eligible(Intent.instance(:backend)))
    end

    def test_raises_on_write_if_obligatory_is_unset
      sparam = get_param
      exc = assert_raises do
        sparam.to_hash_if_eligible
      end
      assert_equal('string: value is nil', exc.message)
    end
  end
end