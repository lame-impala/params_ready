require_relative 'predicate'
require_relative '../parameter/struct_parameter'
require_relative '../parameter/value_parameter'
require_relative '../value/validator'
require_relative 'predicate_operator'

module ParamsReady
  module Query
    class VariableOperatorPredicate < Parameter::AbstractParameter
      include Predicate::DelegatingPredicate
      include Predicate::HavingAttribute

      def initialize(definition)
        super definition
        @data = definition.struct_parameter.create
      end

      def build_query(select_expression, context: nil)
        operator.to_query(select_expression, value)
      end

      def perform_test(record, attribute_name)
        operator.test(record, attribute_name, value)
      end

      def value
        @data[:value].unwrap
      end

      def operator
        @data[:operator].unwrap
      end

      def inspect_content
        op, val = if is_definite?
          @data[:operator].unwrap_or(nil)&.name || '?'
          @data[:value].unwrap_or('?')
        else
          %w[? ?]
        end
        "#{definition.attribute_name} #{op} #{val}"
      end
    end

    class OperatorCoder < Value::Coder
      def self.coerce(value, context)
        return value if value.class == Class && value < PredicateOperator
        identifier = value.to_sym
        PredicateRegistry.operator(identifier, context)
      end

      def self.format(value, intent)
        intent.hash_key(value)
      end

      def self.strict_default?
        false
      end
    end

    Parameter::ValueParameterBuilder.register_coder :predicate_operator, OperatorCoder

    class VariableOperatorPredicateBuilder < AbstractPredicateBuilder
      PredicateRegistry.register_predicate :variable_operator_predicate, self
      include HavingType
      include HavingAttribute
      include DelegatingBuilder[:struct_parameter_builder]

      def self.instance(name, altn: nil, attr: nil)
        new VariableOperatorPredicateDefinition.new name, altn: altn, attribute_name: attr
      end

      def data_object_handles
        [:value, :val]
      end

      def operators(*arr, &block)
        @definition.set_operators(arr, &block)
      end
    end

    class VariableOperatorPredicateDefinition < AbstractPredicateDefinition
      include HavingAttribute

      attr_reader :struct_parameter_builder
      attr_reader :struct_parameter

      def initialize(*args, attribute_name: nil, **opts)
        super *args, **opts
        @attribute_name = attribute_name
        @struct_parameter_builder = Builder.builder(:struct).instance(name, altn: altn)
        @operator_parameter_builder = Builder.builder(:predicate_operator).instance(:operator, altn: :op)
      end

      def set_type(type)
        @type = type
        @struct_parameter_builder.add @type.finish
      end

      def set_operators(array, &block)
        context = Format.instance(:backend)

        operators = array.map do |name|
          PredicateRegistry.operator(name, context)
        end
        @operator_parameter_builder.include do
          constrain :enum, operators
        end
        @operator_parameter_builder.include(&block) unless block.nil?
        @struct_parameter_builder.add @operator_parameter_builder.build
      end

      def finish
        @struct_parameter = @struct_parameter_builder.build
        @struct_parameter_builder = nil
        @operator_parameter_builder = nil
        @type = nil

        super
      end

      parameter_class VariableOperatorPredicate
    end
  end
end