require_relative 'parameter'
require_relative 'polymorph_parameter'
require_relative 'value_parameter'
require_relative '../marshaller/parameter_module'
require_relative '../marshaller/definition_module'
require_relative '../marshaller/builder_module'
require_relative '../marshaller/polymorph_marshallers'

module ParamsReady
  module Parameter
    class PolymorphParameter < Parameter
      include ComplexParameter
      include Marshaller::ParameterModule

      def_delegators :@definition, :identifier, :types
      intent_for_children :restriction

      def permission_depends_on
        type = to_type
        return [] if type.nil?
        [type]
      end

      def set_value_as(value, type, context = Format.instance(:backend), validator = nil)
        parameter = types[type].create
        parameter.set_value value, context, validator
        @value = parameter
      end

      def type
        return nil unless is_definite?
        bare_value.name
      end

      def to_type
        bare_value
      end

      def [](key)
        raise ParamsReadyError, "Type '#{key}' is not set, current type: nil" if is_nil?

        param = bare_value
        if param.name != key
          raise ParamsReadyError, "Type '#{key}' is not set, current type: '#{param.name}'"
        else
          param
        end
      end

      protected

      def child_for_update(path)
        type, *path = path
        [self[type], type, path]
      end

      def updated_clone(_child_name, updated)
        clone = definition.create
        clone.populate_with(updated, frozen?)
        clone
      end

      def populate_with(value, freeze = false)
        @value = if freeze && value.frozen?
          value
        else
          value.dup
        end

        self.freeze if freeze
        self
      end
    end

    class PolymorphParameterBuilder < Builder
      include Marshaller::BuilderModule

      register :polymorph

      def self.instance(name, altn: nil)
        new PolymorphParameterDefinition.new(name, altn: altn)
      end

      def type(input, *args, **opts, &block)
        definition = self.class.resolve(input, *args, **opts, &block)
        @definition.add_type definition
      end

      def identifier(identifier)
        @definition.set_identifier identifier
      end
    end

    class PolymorphParameterDefinition < Definition
      include ValueParameterDefinition::ValueLike
      include Marshaller::DefinitionModule[Marshaller::PolymorphMarshallers.collection]

      obligatory! :types
      attr_reader :types
      # late_init :identifier, obligatory: true

      parameter_class PolymorphParameter
      name_for_formatter :polymorph

      def initialize(*args, identifier: nil, types: [], default_name: nil, **options)
        @types = {}
        @alt_names = {}
        add_types types
        set_default(default_name)
        super *args, **options
        set_identifier identifier unless identifier.nil?
      end

      def add_type(definition)
        check_type_names(definition)
        raise ParamsReadyError, "Reused name: #{definition.name}" if @types.key? definition.name
        raise ParamsReadyError, "Reused alternative: #{definition.altn}" if @alt_names.key? definition.altn
        @types[definition.name] = definition
        @alt_names[definition.altn] = definition
      end

      def check_type_names(definition)
        return if @marshallers.nil?
        return unless @marshallers.default?
        default = @marshallers.default
        return unless default.respond_to? :reserved?

        raise ParamsReadyError, "Reserved name: #{definition.name}" if default.reserved?(definition.name)
        raise ParamsReadyError, "Reserved alternative: #{definition.altn}" if default.reserved?(definition.altn)
      end

      def add_types(types)
        return if types.nil?
        types.each do |definition|
          add_type definition
        end
      end

      def set_identifier(type_identifier)
        raise ParamsReadyError, "Identifier already taken: #{type_identifier}" if @alt_names&.key?(type_identifier)
        raise ParamsReadyError, "Identifier already taken: #{type_identifier}" if @types&.key?(type_identifier)
        set_marshaller using: :hash, type_identifier: type_identifier
      end

      def type(name, context)
        name = if context.alternative?
          @alt_names[name.to_sym].name
        else
          name
        end
        @types[name.to_sym]
      end

      def set_default(default_name)
        return if default_name.nil?

        type_def = types[default_name]
        raise ParamsReadyError, "Unknown type '#{default_name}'" if type_def.nil?
        raise ParamsReadyError, "Default type must have default" unless type_def.default_defined?
        frozen = freeze_value(type_def.create)
        @default = frozen
      end

      def finish
        set_identifier :ppt unless marshallers.default?
        super
      end

      freeze_variables :types
    end
  end
end