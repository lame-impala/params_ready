require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class FormatExamples < Minitest::Test
      def test_marshal_date_only_format_works
        parameter = Builder.define_hash :parameter do
          add :integer, :integer_parameter
          add :date, :date_parameter
        end.create
        parameter[:integer_parameter] = 5
        parameter[:date_parameter] = '2020-07-20'
        expected = {
          parameter: {
            integer_parameter: 5, date_parameter: '2020-07-20'
          }
        }
        format = Format.new(
          marshal: { only: [:date] },
          omit: [],
          naming_scheme: :standard,
          remap: false,
          local: false,
          name: :test
        )
        assert_equal expected, parameter.to_hash(Intent.new(format))
      end
    end
  end
end