require_relative 'predicate'
require_relative '../parameter/parameter'
require_relative '../parameter/definition'

module ParamsReady
  module Query
    class CustomPredicate < Parameter::AbstractParameter
      include Predicate::DelegatingPredicate
      include Predicate::HavingChildren

      def initialize(definition)
        super definition
        @data = definition.type.create
      end

      def eligible_for_query?(arel_table, context)
        return false unless context.permitted? self
        eligibility_test = definition.eligibility_test
        return true if eligibility_test.nil?

        instance_exec(arel_table, context, &eligibility_test)
      end

      def to_query(arel_table, context: Restriction.blanket_permission)
        return unless eligible_for_query?(arel_table, context)

        to_query = definition.to_query
        raise ParamsReadyError, "Method 'to_query' unimplemented in '#{name}'" if to_query.nil?
        result = instance_exec(arel_table, context, &to_query)

        case result
        when Arel::Nodes::Node, nil
          result
        else
          literal = Arel::Nodes::SqlLiteral.new(result)
          grouping = Arel::Nodes::Grouping.new(literal)
          grouping
        end
      end

      def test(record)
        test = definition.test
        raise ParamsReadyError, "Method 'test' unimplemented in '#{name}'" if test.nil?
        self.instance_exec(record, &test)
      end
    end

    class CustomPredicateBuilder < Builder
      PredicateRegistry.register_predicate :custom_predicate, self
      include AbstractPredicateBuilder::HavingType

      def initialize(name, altn: nil)
        super CustomPredicateDefinition.new(name, altn: altn)
      end

      def type_builder_instance(type_name, name, *args, altn:, **opts, &block)
        builder_class = Builder.builder(type_name)
        builder_class.instance(name, *args, altn: altn, **opts)
      end

      def data_object_handles
        [@definition.name, @definition.altn]
      end

      def to_query(&proc)
        @definition.set_to_query(proc)
      end

      def eligible(&proc)
        @definition.set_eligibility_test(proc)
      end

      def test(&proc)
        @definition.set_test(proc)
      end
    end

    class CustomPredicateDefinition < Parameter::AbstractDefinition
      late_init :type, obligatory: true, freeze: false
      freeze_variable :type
      late_init :to_query, obligatory: false
      late_init :eligibility_test, obligatory: false
      late_init :test, obligatory: false

      include Parameter::DelegatingDefinition[:type]

      def initialize(*args, type: nil, to_query: nil, test: nil, **opts)
        @type = type
        @to_query = to_query
        @test = test
        super *args, **opts
      end

      def finish
        @type.finish
        super
      end

      parameter_class CustomPredicate
    end
  end
end