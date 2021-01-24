module ParamsReady
  module Marshaller
    module DefinitionModule
      def self.[](collection)
        mod = Module.new
        mod.include self
        mod.define_method :class_marshallers do
          collection
        end
        mod
      end

      attr_reader :marshallers

      def initialize(*args, marshaller: nil, **options)
        @marshallers = class_marshallers.instance_collection
        set_marshaller(**marshaller) unless marshaller.nil?

        super *args, **options
      end

      def set_marshaller(to: nil, using: nil, **opts)
        if using.is_a? Symbol
          raise ParamsReadyError, "Expected ':to' argument to be nil, got #{to.class.name}" unless to.nil?
          default_class, instance = class_marshallers.build_instance(using, **opts)
          @marshallers.add_instance(default_class, instance)
          @marshallers.default!(default_class)
        elsif using.nil?
          @marshallers.default!(to)
        else
          @marshallers.add_instance(to, using)
          @marshallers.default!(to)
        end
      end

      def marshal(parameter, intent, **opts)
        if intent.marshal?(name_for_formatter)
          @marshallers.marshal(parameter, intent, **opts)
        else
          @marshallers.marshal_canonical(parameter, intent, **opts)
        end
      end

      def try_canonicalize(input, context, validator = nil, **opts)
        @marshallers.canonicalize(self, input, context, validator, **opts)
      end

      def finish
        unless @marshallers.default?
          if class_marshallers.default?
            @marshallers.default = class_marshallers.default
          end
        end
        super
      end

      def freeze
        @marshallers.freeze
        super
      end
    end
  end
end
