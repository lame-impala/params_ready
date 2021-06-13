require_relative 'interface_definer'

module ParamsReady
  module Helpers
    module ParameterUserClassMethods
      def params_ready_option
        @params_ready_option ||= begin
          if superclass.respond_to? :params_ready_storage
            # This works on assumption that superclass
            # definition doesn't change during execution
            superclass.params_ready_option.dup
          else
            ParamsReady::Helpers::Options.new
          end
        end
      end

      def use_parameter(name, rule = :all)
        parameter = parameter_definition name
        params_ready_option.use_parameter parameter, rule
      end

      def use_relation(name, rule = :all)
        relation = relation_definition name
        params_ready_option.use_relation relation, rule
      end

      def action_interface(*action_names, **opts, &block)
        definer = InterfaceDefiner.new(action_names, self)

        definer.define(**opts, &block)
      end
    end
  end
end
