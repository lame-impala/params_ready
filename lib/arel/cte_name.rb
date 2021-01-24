module Arel # :nodoc: all
  module Nodes
    class CteName < Unary
      alias :name :expr

      def initialize(expr)
        expr = SqlLiteral.new(expr)
        super expr
      end
    end
  end

  module Visitors
    class ToSql < Visitor
      def visit_Arel_Nodes_CteName(o, collector)
        collector << o.expr
      end
    end
  end
end
