require_relative '../error'

module ParamsReady
  module Helpers
    module ArelBuilder
      class Callable
        def initialize(proc)
          @proc = proc
        end

        def to_arel(*args)
          result = @proc.call(*args)
          case result
          when String, Symbol
            to_literal(result).to_arel(*args)
          else
            result
          end
        end

        def to_literal(*)
          raise ParamsReadyError, "Unimplemented: #{self.class.name}##{__callee__}"
        end
      end

      class ArelObject
        def initialize(node)
          @node = node
        end

        def to_arel(*)
          @node
        end
      end

      def self.safe_name(name)
        name[0...64]
      end

      class Literal
        def initialize(literal)
          @literal = literal.to_s.freeze
        end

        def to_arel(*)
          Arel::Nodes::SqlLiteral.new(@literal)
        end
      end

      class Attribute
        def self.instance(object, arel_table: nil)
          case object
          when Arel::Nodes::Node, Arel::Nodes::SqlLiteral, Arel::Attribute
            raise ParamsReadyError, "Arel table unexpected" unless arel_table.nil? || arel_table == :none
            ArelObject.new(object)
          when Proc
            raise ParamsReadyError, "Arel table unexpected" unless arel_table.nil? || arel_table == :none
            Callable.new(object)
          when String, Symbol
            Literal.new(object, arel_table)
          else
            raise ParamsReadyError, "Unexpected type for arel builder: #{object.class.name}"
          end
        end

        class Callable < ArelBuilder::Callable
          def to_literal(string)
            Helpers::ArelBuilder::Attribute.instance(string)
          end
        end

        class Literal < ArelBuilder::Literal
          def initialize(literal, arel_table)
            super literal
            @arel_table = arel_table
          end

          def to_arel(default_table, *args)
            arel_table = @arel_table || default_table
            if arel_table == :none
              super(*args)
            else
              arel_table[@literal]
            end
          end
        end
      end

      class Table
        def self.instance(object, table_alias: nil)
          case object
          when Arel::Table, Arel::Nodes::TableAlias
            raise ParamsReadyError, "Table alias unexpected" unless table_alias.nil?
            ArelObject.new(object)
          when Proc
            Callable.new(object, table_alias)
          when String, Symbol
            Literal.new(object, table_alias)
          else
            raise ParamsReadyError, "Unexpected type for arel builder: #{object.class.name}"
          end
        end

        class Callable < ArelBuilder::Callable
          def initialize(proc, table_alias)
            super proc
            @table_alias = table_alias
          end

          def to_literal(string)
            Helpers::ArelBuilder::Table.instance(string, table_alias: @table_alias)
          end
        end

        class Literal < ArelBuilder::Literal
          def initialize(literal, table_alias)
            super literal
            raise "Table alias must be present" if table_alias.nil?
            @table_alias = table_alias.to_s.freeze
          end

          def to_arel(*)
            Arel::Table.new(@literal).as(@table_alias)
          end
        end
      end
    end
  end
end
