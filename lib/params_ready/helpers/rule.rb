require 'set'

module ParamsReady
  module Helpers
    def self.Rule(input)
      return input if input.nil?
      return input if input.is_a? Rule

      Rule.instance(input).freeze
    end

      class Rule
      attr_reader :hash, :mode, :values

      def self.instance(input)
        mode, values = case input
        when :none, :all then [input, nil]
        when Hash
          if input.length > 1 || input.length < 1
            raise ParamsReadyError, "Unexpected hash for rule: '#{input}'"
          end
          key, values = input.first
          case key
          when :except, :only then [key, values.to_set.freeze]
          else
            raise ParamsReadyError, "Unexpected mode for rule: '#{key}'"
          end
        else
          raise ParamsReadyError, "Unexpected input for rule: '#{input}'"
        end
        new(mode, values)
      end

      def initialize(mode, values)
        @mode = mode
        @values = values.freeze
        @hash = [@mode, @values].hash
        freeze
      end

      def merge(other)
        return self if other.nil?
        raise ParamsReadyError, "Can't merge with #{other.class.name}" unless other.is_a? Rule
        raise ParamsReadyError, "Can't merge incompatible rules: #{mode}/#{other.mode}" if other.mode != mode

        case mode
        when :all, :none
          self
        when :only, :except
          values = self.values + other.values
          Rule.new(mode, values)
        end
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