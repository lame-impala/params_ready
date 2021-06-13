module ParamsReady
  module Helpers
    class InterfaceDefiner
      def initialize(action_names, user)
        @action_names = action_names
        @user = user
      end

      def use_parameters(*names)
        names.each do |name|
          use_parameter(name)
        end
      end

      def use_relations(*names)
        names.each do |name|
          use_relation(name)
        end
      end

      def use_parameter(name)
        @user.use_parameter(name, only: @action_names)
      end

      def use_relation(name)
        @user.use_relation(name, only: @action_names)
      end

      def define(&block)
        instance_eval(&block)
        @option
      end
    end
  end
end
