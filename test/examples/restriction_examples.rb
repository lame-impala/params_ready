require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class RestrictionExamples < Minitest::Test
      def test_restriction_example_works
        definition = Builder.define_hash :parameter do
          add :string, :allowed
          add :integer, :disallowed
          add :hash, :allowed_as_a_whole do
            add :integer, :allowed_by_inclusion
          end
          add :hash, :partially_allowed do
            add :integer, :allowed
            add :integer, :disallowed
          end
        end

        input = {
          allowed: 'FOO',
          disallowed: 5,
          allowed_as_a_whole: {
            allowed_by_inclusion: 8
          },
          partially_allowed: {
            allowed: 10,
            disallowed: 13
          }
        }

        result, parameter = definition.from_input(input)

        format = Format.instance :backend

        expected = {
          allowed: 'FOO',
          allowed_as_a_whole: {
            allowed_by_inclusion: 8
          },
          partially_allowed: {
            allowed: 10
          }
        }

        restriction = Restriction.permit :allowed, :allowed_as_a_whole, partially_allowed: [:allowed]
        output = parameter.for_output(format, restriction: restriction)
        assert_equal expected, output

        restriction = Restriction.prohibit :disallowed, partially_allowed: [:disallowed]
        output = parameter.for_output(format, restriction: restriction)
        assert_equal expected, output
      end

      def test_restriction_with_array_example_works
        definition = Builder.define_hash :parameter do
          add :array, :partially_allowed do
            prototype :hash, :allowed_along_with_parent do
              add :string, :explicitly_allowed
              add :integer, :disallowed_by_omission
            end
          end
        end

        input = {
          parameter: {
            partially_allowed: [
              {
                explicitly_allowed: 'FOO',
                disallowed_by_omission: 5
              }
            ]
          }
        }
        _, parameter = definition.from_hash(input)
        format = Format.instance :backend

        expected = {
          partially_allowed: [
            { explicitly_allowed: 'FOO' }
          ]
        }

        restriction = Restriction.permit partially_allowed: [:explicitly_allowed]

        output = parameter.for_output(format, restriction: restriction)
        assert_equal expected, output

        restriction = Restriction.prohibit partially_allowed: [:disallowed_by_omission]
        output = parameter.for_output(format, restriction: restriction)
        assert_equal expected, output
      end
    end
  end
end
