require_relative 'test_helper'

class KSR
  include ParamsReady::ParameterDefiner
  include ParamsReady::ParameterUser

  define_relation :companies do
    fixed_operator_predicate :name_like, attr: :name do
      operator :like
      type :value, :string
      optional
    end

    paginate 10, 200, method: :keyset do
      key :integer, :id, :asc
    end

    order do
      column :name, :asc
    end

  end
  use_relation :companies
end

class KeysetPaginationParameterUserTest < Minitest::Test
  def get_input
    {
      companies: {
        name_like: 'FOO',
        pgn: {
          dir: 'aft',
          lmt: '10',
          ks: {
            id: '50'
          }
        }
      }
    }
  end

  def get_state
    state = KSR.new
    _, prms = state.send :populate_state_for, :any, get_input
    prms
  end

  def test_pagination_basics_work
    state = get_state
    assert_equal get_input, state.current
    first = get_input
    first[:companies].delete(:pgn)
    assert_equal first, state.first(:companies)
    last = get_input
    last[:companies][:pgn] = { dir: 'bfr', lmt: '10' }
    assert_equal last, state.last(:companies)
    limited = get_input
    limited[:companies][:pgn][:lmt] = '5'
    assert_equal limited, state.limit_at(:companies, 5)
    before = get_input
    before[:companies][:pgn][:dir] = 'bfr'
    before[:companies][:pgn][:ks] = { id: '30' }
    assert_equal before, state.before(:companies, { id: 30 })
    after = get_input
    after[:companies][:pgn][:ks] = { id: '30' }
    assert_equal after, state.after(:companies, { id: 30 })
  end
end