require 'forwardable'
require_relative 'structured_grouping'
require_relative 'join_clause'
require_relative '../pagination/offset_pagination'
require_relative '../pagination/keyset_pagination'
require_relative '../pagination/direction'
require_relative '../ordering/ordering'

module ParamsReady
  module Query
    class Relation < StructuredGrouping
      module PageAccessors
        def page_accessor(name, delegate = nil)
          delegate ||= "#{name}_page"

          define_method name do |*args|
            send(delegate, *args)&.for_frontend
          end
          ruby2_keywords name
        end

        def self.extended(mod)
          mod.page_accessor :current
          mod.page_accessor :first
          mod.page_accessor :last
          mod.page_accessor :previous
          mod.page_accessor :next
          mod.page_accessor :before
          mod.page_accessor :after
          mod.page_accessor :limit_at, :limited_at
          mod.page_accessor :toggle, :toggled_order
          mod.page_accessor :reorder, :reordered
        end
      end

      extend PageAccessors
      extend Forwardable

      def_delegators :pagination, :offset, :limit, :num_pages, :page_no, :has_previous?, :has_next?, :has_page?

      def child_is_definite?(name)
        return false unless definition.has_child?(name)
        return false if self[name].nil?
        return false unless self[name].is_definite?

        true
      end

      def pagination
        self[:pagination]
      end

      def ordering
        self[:ordering]
      end

      def ordering_or_nil
        return unless child_is_definite?(:ordering)

        self[:ordering]
      end

      def new_offset(delta)
        pagination.new_offset(delta)
      end

      def page(delta, count: nil)
        return nil unless pagination.can_yield_page?(delta, count: count)
        return self if delta == 0

        new_offset = pagination.new_offset(delta)

        update_in(new_offset, [:pagination, 0])
      end

      def current_page(count: nil)
        page(0, count: count)
      end

      def first_page
        value = pagination.first_page_value
        update_in(value, [:pagination])
      end

      def last_page(count:)
        value = pagination.last_page_value(count: count)
        return if value.nil?
        update_in(value, [:pagination])
      end

      def previous_page(delta = 1)
        value = pagination.previous_page_value(delta)
        return if value.nil?
        update_in(value, [:pagination])
      end

      def next_page(delta = 1, count: nil)
        value = pagination.next_page_value(delta, count: count)
        return if value.nil?
        page(delta, count: count)
      end

      def before_page(keyset)
        tuple = { direction: :bfr, limit: limit, keyset: keyset }
        update_in(tuple, [:pagination])
      end

      def after_page(keyset)
        tuple = { direction: :aft, limit: limit, keyset: keyset }
        update_in(tuple, [:pagination])
      end

      def limited_at(limit)
        update_in(limit, [:pagination, pagination.limit_key])
      end

      def toggled_order(column)
        new_order = ordering.toggled_order_value(column)
        toggled = update_in(new_order, [:ordering])
        toggled.update_in(0, [:pagination, 0])
      end

      def reordered(column, direction)
        new_order = ordering.reordered_value(column, direction)
        reordered = update_in(new_order, [:ordering])
        reordered.update_in(0, [:pagination, 0])
      end

      def model_class(default_model_class)
        default_model_class || definition.model_class
      end

      def arel_table(default_model_class)
        model_class(default_model_class).arel_table
      end

      def perform_count(scope: nil, context: Restriction.blanket_permission)
        scope ||= definition.model_class if definition.model_class_defined?
        group = to_query_if_eligible(scope.arel_table, context: context)
        relation = scope.where(group)
        relation = perform_joins(relation, context)
        relation.count
      end

      def keysets(limit, direction, keyset, scope: nil, context: Restriction.blanket_permission, &block)
        model_class = scope || definition.model_class
        group = to_query_if_eligible(model_class.arel_table, context: context)
        relation = model_class.where(group)
        relation = perform_joins(relation, context)

        sql_literal = pagination.keysets_for_relation(relation, limit, direction, keyset, ordering, context, &block)

        array = model_class.connection.execute(sql_literal.to_s).to_a
        Pagination::Direction.instance(direction).keysets(keyset, array, &block)
      end

      def build_relation(scope: nil, include: [], context: Restriction.blanket_permission, paginate: true)
        model_class = scope || definition.model_class
        group = to_query_if_eligible(model_class.arel_table, context: context)
        relation = model_class.where(group)
        relation = relation.includes(*include) unless include.empty?
        relation = perform_joins(relation, context)

        order_and_paginate_relation(relation, context, paginate)
      end

      def perform_joins(relation, context)
        return relation if definition.joins.empty?

        sql = joined_tables(relation.arel_table, context).join_sources.map(&:to_sql).join(' ')
        relation.joins(sql)
      end

      def to_count(model_class: nil, context: Restriction.blanket_permission)
        model_class = model_class || definition.model_class

        arel_table = joined_tables(model_class.arel_table, context)

        group = to_query_if_eligible(model_class.arel_table, context: context)

        query = if group.nil?
          arel_table
        else
          arel_table.where(group)
        end
        query.project(arel_table[:id].count)
      end

      def build_select(model_class: nil, context: Restriction.blanket_permission, select_list: Arel.star, paginate: true)
        arel_table, query = build_query(model_class, context)
        query = order_and_paginate_query(query, arel_table, context, paginate)
        query.project(select_list)
      end

      def build_keyset_query(limit, direction, keyset, model_class: nil, context: Restriction.blanket_permission)
        arel_table, query = build_query(model_class, context)
        pagination.select_keysets(query, limit, direction, keyset, ordering, arel_table, context)
      end

      def build_query(model_class, context)
        arel_table = arel_table(model_class)

        group = to_query_if_eligible(arel_table, context: context)
        joined = joined_tables(arel_table, context)

        query = if group.nil?
          joined
        else
          joined.where(group)
        end

        [arel_table, query]
      end

      def to_query_if_eligible(arel_table, context:)
        return if respond_to?(:to_query?) && !to_query?(arel_table, context)

        predicate_group(arel_table, context: context)
      end

      def order_if_applicable(arel_table, context)
        if child_is_definite?(:ordering) && (context.permitted?(ordering) || ordering.required?)
          ordering = self.ordering.to_arel(arel_table, context: context)
          yield ordering if ordering.length > 0
        end
      end

      def paginate_if_applicable(paginate)
        if paginate && child_is_definite?(:pagination)
          pagination = self.pagination
          yield pagination
        end
      end

      def order_and_paginate_relation(relation, context, paginate)
        paginate_if_applicable(paginate) do |pagination|
          relation = pagination.paginate_relation(relation, ordering_or_nil, context)
        end

        order_if_applicable(relation.arel_table, context) do |ordering|
          relation = relation.order(ordering)
        end
        relation
      end

      def order_and_paginate_query(query, arel_table, context, paginate)
        paginate_if_applicable(paginate) do |pagination|
          query = pagination.paginate_query(query, ordering_or_nil, arel_table, context)
        end

        order_if_applicable(arel_table, context) do |ordering|
          query = query.order(*ordering)
        end
        query
      end

      def joined_tables(base_table, context)
        definition.joins.reduce(base_table) do |joined_table, join|
          join = join.to_arel(joined_table, base_table, context, self)
          next joined_table if join.nil?

          join
        end
      end
    end

    class RelationParameterBuilder < Builder
      include GroupingLike
      include Parameter::AbstractStructParameterBuilder::StructLike
      include HavingModel

      def self.instance(name, altn: nil)
        new RelationDefinition.new(name, altn: altn)
      end

      register :relation
      DEFAULT_LIMIT = 10

      def paginate(limit = DEFAULT_LIMIT, max_limit = nil, method: :offset, &block)
        case method
        when :offset
          raise ParamsReadyError, 'Block not expected' unless block.nil?
          add Pagination::OffsetPaginationDefinition.new(0, limit, max_limit).finish
        when :keyset
          ordering_builder = @definition.init_ordering_builder(empty: true)
          rcpb = Pagination::KeysetPaginationBuilder.new ordering_builder, limit, max_limit
          add rcpb.build(&block)
        else
          raise "Unimplemented pagination method '#{method}'"
        end
      end

      def order(&proc)
        ordering_builder = @definition.init_ordering_builder(empty: false)
        ordering_builder.instance_eval(&proc) unless proc.nil?
        ordering = ordering_builder.build
        add ordering
      end

      def join_table(arel_table, type, &block)
        join = Join.new arel_table, type, &block
        join.freeze
        @definition.add_join(join)
      end
    end

    class RelationDefinition < StructuredGroupingDefinition
      late_init :model_class, obligatory: false, freeze: false, getter: false
      collection :joins, :join

      def model_class
        raise ParamsReadyError, "Model class not set for #{name}" if @model_class.nil?
        @model_class
      end

      def init_ordering_builder(empty:)
        raise ParamsReadyError, 'Ordering already defined' if empty == true && !@ordering_builder.nil?
        @ordering_builder ||= Ordering::OrderingParameterBuilder.instance
      end

      def arel_table
        model_class.arel_table
      end

      def model_class_defined?
        !@model_class.nil?
      end

      attr_reader :joins

      def initialize(*args, **opts)
        @joins = []
        @ordering_builder = nil
        super
      end

      def finish
        raise ParamsReadyError, 'Ordering must be explicitly declared' if @ordering_builder&.open?
        @ordering_builder = nil
        super
      end

      parameter_class Relation
    end
  end
end