require_relative 'parameter'
require_relative 'definition'
require_relative 'abstract_struct_parameter'
require_relative '../builder'
require_relative '../marshaller/array_marshallers'
require_relative '../marshaller/builder_module'
require_relative '../marshaller/definition_module'
require_relative '../marshaller/parameter_module'

module ParamsReady
  module Parameter
    class ArrayParameter < Parameter
      module ArrayLike
        include ComplexParameter

        def []=(index, value)
          init_for_write
          c = element(index)
          c.set_value value
        end

        def [](index)
          if index == :cnt || index == 'cnt'
            count = ValueParameterBuilder.instance(:cnt, :integer).build.create
            count.set_value(self.length)
            count.freeze
            count
          else
            element(index)
          end
        end

        protected

        def updated_clone(index, updated_child)
          clone = definition.create
          clone.populate_with(bare_value, frozen?, { index => updated_child })
          clone
        end

        def child_for_update(path)
          index, *child_path = path
          child = element(index)
          raise ParamsReadyError, "No element at index '#{index}' in '#{name}'" if child.nil?
          [child, index, child_path]
        end

        def populate_with(array, freeze = false, replacement = {})
          @value = []
          array.each_with_index do |element, index|
            incoming = replacement[index] || element

            own = if freeze && incoming.frozen?
              incoming
            else
              incoming.dup
            end

            own.freeze if freeze

            @value << own
          end

          self.freeze if freeze
          self
        end
      end

      include ArrayLike
      include Marshaller::ParameterModule

      intent_for_children :delegate do
        definition.prototype.name
      end

      def_delegators :@definition, :prototype
      def_delegators :bare_value, :length, :count, :each, :each_with_index, :map, :reduce, :to_a

      freeze_variable :value do |array|
        array.each(&:freeze)
      end

      def <<(value)
        init_for_write
        c = element(length, for_write: true)
        c.set_value value
        self
      end

      protected

      def element(index, for_write: false)
        return nil if is_nil?

        value = bare_value
        if value.length > index
          value[index]
        elsif value.length == index && for_write
          value << prototype.create
          value[index]
        else
          nil
        end
      end

      def init_value
        @value = []
      end
    end

    class ArrayParameterBuilder < Builder
      module ArrayLike
        def prototype(input, name = nil, *args, altn: nil, **opts, &block)
          name ||= :element
          altn ||= :elm
          definition = self.class.resolve(input, name, *args, altn: altn, **opts, &block)
          @definition.set_prototype definition
        end
      end

      include ArrayLike
      register :array
      include Marshaller::BuilderModule

      def self.instance(name, altn: nil)
        new ArrayParameterDefinition.new(name, altn: altn)
      end

      def compact
        @definition.set_compact true
      end
    end

    class ArrayParameterDefinition < Definition
      name_for_formatter :array
      include Marshaller::DefinitionModule[Marshaller::ArrayMarshallers.collection]

      module ArrayLike
        def duplicate_value(value)
          value.map do |param|
            param.dup
          end
        end

        def freeze_value(value)
          value.each(&:freeze)
          value.freeze
        end
      end

      include ArrayLike

      parameter_class ArrayParameter

      def initialize(*args, prototype: nil, **options)
        raise ParamsReadyError, "Not a definition: #{prototype.class.name}" unless (prototype.is_a?(Definition) || prototype.nil?)
        @prototype = prototype
        super *args, **options
      end

      def set_default(args)
        raise ParamsReadyError, "Can't set default before prototype has been defined" if @prototype.nil?
        super
      end

      late_init :prototype do |prototype|
        raise ParamsReadyError, "Can't set prototype after default has been set" if default_defined?
        prototype
      end

      late_init :compact, obligatory: false, boolean: true, getter: false

      def ensure_canonical(array)
        raise "Not a canonical value, array expected, got: '#{array.class.name}'" unless array.is_a? Array
        context = Format.instance(:backend)
        value, _validator = try_canonicalize(array, context, nil, freeze: true)
        value
      end

      def try_canonicalize(value, context, validator = nil, freeze: false)
        if freeze
          marshaller = marshallers.instance(Array)
          marshaller.canonicalize self, value, context, validator, freeze: freeze
        else
          super value, context, validator
        end
      end

      def finish
        if compact? && (prototype&.default_defined?)
          raise ParamsReadyError, 'Prototype must not be optional nor have default in compact array parameter'
        end
        super
      end
    end
  end
end