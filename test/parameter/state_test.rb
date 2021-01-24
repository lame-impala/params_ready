require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/state'
require_relative '../params_ready_test_helper'

module ParamsReady
  module Parameter
    class StateTest < Minitest::Test
      def get_def
        relation = S.relation_definition :users
        parameter = S.parameter_definition :string

        b = StateBuilder.instance
        b.relation relation
        b.add parameter
        b.build
      end

      def input
        {
          usr: {
            pgn: '50-10',
            ord: 'email-desc',
            str: 'real',
            num: 7
          },
          str: 'virtual'
        }
      end

      def test_definition_works
        d = get_def
        assert d.has_child? :users
        assert d.has_child? :string
        assert d.relations.member? :users
        assert d.instance_variable_get(:@relations).frozen?
      end

      def test_update_in_works
        d = get_def
        _, p = d.from_input(input)
        u = p.update_in('bogus', [:users, :string])
        assert_equal 'bogus', u[:users][:string].unwrap
        assert_equal 'real', p[:users][:string].unwrap
      end
    end
  end
end
