require_relative 'params_ready_test_helper'

class ParamDefinitionsInheritanceTest < Minitest::Test
  def test_param_inheritance_works
    c = C.new
    u = CU.new

    [c, u].each do |instance|
      assert_equal(:C, instance.class.parameter_definition(:para).altn)
      assert_equal(:X, instance.class.parameter_definition(:parb).altn)
      err = assert_raises do
        instance.class.parameter_definition(:parc)
      end
      assert_equal "Unknown parameter 'parc'", err.message
    end

    b = B.new
    assert_equal(:B, b.class.parameter_definition('para').altn)
    assert_equal(:X, b.class.parameter_definition(:parb).altn)

    a = A.new
    assert_equal(:A, a.class.parameter_definition(:para).altn)
    assert_equal(:X, a.class.parameter_definition('parb').altn)
  end
end

class PickyUser
  include ParamsReady::ParameterUser
  include ParamsReady::ParameterDefiner

  include_parameters(A, only: [:string])
  include_relations(A, only: [:users])
end

class GreedyUser
  include ParamsReady::ParameterUser
  include ParamsReady::ParameterDefiner

  include_parameters(A, except: [:string])
  include_relations(A, except: [:users])
end

class ParameterUserTest < Minitest::Test
  def with_users(*user_classes)
    user_classes.each do |user_class|
      user = user_class.new
      yield user
    end
  end

  def input_hash
    {
      A: true,
      X: false,
      usr: {
        pgn: '50-10',
        ord: 'email-desc',
        str: 'real',
        num: 7
      }
    }
  end

  def assert_contents_frozen(prms)
    hash = prms.instance_variable_get :@value
    assert hash.frozen?, "Hash expected to be frozen"
    hash.each_value do |child|
      assert_param_frozen(child)
    end
  end

  def assert_param_frozen(prm)
    assert prm.frozen?, "Not frozen: #{prm.name}"
    return unless prm.is_a? ParamsReady::Parameter::AbstractHashParameter

    prm.names.keys.each do |name|
      child = prm[name]
      assert_param_frozen(child)
    end
  end

  def refute_param_frozen(prm)
    refute prm.frozen?, "Frozen: #{prm.name}"
    return unless prm.is_a? ParamsReady::Parameter::AbstractHashParameter

    prm.names.keys.each do |name|
      child = prm[name]
      refute_param_frozen(child)
    end
  end

  def test_parameters_included_with_only_rule
    assert_equal [:string], PickyUser.all_parameters.keys
  end

  def test_relations_included_with_only_rule
    assert_equal [:users], PickyUser.all_relations.keys
  end

  def test_parameters_included_with_except_rule
    assert_equal [:para, :parb, :complex, :number], GreedyUser.all_parameters.keys
  end

  def test_relations_included_with_except_rule
    assert_equal [:posts], GreedyUser.all_relations.keys
  end

  def test_parameters_retrieved_correctly_for_single_relation
    with_users(A, AU) do |user|
      _, state = user.send :populate_state_for, :not_bogus, {
        usr: {
          eml_lk: 'Stuff',
          pgn: '2-50'
        }
      }
      exp = {
        usr: {
          eml_lk: 'Stuff',
          pgn: '2-50'
        }
      }
      hash = state.relation(:users).to_hash(ParamsReady::Format.instance(:frontend))
      assert_equal exp, hash
    end
  end

  def test_use_param_works
    with_users(A, AU) do |user|
      _, state = user.send :populate_state_for, :bogus, { A: true }

      param = state[:para]
      assert_equal(true, param.unwrap)
      param = state[:parb]
      assert_equal(true, param.unwrap)

      assert_equal({ '': { A: 'true' }}, state.page.to_hash_if_eligible(ParamsReady::Intent.instance(:frontend)))
    end
  end

  def test_ordering_works
    user = A.new
    _, prms = user.send :populate_state_for, :ordering, { A: true }
    prms.freeze
    ord = prms.ordering :users
    assert_equal [[:email, :asc]], ord.to_array

    new_state = prms.toggled_order :users, :name
    ord = new_state[:users][:ordering]
    assert_equal 'name-asc|email-asc', ord.format(ParamsReady::Intent.instance(:marshal_only))

    hash = prms.toggle :users, :name
    assert_equal  'name-asc|email-asc', hash[:usr][:ord]

    new_state = prms.reordered :users, :name, :desc
    ord = new_state[:users][:ordering]
    assert_equal 'name-desc|email-asc', ord.format(ParamsReady::Intent.instance(:marshal_only))

    hash = prms.reorder :users, :name, :asc
    assert_equal  'name-asc|email-asc', hash[:usr][:ord]
  end

  def test_limited_at_works
    user = A.new
    _, prms = user.send :populate_state_for, :ordering, input_hash

    prms.freeze
    relimited = prms.limited_at :users, 71
    assert_equal 71, relimited[:users][:pagination].limit
  end

  def test_next_and_previous_works
    user = A.new
    _, prms = user.send :populate_state_for, :not_bogus, {:usr => {:pgn => "30-100"}}
    assert_equal 30, prms[:users][:pagination].offset
    assert prms.has_next? :users, count: 1000

    assert prms.has_page? :users, 1, count: 131
    refute prms.has_page? :users, 2, count: 131
    refute prms.has_page? :users, 1, count: 130
    assert prms.has_page? :users, -1
    refute prms.has_page? :users, -2
    nxt = prms.next_page :users, count: 1000
    assert_equal({usr: { pgn: "130-100" } }, nxt.format(ParamsReady::Intent.instance(:frontend)))

    assert prms.has_previous? :users
    pre = prms.previous_page :users

    assert_nil pre.to_hash_if_eligible(ParamsReady::Intent.instance(:frontend))

    _, prms = user.send :populate_state_for, :not_bogus, {:usr => {:pgn => "0-100"}}
    refute prms.has_previous? :users

    _, prms = user.send :populate_state_for, :not_bogus, {:usr => {:pgn => "900-100"}}
    refute prms.has_next? :users, count: 1000
  end

  def test_next_and_previous_work_with_delta
    user = A.new
    _, prms = user.send :populate_state_for, :not_bogus, {:usr => {:pgn => "101-100"}}

    assert prms.has_next? :users, 2, count: 302
    assert_equal({usr: { pgn: "301-100" } }, prms.next(:users, 2, count: 302))

    refute prms.has_next? :users, 3, count: 302
    assert_nil prms.next(:users, 2, count: 301)

    assert prms.has_previous? :users, 1
    assert_equal({usr: { pgn: "1-100" } }, prms.previous(:users, 1))

    assert prms.has_previous? :users, 2
    assert_equal([0, 100], prms.previous_page(:users, 2).for_output(:backend)[:users][:pagination])

    refute prms.has_previous? :users, 3
    assert_nil prms.previous(:users, 3)
  end

  def test_first_and_last_page_work
    user = A.new
    _, prms = user.send :populate_state_for, :not_bogus, {:usr => {:pgn => "101-100"}}
    first = prms.first(:users)
    assert_equal({}, first)
    last = prms.last(:users, count: 200)
    assert_equal '100-100', last[:usr][:pgn]
  end

  def test_from_hash_works_if_params_are_empty
    with_users(A, AU) do |user|
      _, prms = user.send :populate_state_for, :not_bogus, nil
      assert_equal false, prms[:para].unwrap
      assert_equal true, prms[:parb].unwrap
      assert_equal 'bogus', prms[:users][:string].unwrap
      assert_equal 5, prms[:users][:number].unwrap
      assert_equal 0, prms[:users][:pagination].offset
      assert_equal :email, prms[:users][:ordering][0].first.unwrap
    end
  end

  def test_from_hash_works_with_correct_values
    with_users(A, AU) do |user|
      hash = input_hash

      _, prms = user.send :populate_state_for, :not_bogus, hash
      assert_equal true, prms[:para].unwrap
      assert_equal false, prms[:parb].unwrap
      assert_equal 'real', prms[:users][:string].unwrap
      assert_equal 7, prms[:users][:number].unwrap
      assert_equal 50, prms[:users][:pagination].offset
      assert_equal :desc, prms[:users][:ordering][0].second.unwrap
    end
  end

  def test_state_can_be_decorated
    user = A.new

    hash = input_hash

    _, prms = user.send :populate_state_for, :not_bogus, hash
    d = ParamsReady::OutputParameters.decorate(prms.freeze)

    assert_equal true, d[:para].unwrap
    assert_equal false, d[:parb].unwrap
    assert_equal 'real', d[:users][:string].unwrap
    assert_equal 'real', d.relation(:users)[:string].unwrap
    assert_equal 7, d[:users][:number].unwrap
    assert_equal 50, d[:users][:pagination].offset
    assert_equal :desc, d[:users][:ordering][0].second.unwrap

    assert_equal 'usr', d[:users].scoped_name
    assert_equal 'usr', d[:users].scoped_id
    assert_equal 'usr[str]', d[:users][:string].scoped_name
    assert_equal 'usr_str', d[:users][:string].scoped_id
  end

  def test_state_can_be_cloned
    user = A.new

    hash = input_hash
    _, prms = user.send :populate_state_for, :not_bogus, hash

    clone = prms.dup
    clone[:para].set_value false
    clone[:users][:string].set_value 'virtual'
    assert_equal true, prms[:para].unwrap
    assert_equal 'real', prms[:users][:string].unwrap
  end
end
