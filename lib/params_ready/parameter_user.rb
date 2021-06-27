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

    def populate_state_for(key, params, context = Format.instance(:frontend), validator = nil)
      definition = create_state_for key
      result, state = definition.from_input(params || {}, context: context, validator: validator || Result.new(:params_ready))
      [result, state]
    end

    def create_state_for(key)
      self.class.params_ready_option.create_state_for(key)
    end
  end
end
