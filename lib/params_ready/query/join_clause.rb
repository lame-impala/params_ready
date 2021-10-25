require_relative '../helpers/arel_builder'
require_relative '../error'

module ParamsReady
  module Query
    class Join
      class Builder
        def initialize(&block)
          @block = block
          @statement_builder = nil
          @only_if = nil
        end

        def build
          instance_eval(&@block)
          @block = nil
          raise ParamsReadyError, 'Join statement must be present' if @statement_builder.nil?
          [@statement_builder.build, @only_if]
        end

        def on(expression, arel_table: nil)
          @statement_builder ||= JoinStatement::Builder.new
          @statement_builder.on(expression, arel_table: arel_table)
        end

        def only_if(&block)
          @only_if = block
          nil
        end
      end

      attr_reader :arel_table, :statement, :type

      def initialize(table, type, table_alias: nil, &block)
        @arel_table = Helpers::ArelBuilder::Table.instance(table, table_alias: table_alias)
        @type = arel_type(type)
        @statement, @only_if = Builder.new(&block).build
        freeze
      end

      def arel_table(context, parameter)
        @arel_table.to_arel(context, parameter)
      end

      def arel_type(type)
        case type
        when :inner then Arel::Nodes::InnerJoin
        when :outer then Arel::Nodes::OuterJoin
        else raise ParamsReadyError, "Unimplemented join type '#{type}'"
        end
      end

      def to_arel(joined_table, base_table, context, parameter)
        return joined_table unless eligible?(context, parameter)

        arel_table = arel_table(context, parameter)
        join_statement = @statement.to_arel(base_table, arel_table, context, parameter)
        joined_table.join(arel_table, @type).on(join_statement)
      end

      def eligible?(context, parameter)
        return true if @only_if.nil?

        @only_if.call(context, parameter)
      end
    end

    class JoinStatement
      class Builder
        def initialize(on: nil, eq: nil, &block)
          @condition_builders = []
          if on.nil?
            raise ParamsReadyError, 'Parameter :eq unexpected' unless eq.nil?
          else
            condition = on(on)
            condition.eq(eq) unless eq.nil?
          end
          @block = block
        end

        def on(expression, arel_table: nil)
          condition = JoinCondition::Builder.new(expression, arel_table: arel_table)
          @condition_builders << condition
          condition
        end

        def build
          instance_eval(&@block) unless @block.nil?
          JoinStatement.new(@condition_builders.map(&:build))
        end
      end

      def initialize(conditions)
        @conditions = conditions.freeze
        raise ParamsReadyError, "Join clause is empty" if @conditions.empty?

        freeze
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
      class Builder
        def initialize(expression, arel_table: nil)
          @on = Helpers::ArelBuilder::Attribute.instance(expression, arel_table: arel_table)
          @op = nil
          @to = nil
        end

        def eq(expression, arel_table: nil)
          raise ParamsReadyError, "Operator already set" unless @op.nil?
          @op = :eq
          @to = Helpers::ArelBuilder::Attribute.instance(expression, arel_table: arel_table)
        end

        def build
          JoinCondition.new(@on, @op, @to)
        end
      end

      def initialize(on, op, to)
        @on = on
        @op = op
        @to = to
        freeze
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