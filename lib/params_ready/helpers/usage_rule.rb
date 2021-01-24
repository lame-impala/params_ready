require_relative 'rule'

module ParamsReady
  module Helpers
    class UsageRule
      attr_reader :parameter_definition

      def initialize(parameter_definition, rule = :all)
        @parameter_definition = parameter_definition
        @rule = ParamsReady::Helpers::Rule(rule)
      end

      def valid_for(method)
        @rule.include? method
      end
    end
  end
end