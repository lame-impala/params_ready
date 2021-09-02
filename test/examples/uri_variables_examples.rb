require_relative '../test_helper'
require_relative '../../lib/params_ready'

module ParamsReady
  module Examples
    class UriVariablesExamples < Minitest::Test
      def get_parameter
        definition = Builder.define_struct :parameter do
          add :struct, :users do
            add(:string, :name_match){ optional }
            add(:integer, :offset){ default 0 }
          end
          add :struct, :posts do
            add(:integer, :user_id){ optional }
            add(:string, :subject_match){ optional }
            add(:integer, :offset){ default 0 }
          end
        end

        _, parameter = definition.from_input({
          users: { name_match: 'John', offset: 20 },
          posts: { user_id: 11, subject_match: 'Question', offset: 30 }
        })
        parameter.freeze
      end

      def test_variables_for_next_page_work
        parameter = get_parameter
        next_page = parameter.update_in(40, [:posts, :offset])
        expected = {
          users: { name_match: 'John', offset: '20' },
          posts: { user_id: '11', subject_match: 'Question', offset: '40' }
        }
        assert_equal expected, next_page.for_frontend
      end

      def test_variables_for_users_page_work
        parameter = get_parameter
        expected = {
          users: { name_match: 'John', offset: '20' }
        }
        restriction = Restriction.permit(:users)
        assert_equal expected, parameter.for_frontend(restriction: restriction)
      end
    end
  end
end
