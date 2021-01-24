require_relative '../helpers/arel_builder'

module ParamsReady
  module Query
    class Join
      attr_reader :arel_table, :statement, :type

      def initialize(table, type, &block)
        @arel_table = table
        @type = arel_type(type)
        @statement = JoinStatement.new(&block)
      end

      def arel_type(type)
        case type
        when :inner then Arel::Nodes::InnerJoin
        when :outer then Arel::Nodes::OuterJoin
        else raise ParamsReadyError, "Unimplemented join type '#{type}'"
        end
      end

      def to_arel(base_table, context, parameter)
        join_statement = @statement.to_arel(base_table, @arel_table, context, parameter)
        base_table.join(@arel_table, @type).on(join_statement)
      end
    end

    class JoinStatement
      def initialize(on: nil, eq: nil, &block)
        @conditions = []
        if on
          condition = on(on)
          if eq
            condition.eq(eq)
          end
        else
          raise ParamsReadyError('Parameter :eq unexpected') unless eq.nil?
        end

        instance_eval(&block) unless block.nil?
        raise ParamsReadyError, "Join clause is empty" if @conditions.empty?
      end

      def on(expression, arel_table: nil)
        condition = JoinCondition.new(expression, arel_table: arel_table)
        @conditions << condition
        condition
      end

      def to_arel(base_table, join_table, context, parameter)
        @conditions.reduce(nil) do |result, condition|
          arel = condition.to_arel(base_table, join_table, context, parameter)
          next arel if result.nil?

          result.and(arel)
        end
      end
    end

    class JoinCondition
      def initialize(expression, arel_table: nil)
        @on = Helpers::ArelBuilder.instance(expression, arel_table: arel_table)
        @to = nil
        @op = nil
      end

      def eq(expression, arel_table: nil)
        raise ParamsReadyError, "Operator already set" unless @op.nil?
        @op = :eq
        @to = Helpers::ArelBuilder.instance(expression, arel_table: arel_table)
      end

      def to_arel(base_table, join_table, context, parameter)
        if @to.nil?
          grouping =  @on.to_arel(:none, context, parameter)
          return grouping if grouping.is_a? Arel::Nodes::Node

          Arel::Nodes::Grouping.new(grouping)
        else
          lhs =  @on.to_arel(base_table, context, parameter)
          rhs = @to.to_arel(join_table, context, parameter)
          lhs.send(@op, rhs)
        end
      end
    end
  end
end