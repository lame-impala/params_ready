require_relative 'extensions/registry'
require_relative 'helpers/rule'

module ParamsReady
  class AbstractBuilder
    module HavingArelTable
      def arel_table(arel_table)
        @definition.set_arel_table arel_table
      end
    end

    module HavingModel
      def model(model_class)
        @definition.set_model_class model_class
      end
    end

    extend Extensions::Registry
    registry :builders, as: :builder, getter: true do |name, _|
      full_name = "define_#{name}"
      raise ParamsReadyError, "Reserved name: #{full_name}" if method_defined?(full_name)
      Builder.define_singleton_method(full_name) do |*args, **opts, &block|
        define_parameter(name, *args, **opts, &block)
      end
    end

    def self.register(name)
      register_builder(name, self)
    end

    def self.define_parameter(type, *args, **opts, &block)
      builder_class = builder(type)
      builder = builder_class.instance(*args, **opts)
      builder.include(&block) unless block.nil?
      builder.build
    end

    def self.define_registered_parameter(name, *args, **opts, &block)
      full_name = "define_#{name}"
      send(full_name, *args, **opts, &block)
    end

    def self.resolve(input, *args, **opts, &block)
      if input.is_a? Parameter::AbstractDefinition
        input
      else
        define_registered_parameter(input, *args, **opts, &block)
      end
    end

    def self.instance(*args, **opts)
      new *args, **opts
    end

    private_class_method :new

    def initialize(definition)
      @definition = definition
    end

    def include(&block)
      instance_eval(&block)
      self
    end

    def fetch
      d = @definition
      @definition = nil
      d
    end

    def build
      @definition.finish
      @definition
    end

    def open?
      return false if @definition.nil?
      return false if @definition.frozen?

      true
    end

    module HavingValue
      def optional
        @definition.set_optional true
      end

      def default(val)
        @definition.set_default(val, **{})
      end

      def no_output(rule: nil)
        @definition.set_no_output Helpers::Rule(rule) || true
      end

      def no_input(*arr, rule: nil)
        @definition.set_no_input *arr, rule: rule
      end

      def local(*arr, rule: nil)
        @definition.set_local *arr, rule: rule
      end

      def preprocess(rule: nil, &block)
        @definition.set_preprocessor rule: rule, &block
      end

      def populate(&block)
        @definition.set_populator block
      end

      def postprocess(rule: nil, &block)
        @definition.set_postprocessor rule: rule, &block
      end

      def marshal(*args, **opts)
        @definition.set_marshaller(*args, **opts)
      end

      def memoize(slots = 1)
        @definition.set_memoize(slots)
      end
    end
  end

  class Builder < AbstractBuilder
    include HavingValue

    def helper(name, &block)
      @definition.add_helper [name, block]
    end
  end

  module DelegatingBuilder
    def self.[](delegee_name)
      mod = Module.new
      Extensions::Delegation.delegate(mod) do
        @definition.send(delegee_name)
      end
      mod
    end
  end
end
