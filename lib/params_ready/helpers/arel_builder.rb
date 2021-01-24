require_relative '../error'

module ParamsReady
  module Helpers
    class ArelBuilder
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

      def self.safe_name(name)
        name[0...64]
      end

      class Callable
        def initialize(proc)
          @proc = proc
        end

        def to_arel(*args)
          result = @proc.call(*args)
          case result
          when String, Symbol
            Helpers::ArelBuilder.instance(result).to_arel(*args)
          else
            result
          end
        end
      end

      class Literal
        def initialize(literal, arel_table)
          @literal = literal.to_s
          @arel_table = arel_table
        end

        def to_arel(default_table, _, _)
          arel_table = @arel_table || default_table
          if arel_table == :none
            Arel::Nodes::SqlLiteral.new(@literal)
          else
            arel_table[@literal]
          end
        end
      end

      class ArelObject
        def initialize(node)
          @node = node
        end

        def to_arel(_, _, _)
          @node
        end
      end
    end
  end
end