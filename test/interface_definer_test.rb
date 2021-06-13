require_relative 'params_ready_test_helper'

class BlockDefinitionController
  include ParamsReady::ParameterUser
  include_parameters A
  include_relations A

  use_relation :users
  use_parameter :number

  action_interface(:create, :update) do
    parameter :complex
  end

  action_interface(:index) do
    parameter :string
    relation :posts
  end

  action_interface(:mass) do
    parameters :string, :complex
    relations :posts
  end
end

class NamedArgumentsDefinitionController
  include ParamsReady::ParameterUser
  include_parameters A
  include_relations A

  use_relation :users
  use_parameter :number

  action_interface(:create, :update, parameter: :complex)
  action_interface(:index, parameter: :string, relation: :posts)
  action_interface(:mass, parameter: :string, parameters: [:complex], relations: [:posts])
end

class InterfaceDefinerTest < Minitest::Test
  def test_usage_rules_are_created_using_block
    assert_named_arguments(BlockDefinitionController)
  end

  def test_usage_rules_are_created_using_named_arguments
    assert_named_arguments(NamedArgumentsDefinitionController)
  end

  def assert_named_arguments(controller)
    opt = controller.params_ready_storage
    p_rules = opt.parameter_rules
    assert_equal [:number, :complex, :string], p_rules.keys
    assert_equal :all, p_rules.values[0].rule.mode
    assert_equal :only, p_rules.values[1].rule.mode
    assert_equal [:mass, :create, :update], p_rules.values[1].rule.values.to_a
    assert_equal :only, p_rules.values[2].rule.mode
    assert_equal [:mass, :index], p_rules.values[2].rule.values.to_a
    r_rules = opt.relation_rules
    assert_equal [:users, :posts], r_rules.keys
    assert_equal :all, r_rules.values[0].rule.mode
    assert_equal :only, r_rules.values[1].rule.mode
    assert_equal [:mass, :index], r_rules.values[1].rule.values.to_a
  end
end
