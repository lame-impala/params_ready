require_relative 'params_ready_test_helper'

class InterfaceDefiningController
  include ParamsReady::ParameterUser
  include_parameters A
  include_relations A

  use_relation :users
  use_parameter :number

  action_interface(:create, :update) do
    use_parameter :complex
  end

  action_interface(:index) do
    use_parameter :string
    use_relation :posts
  end
end

class InterfaceDefinerTest < Minitest::Test
  def test_usage_rules_are_created
    opt = InterfaceDefiningController.params_ready_storage
    p_rules = opt.parameter_rules
    assert_equal [:number, :complex, :string], p_rules.keys
    assert_equal :all, p_rules.values[0].rule.mode
    assert_equal :only, p_rules.values[1].rule.mode
    assert_equal [:create, :update], p_rules.values[1].rule.values.to_a
    assert_equal :only, p_rules.values[2].rule.mode
    assert_equal [:index], p_rules.values[2].rule.values.to_a
    r_rules = opt.relation_rules
    assert_equal [:users, :posts], r_rules.keys
    assert_equal :all, r_rules.values[0].rule.mode
    assert_equal :only, r_rules.values[1].rule.mode
    assert_equal [:index], r_rules.values[1].rule.values.to_a
  end
end
