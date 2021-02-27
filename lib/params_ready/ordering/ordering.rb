require 'set'
require_relative '../parameter/definition'
require_relative '../builder'
require_relative '../parameter/parameter'
require_relative 'column'

module ParamsReady
  module Ordering
    class OrderingParameter < Parameter::ArrayParameter
      def_delegators :definition, :required?

      def marshal(intent)
        arr = to_array(intent)
        return arr unless intent.marshal?(name_for_formatter)

        arr.join(definition.class::COLUMN_DELIMITER)
      end

      def to_array(intent = Intent.instance(:backend))
        arr = bare_value
        arr.map do |tuple|
          name = tuple.first.unwrap
          next unless intent.name_permitted?(name) || definition.required?(name)

          tuple.format(intent)
        end.compact
      end

      def by_columns
        bare_value.each_with_index.each_with_object(Hash.new([:none, nil])) do |(tuple, index), hash|
          hash[tuple[0].unwrap] = [tuple[1].unwrap, index]
        end
      end

      def toggle_schema(schema)
        case schema
        when :desc
          [:desc, :asc]
        when :asc
          [:asc, :desc]
        else
          [:none, :none]
        end
      end

      def filtered(name)
        bare_value.map do |tuple|
          tuple.format(Intent.instance(:backend))
        end.partition do |item|
          next item[0] == name
        end
      end

      def prepend_item(name, direction, array)
        return array if direction == :none
        [[name, direction], *array]
      end

      def inverted_order_value
        bare_value.map do |tuple|
          name = tuple.first.unwrap
          case tuple.second.unwrap
          when :asc
            [name, :desc]
          when :desc
            [name, :asc]
          else
            raise ParamsReadyError, "Unexpected ordering: '#{tuple.second.unwrap}'"
          end
        end
      end

      def inverted_order
        update_in(inverted_order_value, [])
      end

      def toggled_order_value(name)
        drop, save = filtered(name)

        old_dir = drop.count > 0 ? drop.first[1] : :none
        primary, secondary = toggle_schema(definition.columns[name.to_sym].ordering)
        new_dir = old_dir == primary ? secondary : primary

        prepend_item(name, new_dir, save)
      end

      def toggled_order(name)
        update_in(toggled_order_value(name), [])
      end

      def reordered_value(name, new_dir)
        _, save = filtered(name)
        prepend_item(name, new_dir, save)
      end

      def reordered(name, new_dir)
        update_in(reordered_value(name, new_dir), [])
      end

      def restriction_from_context(context)
        restriction = context.to_restriction
        return restriction if restriction.name_permitted? :ordering || !required?

        Restriction.permit({ ordering: [] })
      end

      def to_arel(default_table, context: Restriction.blanket_permission, inverted: false)
        ordering = inverted ? inverted_order : self
        ordering.to_array_with_context(context).flat_map do |(column_name, direction)|
          column = definition.columns[column_name]
          attribute = column.attribute(column_name, default_table, context)
          column.clauses(attribute, direction, inverted: inverted)
        end
      end

      def to_array_with_context(context)
        intent = Intent.instance(:backend).clone(restriction: restriction_from_context(context))
        to_array(intent.for_children(self))
      end

      def order_for(name)
        order = bare_value.find do |tuple|
          tuple[0].unwrap == name
        end
        return :none if order.nil?

        order[1].unwrap
      end
    end

    class OrderingParameterBuilder < Builder
      def self.instance
        new OrderingParameterDefinition.new({})
      end

      def column(name, ordering, arel_table: nil, expression: nil, nulls: :default, required: false, pk: false)
        @definition.add_column(
          name,
          ordering,
          arel_table: arel_table,
          expression: expression,
          nulls: nulls,
          required: required,
          pk: pk
        )
      end

      def default(*array)
        super array
      end
    end

    class OrderingParameterDefinition < Parameter::ArrayParameterDefinition
      COLUMN_DELIMITER = '|'
      FIELD_DELIMITER = '-'
      attr_reader :columns, :primary_keys

      parameter_class OrderingParameter

      def initialize(columns, default = Extensions::Undefined)
        invalid = columns.values.uniq.reject do |column|
          column.is_a? Column
        end
        raise ParamsReadyError, "Invalid ordering values: #{invalid.join(", ")}" unless invalid.length == 0
        @columns = columns.transform_keys { |k| k.to_sym }
        @required_columns = nil
        @primary_keys = Set.new
        super :ordering, altn: :ord, prototype: nil, default: default
      end

      def set_default(value)
        raise ParamsReadyError, "Prototype for ordering expected to be nil" unless @prototype.nil?
        set_required_columns

        @prototype = create_prototype columns
        super value
      end

      def set_required_columns
        return unless @required_columns.nil?

        @required_columns = @columns.select do |_name, value|
          value.required
        end.map do |name, _value|
          name
        end
      end

      def required?(name = nil)
        return !@required_columns.empty? if name.nil?

        @required_columns.member?(name)
      end

      def add_column(
        name,
        ordering,
        expression:,
        arel_table:,
        nulls: :default,
        required: false,
        pk: false
      )
        raise ParamsReadyError, "Column name taken: #{name}" if @columns.key? name
        raise ParamsReadyError, "Can't add column after default defined" unless @default == Extensions::Undefined
        @primary_keys << name if pk == true

        column = Column.new(
          ordering,
          expression: expression,
          arel_table: arel_table,
          nulls: nulls,
          required: required,
          pk: pk
        )
        @columns[name] = column
      end

      def create_prototype(columns)
        Builder.define_tuple(:column) do
          marshal using: :string, separator: FIELD_DELIMITER
          field :symbol, :column_name do
            constrain Value::EnumConstraint.new(columns.keys)
          end
          field :symbol, :column_ordering do
            constrain Value::EnumConstraint.new(Column::DIRECTIONS)
          end
        end
      end

      def try_canonicalize(input, context, validator = nil, freeze: false)
        input ||= [%w(none none)]
        canonical, validator = case input
        when String
          raise ParamsReadyError, "Freeze option expected to be false" if freeze
          array = input.split(COLUMN_DELIMITER)
          try_canonicalize(array, context, validator, freeze: false)
        when Array
          super
        else
          raise ParamsReadyError, "Unexpected type for #{name}: #{input.class.name}"
        end
        unique_columns = unique_columns(canonical)
        with_required = with_required(unique_columns)
        [with_required.values, validator]
      end

      def unique_columns(array)
        array.each_with_object({}) do |column, hash|
          name = column.first.unwrap
          next if hash.key? name

          hash[name] = column
        end
      end

      def with_required(hash)
        @required_columns.each_with_object(hash) do |name, result|
          next if result.key? name
          column = @columns[name]
          _, tuple = @prototype.from_input([name, column.ordering])
          hash[name] = tuple
        end
      end

      def finish
        raise ParamsReadyError, "No ordering column defined" if @columns.empty?
        set_required_columns
        set_default([]) unless default_defined?
        super
      end

      freeze_variables :columns, :required_columns, :primary_keys, :prototype
    end
  end
end