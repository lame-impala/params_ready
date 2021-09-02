require_relative '../error'
require_relative '../../params_ready/parameter/struct_parameter'
require_relative '../query/relation'

module ParamsReady
  module Parameter
    class State < StructParameter
      extend Query::Relation::PageAccessors
      extend Forwardable
      def_delegators :definition, :relations

      def relation(name)
        raise ParamsReadyError, "Relation not defined: '#{name}'" unless relations.include? name
        child(name)
      end

      def self.relation_delegator(name)
        define_method name do |relation_name, *args|
          relation(relation_name).send(name, *args)
        end
        ruby2_keywords name
      end

      relation_delegator :ordering
      relation_delegator :num_pages
      relation_delegator :page_no
      relation_delegator :offset
      relation_delegator :limit
      relation_delegator :has_previous?
      relation_delegator :has_previous?
      relation_delegator :has_next?
      relation_delegator :has_page?

      def page(relation_name = nil, delta = 0, count: nil)
        if delta == 0
          clone
        else
          raise ParamsReadyError, "Relation must be specified when delta is not 0" if relation_name.nil?

          return nil unless relation(relation_name).pagination.can_yield_page? delta, count: count
          new_offset = relation(relation_name).new_offset(delta)
          update_in(new_offset, [relation_name, :pagination, 0])
        end
      end

      def current_page
        page
      end

      def first_page(relation_name)
        value = relation(relation_name).pagination.first_page_value
        update_in(value, [relation_name, :pagination])
      end

      def last_page(relation_name, *args, **opts)
        value = relation(relation_name).pagination.last_page_value(*args, **opts)
        return if value.nil?
        update_in(value, [relation_name, :pagination])
      end

      def previous_page(relation_name, delta = 1)
        value = relation(relation_name).pagination.previous_page_value(delta)
        return if value.nil?
        update_in(value, [relation_name, :pagination])
      end

      def next_page(relation_name, delta = 1, count: nil)
        value = relation(relation_name).pagination.next_page_value(delta, count: count)
        return if value.nil?
        update_in(value, [relation_name, :pagination])
      end

      def before_page(relation_name, keyset)
        value = relation(relation_name).pagination.before_page_value(keyset)
        update_in(value, [relation_name, :pagination])
      end

      def after_page(relation_name, keyset)
        value = relation(relation_name).pagination.after_page_value(keyset)
        update_in(value, [relation_name, :pagination])
      end

      def limited_at(relation_name, limit)
        limit_key = relation(relation_name).pagination.limit_key
        update_in(limit, [relation_name, :pagination, limit_key])
      end

      def toggled_order(relation_name, column)
        new_order = relation(relation_name).ordering.toggled_order_value(column)
        toggled = update_in(new_order, [relation_name, :ordering])
        toggled.first_page(relation_name)
      end

      def reordered(relation_name, column, direction)
        new_order = relation(relation_name).ordering.reordered_value(column, direction)
        reordered = update_in(new_order, [relation_name, :ordering])
        reordered.first_page(relation_name)
      end
    end

    class StateBuilder < StructParameterBuilder
      def relation(relation)
        @definition.add_relation relation
      end

      def self.instance
        definition = StateDefinition.new(:'', altn: :'')
        new definition
      end
    end

    class StateDefinition < StructParameterDefinition
      parameter_class State
      attr_reader :relations

      def initialize(*args, **opts)
        super *args, **opts
        @relations = Set.new
      end

      def add_relation(relation)
        if @relations.include? relation.name
          raise ParamsReadyError, "Relation already there '#{relation.name}'"
        end
        @relations << relation.name
        add_child relation
      end

      freeze_variable :relations
    end
  end
end
