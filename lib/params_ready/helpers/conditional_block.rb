require_relative 'rule'
require_relative '../error'

module ParamsReady
  module Helpers
    class Conditional
      def initialize(rule: nil)
        @rule = Helpers::Rule(rule)
        freeze
      end

      def perform?(general_rule, name)
        if @rule.nil?
          general_rule
        else
          @rule.include?(name)
        end
      end
    end

    class ConditionalBlock < Conditional
      attr_reader :block

      def initialize(rule: nil, &block)
        raise ParamsReadyError, "Block must not be empty" if block.nil?
        @block = block
        super(rule: rule)
      end
    end
  end
end
