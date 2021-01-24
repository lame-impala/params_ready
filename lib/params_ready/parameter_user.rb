require_relative 'result'
require_relative 'helpers/usage_rule'
require_relative 'helpers/options'
require_relative 'helpers/parameter_user_class_methods'
require_relative 'helpers/parameter_storage_class_methods'
require_relative 'parameter/state'

module ParamsReady
  module ParameterUser
    def self.included(base)
      base.extend(Helpers::ParameterStorageClassMethods)
      base.extend(Helpers::ParameterUserClassMethods)
    end

    protected

    def parameter_definition(key)
        self.class.parameter_definition key
    end

    def relation_definition(key)
        self.class.relation_definition key
    end

    def populate_state_for(method, params, context = Format.instance(:frontend), validator = nil)
      definition = create_state_for method
      result, state = definition.from_input(params || {}, context: context, validator: validator || Result.new(:params_ready))
      [result, state]
    end

    def create_state_for(method)
      builder = Parameter::StateBuilder.instance
      options = self.class.params_ready_storage
      options.parameter_rules do |rule|
        builder.add rule.parameter_definition if rule.valid_for(method)
      end
      options.relation_rules do |rule|
        builder.relation rule.parameter_definition if rule.valid_for(method)
      end
      builder.build
    end
  end
end