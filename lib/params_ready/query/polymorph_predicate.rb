require 'forwardable'
require_relative 'predicate'
require_relative '../parameter/polymorph_parameter'

module ParamsReady
  module Query
    class PolymorphPredicate < Parameter::AbstractParameter
      include Predicate::DelegatingPredicate
      include Predicate::HavingChildren

      def_delegators :@data,
                     :intent_for_children,
                     :permission_depends_on

      def initialize(definition, **_)
        super definition
        @data = definition.polymorph_parameter.create
      end

      def to_query(arel_table, context: Restriction.blanket_permission)
        data[data.type].to_query_if_eligible(arel_table, context: context)
      end

      def test(record)
        return nil unless is_definite?

        data[data.type].test(record)
      end
    end

    class PolymorphPredicateBuilder < AbstractPredicateBuilder
      PredicateRegistry.register_predicate :polymorph_predicate, self
      include HavingValue

      def self.instance(name, altn: nil)
        new PolymorphPredicateDefinition.new name, altn: altn
      end

      def type(type_name, *args, **opts, &block)
        builder = PredicateRegistry.predicate(type_name).instance(*args, **opts)
        builder.instance_eval(&block) unless block.nil?
        type = builder.build
        @definition.add_type type
      end

      def identifier(identifier)
        @definition.set_identifier(identifier)
      end
    end

    class PolymorphPredicateDefinition < AbstractPredicateDefinition
      extend Forwardable

      attr_reader :polymorph_parameter, :name, :altn
      freeze_variable :polymorph_parameter
      def_delegators :@polymorph_parameter,
                     :add_type,
                     :set_optional,
                     :set_default,
                     :set_identifier,
                     :set_marshaller

      def initialize(*args, **opts)
        super
        @polymorph_parameter = Parameter::PolymorphParameterDefinition.new(name, altn: altn)
        @optional = false
      end

      def finish
        @polymorph_parameter.finish
        super
      end

      parameter_class PolymorphPredicate
    end
  end
end