require_relative '../../lib/params_ready/value/custom'
require_relative '../test_helper'
require_relative '../../lib/params_ready/input_context'
require_relative '../../lib/params_ready/parameter/hash_parameter'

module ParamsReady
  module Value
    class NonEmptyStringTest < Minitest::Test
      def test_undefined_can_be_passed_in_from_coder
        d = Builder.define_hash :dump_empty do
          add :non_empty_string, :never_empty do
            optional
          end

          add :string, :can_be_empty do
            default nil
          end
        end

        input = { dump_empty: { never_empty: '' }}
        _, p = d.from_hash(input)
        attrs = p.for_model
        exp = { can_be_empty: nil }
        assert_equal exp, attrs
      end
    end

    class CheckboxBooleanParameterTest < MiniTest::Test
      def checkbox_boolean_def(default: false, optional: false)
        Builder.define_checkbox_boolean :checkbox_boolean, altn: :cbb do
          self.default(default) unless default == Extensions::Undefined
          self.optional if optional
        end
      end

      def test_formats_nil_if_nil
        d = checkbox_boolean_def(optional: true, default: Extensions::Undefined)
        _, cbparam = d.from_hash({ cbb: nil })
        assert_nil cbparam.unwrap

        assert_equal({}, cbparam.to_hash(:frontend))
        assert_equal({ checkbox_boolean: nil }, cbparam.to_hash(:marshal_only))
      end

      def test_formats_to_nil_if_false
        d = checkbox_boolean_def(default: false)
        _, cbparam = d.from_hash({ cbb: 'false' })
        assert_equal(false, cbparam.unwrap)
        assert_equal({}, cbparam.to_hash(:frontend))
        assert_equal({ checkbox_boolean: nil }, cbparam.to_hash(:marshal_only))
      end

      def test_formats_to_true_string_if_true
        d = checkbox_boolean_def
        _, cbparam = d.from_hash({ cbb: 'true' })
        assert_equal(true, cbparam.unwrap)
        assert_equal({ checkbox_boolean: 'true' }, cbparam.to_hash(:marshal_only))
      end
    end

    class DowncaseStringtParameterTest < MiniTest::Test
      def test_enforces_strict_default
        err = assert_raises do
          Builder.define_downcase_string(:email) do
            default 'UPCASE'
          end
        end
        assert_equal "Invalid default: input 'UPCASE' (String) coerced to 'upcase' (String)", err.message
      end

      def test_casts_string_to_down_case
        dcs = Builder.define_downcase_string(:email)
        hash = { email: "UPCASE@eml.cz" }
        _, p = dcs.from_hash hash
        assert_equal 'upcase@eml.cz', p.unwrap
      end
    end

    class FormattedDecimalTest < MiniTest::Test
      def test_sets_value_from_formatted_decimal
        fd = Builder.define_formatted_decimal(:price)
        hash = { price: "10 332,6" }
        _, p = fd.from_hash hash
        assert_equal '10332.6'.to_d, p.unwrap
      end

      def test_regex_works_with_european_formatting
        valid = '1 234 567,20'
        assert FormattedDecimalCoder::EU.match? valid
        refute FormattedDecimalCoder::US.match? valid
        valid = '1234567,20'
        assert FormattedDecimalCoder::EU.match? valid
        refute FormattedDecimalCoder::US.match? valid
        invalid = '1 234 56,20'
        refute FormattedDecimalCoder::EU.match? invalid
        refute FormattedDecimalCoder::US.match? invalid
        invalid = '56,200'
        refute FormattedDecimalCoder::EU.match? invalid
        refute FormattedDecimalCoder::US.match? invalid
      end

      def test_regex_works_with_us_formatting
        valid = '1,234,567.20'
        refute FormattedDecimalCoder::EU.match? valid
        assert FormattedDecimalCoder::US.match? valid
        valid = '1234567.20'
        refute FormattedDecimalCoder::EU.match? valid
        refute FormattedDecimalCoder::US.match? valid
        invalid = '1 234 56.20'
        refute FormattedDecimalCoder::EU.match? invalid
        refute FormattedDecimalCoder::US.match? invalid
      end

      TestStrings = [
        [' 987 654 321,20 ', '987654321.20'],
        [' 87 654 321,20 ', '87654321.20'],
        [' 7 654 321,20 ', '7654321.20'],
        [' 654 321,20 ', '654321.20'],
        [' 54 321,20 ', '54321.20'],
        [' 4 321,20 ', '4321.20'],
        [' 321,20 ', '321.20'],
        [' 21,20 ', '21.20'],
        [' 1,20 ', '1.20'],
        [' 987654321.20 ', '987654321.20'],
        [' 987,654,321.20 ', '987654321.20'],
        [' 87,654,321.20 ', '87654321.20'],
        [' 7,654,321.20 ', '7654321.20'],
        [' 654,321.20 ', '654321.20'],
        [' 54,321.20 ', '54321.20'],
        [' 4,321.20 ', '4321.20'],
        [' 321.20 ', '321.20'],
        [' 21.20 ', '21.20'],
        [' 1.20 ', '1.20']
      ]

      def test_coerces_from_string
        context = Format.instance(:frontend)
        TestStrings.each do |(input, expected)|
          assert_equal expected.to_d, FormattedDecimalCoder.coerce(input, context)
        end
      end
    end
  end
end