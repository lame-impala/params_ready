require_relative '../extensions/freezer'
require_relative '../extensions/finalizer'
require_relative '../error'
require_relative '../extensions/class_reader_writer'
require_relative '../extensions/collection'
require_relative '../extensions/delegation'
require_relative '../extensions/late_init'
require_relative '../extensions/undefined'
require_relative '../input_context'
require_relative '../result'
require_relative '../helpers/conditional_block'

module ParamsReady
  module Parameter
    class AbstractDefinition
      extend Extensions::Freezer
      include Extensions::Freezer::InstanceMethods
      extend Extensions::Finalizer
      include Extensions::Finalizer::InstanceMethods
      extend Extensions::ClassReaderWriter
      extend Extensions::LateInit
      extend Extensions::Collection

      attr_reader :name, :altn

      def parameter_class
        self.class.parameter_class
      end

      def initialize(name, altn: nil)
        @name = name.to_sym
        @altn = normalize_alternative_name(altn || name)
      end

      def normalize_alternative_name(name)
        if name.is_a? Array
          name.map(&:to_sym)
        else
          name.to_sym
        end
      end

      class_reader_writer :parameter_class
      collection :helpers, :helper

      def create
        raise ParamsReadyError, "Can't create '#{name}' using unfrozen definition" unless frozen?
        instance = parameter_class.new self
        if @helpers
          singleton = class << instance; self; end
          @helpers.each do |(name, block)|
            if singleton.method_defined? name
              raise ParamsReadyError, "Helper '#{name}' overrides existing method"
            end

            singleton.send :define_method, name, &block
          end
        end
        instance
      end

      def from_hash(hash, context: nil, validator: Result.new(name))
        context = InputContext.resolve(context)
        instance = create
        result = instance.set_from_hash(hash, context: context, validator: validator)
        [result, instance]
      end

      def from_input(input, context: nil, validator: nil)
        validator ||= Result.new(name)
        context = InputContext.resolve(context)
        instance = create
        result = instance.set_from_input(input, context, validator)
        [result, instance]
      end

      def finish
        super
        freeze
      end
    end

    class Definition < AbstractDefinition
      attr_reader :default

      class_reader_writer :name_for_formatter

      def name_for_formatter
        self.class.name_for_formatter
      end

      def initialize(
        *args,
        default: Extensions::Undefined,
        optional: false,
        preprocessor: nil,
        populator: nil,
        postprocessor: nil,
        local: false,
        no_output: nil,
        **opts
      )
        super *args, **opts
        @default = Extensions::Undefined
        @optional = optional
        @preprocessor = preprocessor
        @postprocessor = postprocessor
        @populator = populator
        @local = local
        @no_output = no_output

        set_default(default) unless default == Extensions::Undefined
      end

      def default_defined?
        return false unless defined? @default
        return false if @default == Extensions::Undefined
        true
      end

      def canonical_default(value)
        return value if value.nil?
        ensure_canonical value
      rescue => e
        raise ParamsReadyError, "Invalid default: #{e.message}"
      end

      late_init :populator, getter: true, once: true, obligatory: false
      late_init :no_output, getter: false, once: false
      late_init :memoize, getter: true, obligatory: false

      def memoize?
        return false if @memoize.nil?

        @memoize > 0
      end

      def set_preprocessor(rule: nil, &block)
        raise "Preprocesser already set in '#{name}'" unless @preprocessor.nil?
        @preprocessor = Helpers::ConditionalBlock.new(rule: rule, &block)
      end

      def set_postprocessor(rule: nil, &block)
        raise "Postprocessor already set in '#{name}'" unless @postprocessor.nil?
        @postprocessor = Helpers::ConditionalBlock.new(rule: rule, &block)
      end

      def preprocess(input, context, validator)
        return input if @preprocessor.nil?
        return input unless @preprocessor.perform?(!context.local?, context.name)
        @preprocessor.block.call input, context, self
      rescue => error
        preprocessor_error = PreprocessorError.new(error)
        if validator.nil?
          raise preprocessor_error
        else
          validator.error! preprocessor_error
          Extensions::Undefined
        end
      end

      def postprocess(param, context, validator)
        return if @postprocessor.nil?
        return unless @postprocessor.perform?(!context.local?, context.name)
        @postprocessor.block.call param, context
      rescue => error
        postprocessor_error = PostprocessorError.new(error)
        if validator.nil?
          raise postprocessor_error
        else
          validator.error! postprocessor_error
        end
        validator
      end

      def set_local(*arr, rule: nil)
        if rule.nil?
          @local = true
        else
          @local = Helpers::Rule(rule)
        end
        set_default *arr unless arr.empty?
      end

      def local?(format)
        case @local
        when nil, false
          false
        when true
          !format.local?
        when Helpers::Rule
          @local.include? format.name
        else
          raise ParamsReadyError, "Unexpected rule: #{@local}"
        end
      end

      def no_output?(format)
        case @no_output
        when nil, false
          return local?(format)
        when true
          return !format.local?
        when Helpers::Rule
          @no_output.include? format.name
        else
          raise ParamsReadyError, "Unexpected option: '#{@no_output}'"
        end
      end

      late_init :optional, boolean: true, getter: false, once: false do |value|
        next value if value == false
        raise ParamsReadyError, "Optional parameter can't have default" if default_defined?

        value
      end

      late_init :default, once: false, definite: false do |value|
        next value if value == Extensions::Undefined

        raise ParamsReadyError, "Optional parameter can't have default" if optional?

        canonical = canonical_default(value)
        next canonical if canonical.nil?

        freeze_value(canonical)
      end

      def duplicate_default
        return Extensions::Undefined unless default_defined?
        return nil if @default.nil?

        duplicate_value(@default)
      end


      def finish
        if @populator && !@local
          raise ParamsReadyError, "Populator set for non-local parameter '#{name}'"
        end

        if @preprocessor && @local
          raise ParamsReadyError, "Preprocessor set for local parameter '#{name}'"
        end

        if @postprocessor && @local
          raise ParamsReadyError, "Postprocessor set for local parameter '#{name}'"
        end

        super
      end
    end

    module DelegatingDefinition
      def self.[](delegee_name)
        mod = Module.new
        Extensions::Delegation.delegate(mod) do
          instance_variable_get(:"@#{delegee_name}")
        end
        mod
      end
    end
  end
end