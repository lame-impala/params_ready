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
        @parameter_rules = self.class.merge_rule(rule, @parameter_rules)
      end

      def use_relation(relation, rule_args = :all)
        rule = UsageRule.new(relation, rule_args)
        @relation_rules = self.class.merge_rule(rule, @relation_rules)
      end

      def parameter_rules
        if block_given?
          @parameter_rules.each_value do |rule|
            yield rule
          end
        end
        @parameter_rules
      end

      def relation_rules
        if block_given?
          @relation_rules.each_value do |rule|
            yield rule
          end
        end
        @relation_rules
      end

      def self.merge_rule(rule, rules)
        existing = rules[rule.name]
        merged = rule.merge(existing)
        rules[rule.name] = merged
        rules
      end
    end
  end
end