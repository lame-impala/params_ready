require_relative 'interface_definer'

module ParamsReady
  module Helpers
    module ParameterUserClassMethods
      def params_ready_storage
        @params_ready_storage ||= ParamsReady::Helpers::Options.new
      end

      def use_parameter(name, rule = :all)
        parameter = parameter_definition name
        params_ready_storage.use_parameter parameter, rule
      end

      def use_relation(name, rule = :all)
        relation = relation_definition name
        params_ready_storage.use_relation relation, rule
      end

      def action_interface(*action_names, &block)
        definer = InterfaceDefiner.new(action_names, self)
        definer.define(&block)
      end
    end
  end
end
