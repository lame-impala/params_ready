module ParamsReady
  module Helpers
    class Storage
      attr_reader :parameters, :relations

      def initialize
        @parameters = Hash.new
        @relations = Hash.new
      end

      def has_relation?(name)
        relations.key? name
      end

      def has_parameter?(name)
        parameters.key? name
      end

      def add_relation(relation)
        raise ParamsReadyError, "Relation already exists: #{relation.name}" if self.has_relation?(relation.name)
        @relations[relation.name] = relation
      end

      def add_parameter(param)
        raise ParamsReadyError, "Parameter already exists: #{param.name}" if self.has_parameter?(param.name)
        @parameters[param.name] = param
      end
    end
  end
end
