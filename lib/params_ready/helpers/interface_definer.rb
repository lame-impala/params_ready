module ParamsReady
  module Helpers
    class InterfaceDefiner
      def initialize(action_names, user)
        @action_names = action_names
        @user = user
      end

      def parameters(*names)
        names.each do |name|
          parameter(name)
        end
      end

      def relations(*names)
        names.each do |name|
          relation(name)
        end
      end

      def parameter(name)
        @user.use_parameter(name, only: @action_names)
      end

      def relation(name)
        @user.use_relation(name, only: @action_names)
      end

      def define(parameter: nil, relation: nil, parameters: [], relations: [], &block)
        parameters = self.class.complete_list(parameter, parameters)
        parameters(*parameters)
        relations = self.class.complete_list(relation, relations)
        relations(*relations)
        instance_eval(&block) unless block.nil?
        @option
      end

      def self.complete_list(singular, plural)
        list = singular.nil? ? plural : [singular, *plural]
        normalize_list(list)
      end

      def self.normalize_list(list)
        list.map(&:to_sym)
      end
    end
  end
end
