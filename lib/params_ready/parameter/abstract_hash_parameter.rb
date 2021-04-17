require_relative 'parameter'
require_relative '../helpers/key_map'
require_relative '../marshaller/hash_marshallers'
require_relative '../marshaller/builder_module'
require_relative '../marshaller/definition_module'

module ParamsReady
  module Parameter
    using Extensions::Hash

    class AbstractHashParameter < Parameter
      include ComplexParameter

      def_delegators :@definition, :names, :remap?
      intent_for_children :restriction

      EMPTY_HASH = '0'

      freeze_variable :value do |value|
        next if value.nil? || value == Extensions::Undefined

        value.values.each do |child|
          child.freeze
        end
      end

      def []=(name, value)
        init_for_write
        c = child(name)
        c.set_value(value)
      end

      def [](name)
        child(name)
      end

      def find_in_hash(hash, context)
        found, result = super hash, context

        if !(default_defined? || optional?) && result == Extensions::Undefined
          # nil value for non-default and non-optional hash means
          # children may be able to set themselves if they have defaults
          [true, {}]
        elsif result == EMPTY_HASH
          [true, {}]
        else
          [found, result]
        end
      end

      def wrap_output(output, intent)
        if (output.nil? || output.empty?) && !default_defined? && !optional?
          nil
        else
          super
        end
      end

      def for_output(format, restriction: nil, data: nil)
        restriction ||= Restriction.blanket_permission

        intent = Intent.new(format, restriction, data: data)
        output = format(intent)
        return {} if output.nil? || output == EMPTY_HASH
        output
      end

      def for_frontend(format = :frontend, restriction: nil, data: nil)
        for_output(format, restriction: restriction, data: data)
      end

      def for_model(format = :update, restriction: nil)
        for_output(format, restriction: restriction)
      end

      protected

      def child_for_update(path)
        child_name, *path = path
        [self[child_name], child_name, path]
      end

      def updated_clone(name, updated)
        clone = definition.create
        frozen = frozen? || @value&.frozen?
        clone.populate_with(bare_value, frozen, name => updated)
      end

      def child(name)
        return nil if is_nil?

        value = bare_value
        raise ParamsReadyError, "No such name: #{name}" unless names.key? name
        if value.key? name
          value[name]
        else
          child = definition.child_definition(name).create
          raise ParamsReadyError, "Expected definite value for '#{name}' parameter" if child.nil?
          place(name, child) unless frozen?
          child
        end
      end

      def populate_with(hash, freeze = false, **replacement)
        @value = {}
        names.each_key do |name|
          incoming = replacement[name] || hash[name]

          own = if freeze && incoming.frozen?
            incoming
          else
            incoming.dup
          end

          own.freeze if freeze

          place(name, own)
        end

        self.freeze if freeze
        self
      end

      def place(name, child)
        @value[name] = child
      end

      def init_value
        @value = names.map do |name, definition|
          [name, definition.create]
        end.to_h
      end
    end

    module AbstractHashParameterBuilder
      include Marshaller::BuilderModule

      module HashLike
        def add(input, *args, **opts, &block)
          definition = self.class.resolve(input, *args, **opts, &block)
          @definition.add_child definition
        end
      end
    end

    class AbstractHashParameterDefinition < Definition
      attr_reader :key_map

      def duplicate_value(value)
        value.values.map do |param|
          [param.name, param.dup]
        end.to_h
      end

      def freeze_value(value)
        value.values.each(&:freeze)
        value.freeze
      end

      attr_reader :names

      def initialize(*args, **options)
        super *args, **options
        @key_map = nil
        @names = {}
      end

      def child_definition(name)
        raise ParamsReadyError, "No such name: #{name}" unless names.key? name
        names[name]
      end

      def has_child?(name)
        names.key? name
      end

      def set_default(value)
        value = infer_default if value == :inferred
        super(value)
      end

      def infer_default
        names.reduce({}) do |result, pair|
          child_def = pair[1]
          unless child_def.default_defined?
            raise ParamsReadyError, "Can't infer default, child '#{definition.name}' is not optional and has no default" unless child_def.optional?
          else
            result[child_def.name] = child_def.default
          end
          result
        end
      end

      def add_child(child)
        raise ParamsReadyError, "Not a parameter definition: '#{child.class.name}'" unless child.is_a?(AbstractDefinition)
        raise ParamsReadyError, "Name already there: '#{child.name}'" if @names.key?(child.name)
        raise ParamsReadyError, "Child can't be added after default has been set" if default_defined?
        @names[child.name] = child
      end

      freeze_variables :names
    end
  end
end