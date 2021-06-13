require_relative 'storage'
require_relative 'usage_rule'

module ParamsReady
  module Helpers
    class Options
      attr_reader :parameters, :relations

      def initialize
        @parameter_rules = Hash.new
        @relation_rules = Hash.new
        @memo = { parameters: {}, relations: {}}
      end

      def dup
        duplicate = Options.new
        @parameter_rules.each do |_, rule|
          duplicate.merge_parameter_rule(rule)
        end
        @relation_rules.each do |_, rule|
          duplicate.merge_relation_rule(rule)
        end
        duplicate
      end

      def relation_definitions_for(name)
        @memo[:relations][name] ||= definitions_for(name, relation_rules)
      end

      def parameter_definitions_for(name)
        @memo[:parameters][name] ||= definitions_for(name, parameter_rules)
      end

      def definitions_for(name, rules)
        rules.each_with_object([]) do |(_, rule), result|
          next unless rule.valid_for?(name)

          result << rule.parameter_definition
        end
      end

      def use_parameter(param, rule_args = :all)
        rule = UsageRule.new(param, rule_args)
        merge_parameter_rule(rule)
      end

      def merge_parameter_rule(rule)
        @parameter_rules = self.class.merge_rule(rule, @parameter_rules)
      end

      def use_relation(relation, rule_args = :all)
        rule = UsageRule.new(relation, rule_args)
        merge_relation_rule(rule)
      end

      def merge_relation_rule(rule)
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