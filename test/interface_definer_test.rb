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

class SuperController
  include ParamsReady::ParameterUser
  include_parameters A
  include_relations A

  use_relation :users
  use_parameter :number

  action_interface(:update) do
    parameter :complex
  end

  action_interface(:index) do
    relation :posts
  end

  action_interface(:mass) do
    parameters :string
    relations :posts
  end
end

class SubController < SuperController
  action_interface(:create, parameter: :complex)
  action_interface(:index, parameter: :string)
  action_interface(:mass, parameter: :complex)
end

class InterfaceDefinerTest < Minitest::Test
  def test_usage_rules_are_inherited
    assert_rules(SubController)
  end

  def test_parameters_for_actions_are_memoized
    opt = SubController.params_ready_option.dup
    memo = opt.instance_variable_get(:@memo)
    assert_nil memo[:parameters][:index]
    pp = opt.parameter_definitions_for(:index)
    assert_equal pp, memo[:parameters][:index]
  end

  def test_relations_for_actions_are_memoized
    opt = SubController.params_ready_option.dup
    memo = opt.instance_variable_get(:@memo)
    assert_nil memo[:parameters][:index]
    rr = opt.relation_definitions_for(:index)
    assert_equal rr, memo[:relations][:index]
  end

  def test_action_memo_reset_when_parameter_rule_added
    opt = SubController.params_ready_option.dup
    memo = opt.instance_variable_get(:@memo)
    memo[:relations][:index] = :BOO
    relation = Minitest::Mock.new
    relation.expect(:name, :subscriptions)
    relation.expect(:name, :subscriptions)
    opt.use_relation relation
    assert_nil memo[:relations][:index]
  end

  def test_action_memo_reset_when_relation_rule_added
    opt = SubController.params_ready_option.dup
    memo = opt.instance_variable_get(:@memo)
    memo[:parameters][:index] = :BOO
    parameter = Minitest::Mock.new
    parameter.expect(:name, :other)
    parameter.expect(:name, :other)
    opt.use_parameter parameter
    assert_nil memo[:parameters][:index]
  end

  def test_usage_rules_are_created_using_block
    assert_rules(BlockDefinitionController)
  end

  def test_usage_rules_are_created_using_named_arguments
    assert_rules(NamedArgumentsDefinitionController)
  end

  def assert_rules(controller)
    opt = controller.params_ready_option
    p_rules = opt.parameter_rules
    assert_equal [:number, :complex, :string].to_set, p_rules.keys.to_set
    assert_equal :all, p_rules.values[0].rule.mode
    assert_equal :only, p_rules.values[1].rule.mode
    assert_equal [:mass, :create, :update].to_set, p_rules.values[1].rule.values.to_set
    assert_equal :only, p_rules.values[2].rule.mode
    assert_equal [:mass, :index].to_set, p_rules.values[2].rule.values.to_set
    r_rules = opt.relation_rules
    assert_equal [:users, :posts].to_set, r_rules.keys.to_set
    assert_equal :all, r_rules.values[0].rule.mode
    assert_equal :only, r_rules.values[1].rule.mode
    assert_equal [:mass, :index].to_set, r_rules.values[1].rule.values.to_set
  end
end
