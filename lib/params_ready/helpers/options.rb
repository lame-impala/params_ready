require_relative 'storage'
require_relative 'usage_rule'

module ParamsReady
  module Helpers
    class Options < Storage
      attr_reader :parameters, :relations

      def initialize
        super
        @parameter_rules = Hash.new
        @relation_rules = Hash.new
        @state = nil
      end

      def use_parameter(param, rule_args = :all)
        rule = UsageRule.new(param, rule_args)
        @parameter_rules[param.name] = rule
      end

      def use_relation(relation, rule_args = :all)
        rule = UsageRule.new(relation, rule_args)
        @relation_rules[relation.name] = rule
      end

      def parameter_rules
        @parameter_rules.each_value do |rule|
          yield rule
        end
      end

      def relation_rules
        @relation_rules.each_value do |rule|
          yield rule
        end
      end
    end
  end
end