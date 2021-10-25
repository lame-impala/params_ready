require_relative '../extensions/registry'
require_relative '../parameter/array_parameter'
require_relative '../parameter/enum_set_parameter'
require_relative '../helpers/arel_builder'

module ParamsReady
  module Query
    class AbstractPredicateBuilder < AbstractBuilder
      module HavingType
        def type(type_name, *args, **opts, &block)
          name, altn = data_object_handles
          builder = type_builder_instance(type_name, name, *args, altn: altn, **opts)
          builder.instance_eval(&block) unless block.nil?
          @definition.set_type builder.fetch
        end

        def type_builder_instance(type_name, name, *args, altn:, **opts)
          AbstractPredicateBuilder.type(type_name)
                                  .instance(name, *args, altn: altn, **opts)
        end
      end

      module HavingAttribute
        def associations(*arr)
          arr.each do |name|
            @definition.add_association name
          end
        end

        def attribute(name: nil, expression: nil, &block)
          expression = if expression
            raise ParamsReadyError, 'Block unexpected' unless block.nil?
            expression
          else
            raise ParamsReadyError, 'Expression unexpected' unless expression.nil?
            block
          end
          @definition.set_attribute(name, expression)
        end
      end

      include HavingArelTable

      extend Extensions::Registry
      registry :types, as: :type, getter: true
      register_type :value, Parameter::ValueParameterBuilder
      register_type :array, Parameter::ArrayParameterBuilder
      register_type :enum_set, Parameter::EnumSetParameterBuilder
    end

    class AbstractPredicateDefinition < Parameter::AbstractDefinition
      late_init :arel_table, obligatory: false, freeze: false

      module HavingAttribute
        def self.included(base)
          base.collection :associations, :association
        end

        def set_attribute(name, select_expression)
          @attribute_name = name
          @select_expression = select_expression
        end

        def attribute_name
          @attribute_name || @name
        end

        def select_expression
          @select_expression || attribute_name
        end

        def build_select_expression(arel_table, context)
          arel_builder = Helpers::ArelBuilder::Attribute.instance(select_expression, arel_table: @arel_table)
          arel = arel_builder.to_arel(arel_table, context, self)

          arel
        end

        def alias_select_expression(arel_table, context)
          build_select_expression(arel_table, context).as(attribute_name.to_s)
        end
      end
    end

    module Predicate
      module HavingChildren
        def context_for_predicates(context)
          intent_for_children(context)
        end
      end

      module HavingAssociations
        def dig(record, associations)
          associations.reduce(record) do |record, assoc|
            next record if record.nil?

            record.send assoc
          end
        end
      end

      module HavingAttribute
        extend Forwardable
        def_delegators :definition, :build_select_expression, :alias_select_expression
        include HavingAssociations

        def to_query(arel_table, context: Restriction.blanket_permission)
          table = definition.arel_table || arel_table
          select_expression = build_select_expression(table, context)
          build_query(select_expression, context: context)
        end

        def context_for_predicates(context)
          # We consider a an attribute having parameter atomic
          # so it's permitted per se including its contents
          context.permit_all
        end

        def test(record)
          return nil unless is_definite?

          attribute_name = definition.attribute_name
          record = dig(record, definition.associations)

          perform_test(record, attribute_name)
        end
      end

      module DelegatingPredicate
        def self.included(base)
          base.include Parameter::DelegatingParameter
        end

        def eligible_for_query?(_table, context)
          return false unless context.permitted? self

          is_definite?
        end

        def to_query_if_eligible(arel_table, context:)
          return unless eligible_for_query?(arel_table, context)

          context = context_for_predicates(context)
          to_query(arel_table, context: context)
        end
        attr_reader :data

      end
    end

    class PredicateRegistry
      extend Extensions::Registry

      registry :operator_names, as: :operator_by_name, name_method: :name
      registry :operator_alt_names, as: :operator_by_alt_name, name_method: :altn
      registry :predicates, as: :predicate, getter: true

      def self.operator_by(identifier, format)
        if format.alternative?
          @@operator_alt_names[identifier]
        else
          @@operator_names[identifier]
        end
      end

      def self.operator(identifier, format, collision_check = false)
        operator = find_operator(identifier, format, collision_check)
        if operator.nil? && !collision_check
          raise("No such operator: #{identifier}")
        end

        operator
      end

      def self.find_operator(identifier, format, collision_check)
        operator = operator_by(identifier, format)
        if operator.nil?
          name_as_string = identifier.to_s
          invertor = if format.alternative?
            'n_'
          else
            'not_'
          end
          if !collision_check && name_as_string.start_with?(invertor)
            bare_name = name_as_string[invertor.length..-1].to_sym
            inverted = PredicateRegistry.operator(bare_name, format)
            if inverted.nil?
              nil
            elsif inverted.inverse_of.nil?
              Not.new(inverted)
            else
              operator(inverted.inverse_of, format)
            end
          else
            nil
          end
        else
          operator
        end
      end
    end
  end
end