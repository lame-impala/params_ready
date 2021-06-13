require_relative 'rule'

module ParamsReady
  module Helpers
    class UsageRule
      attr_reader :parameter_definition, :rule

      def initialize(parameter_definition, rule = :all)
        @parameter_definition = parameter_definition
        @rule = ParamsReady::Helpers::Rule(rule)
        freeze
      end

      def valid_for?(method)
        @rule.include? method
      end

      def name
        parameter_definition.name
      end

      def merge(other)
        return self if other.nil?
        raise ParamsReadyError, "Can't merge into #{other.class.name}" unless other.is_a? UsageRule

        unless parameter_definition == other.parameter_definition
          message = "Can't merge incompatible rules: #{parameter_definition.name}/#{other.parameter_definition.name}"
          raise ParamsReadyError, message
        end

        rule = self.rule.merge(other.rule)
        UsageRule.new(parameter_definition, rule)
      end
    end
  end
end
