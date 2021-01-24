require 'set'

module ParamsReady
  module Helpers
    def self.Rule(input)
      return input if input.nil?
      return input if input.is_a? Rule

      Rule.new(input).freeze
    end

    class Rule
      attr_reader :hash

      def initialize(value)
        @mode, @values = case value
        when :none, :all then [value, nil]
        when Hash
          if value.length > 1 || value.length < 1
            raise ParamsReadyError, "Unexpected hash for rule: '#{value}'"
          end
          key, values = value.first
          case key
          when :except, :only then [key, values.to_set.freeze]
          else
            raise ParamsReadyError, "Unexpected mode for rule: '#{key}'"
          end
        else
          raise ParamsReadyError, "Unexpected input for rule: '#{value}'"
        end
        @values.freeze
        @hash = [@mode, @values].hash
        freeze
      end

      def include?(name)
        case @mode
        when :none then false
        when :all then true
        when :only then @values.member? name
        when :except
          !@values.member? name
        else
          raise ParamsReadyError, "Unexpected mode for rule: '#{@mode}'"
        end
      end

      def ==(other)
        return false unless other.is_a? Rule
        return true if object_id == other.object_id
        return false unless @mode == other.instance_variable_get(:@mode)

        @values == other.instance_variable_get(:@values)
      end
    end
  end
end