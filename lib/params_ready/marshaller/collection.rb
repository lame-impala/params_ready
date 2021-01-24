require_relative '../error'
require_relative '../extensions/hash'

module ParamsReady
  module Marshaller
    class InstanceCollection
      attr_reader :default, :instances

      def initialize(canonical, default = nil, instances = {})
        @canonical = canonical
        @default = default
        @instances = instances
      end

      def canonicalize(definition, input, context, validator, **opts)
        value_class = infer_class(input)
        marshaller = instance(value_class)
        raise ParamsReadyError, "Unexpected type for #{definition.name}: #{value_class.name}" if marshaller.nil?

        marshaller.canonicalize(definition, input, context, validator, **opts)
      end

      def marshal_canonical(parameter, format, **opts)
        marshaller = instance @canonical
        if marshaller.nil?
          value = parameter.send(:bare_value)
          raise ParamsReadyError, "Value is not canonical" unless value.is_a? @canonical
          value
        else
          marshaller.marshal(parameter, format, **opts)
        end
      end

      def marshal(parameter, format, **opts)
        default.marshal(parameter, format, **opts)
      end

      def infer_class(value)
        if instances.key? value.class
          value.class
        elsif value.is_a?(Hash) || Extensions::Hash.acts_as_hash?(value)
          Hash
        else
          value.class
        end
      end

      def add_instance(value_class, instance)
        raise ParamsReadyError, "Marshaller must be frozen" unless instance.frozen?

        @instances[value_class] = instance
      end

      def instance(value_class)
        @instances[value_class]
      end

      def instance?(value_class)
        @instances.key?(value_class)
      end

      def default=(instance)
        raise ParamsReadyError, "Default already defined" if default?
        raise ParamsReadyError, "Marshaller must be frozen" unless instance.frozen?

        @default = instance
      end

      def default!(value_class)
        instance = instance(value_class)
        raise ParamsReadyError, "No marshaller for class '#{value_class.name}'" if instance.nil?
        self.default = instance
      end

      def default?
        !@default.nil?
      end

      def reverse_merge(other)
        clone = self.class.new(@canonical, @default, @instances.dup)
        populate_clone(clone, other)
      end

      def populate_clone(clone, other)
        if other.default? && !clone.default?
          clone.default = other.default
        end

        other.instances.each do |value_class, i|
          next if clone.instance?(value_class)

          clone.add_instance value_class, i
        end

        clone
      end

      def freeze
        @instance.freeze
        super
      end
    end

    class ClassCollection < InstanceCollection
      attr_reader :factories

      def initialize(canonical, default = nil, instances = {}, factories = {})
        @factories = factories
        super canonical, default, instances
      end

      def instance_collection
        InstanceCollection.new(@canonical, nil, @instances.dup)
      end

      def add_factory(name, factory)
        name = name.to_sym
        raise ParamsReadyError, "Name '#{name}' already taken" if factory?(name)
        raise ParamsReadyError, "Factory must be frozen" unless factory.frozen?

        @factories[name] = factory
      end

      def add_instance(value_class, instance)
        raise ParamsReadyError, "Marshaller for '#{value_class.name}' already exists" if instance?(value_class)

        super
      end

      def build_instance(name, **opts)
        factory(name).instance(**opts)
      end

      def factory(name)
        @factories[name]
      end

      def factory?(name)
        @factories.key? name
      end

      def freeze
        @factories.freeze
        super
      end

      def reverse_merge(other)
        clone = self.class.new(@canonical, @default, @instances.dup, @factories.dup)
        populate_clone(clone, other)
      end

      def populate_clone(clone, other)
        merged = super

        other.factories.each do |value_class, f|
          next if merged.factory?(value_class)

          clone.add_factory value_class, f
        end

        merged
      end
    end
  end
end
