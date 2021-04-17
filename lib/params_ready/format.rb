require 'set'
require_relative 'error'
require_relative 'helpers/rule'

module ParamsReady
 class Format
    module Wrapper
      attr_reader :format

      extend Forwardable
      def_delegators :format,
                     :alternative?,
                     :standard?,
                     :hash_key,
                     :marshal,
                     :marshal?,
                     :remap?,
                     :local?,
                     :name
    end

    attr_reader :marshal, :naming_scheme, :name, :hash

    OMIT_ALL = %i(undefined nil default no_output).freeze
    def initialize(marshal:, naming_scheme:, remap:, omit:, local:, name: nil)
      @marshal = Helpers::Rule(marshal)
      @naming_scheme = naming_scheme
      @remap = remap
      @omit = omit.to_set.freeze
      @local = local
      @name = name.nil? ? name : name.to_sym
      @hash = [@marshal, @naming_scheme, @remap, @omit, @local, @name].hash
      freeze
    end

    def ==(other)
      return false unless other.is_a? Format
      return true if self.object_id == other.object_id
      return false unless marshal == other.marshal
      return false unless naming_scheme == other.naming_scheme
      return false unless remap? == other.remap?
      return false unless @omit == other.instance_variable_get(:@omit)
      return false unless local? == other.local?
      return false unless name == other.name

      true
    end

    def alternative?
      @naming_scheme == :alternative
    end

    def standard?
      @naming_scheme == :standard
    end

    def remap?
      @remap
    end

    def hash_key(parameter)
      case @naming_scheme
      when :standard then parameter.name
      when :alternative then parameter.altn
      else
        raise ParamsReadyError, "Unexpected option: #{@naming_scheme}"
      end
    end

    def omit?(parameter)
      return true if parameter.no_output?(self)
      return true if parameter.is_undefined? && @omit.member?(:undefined)
      return true if parameter.is_nil? && @omit.member?(:nil)
      return true if parameter.is_default? && @omit.member?(:default)
      false
    end

    def local?
      @local
    end

    def preserve?(parameter)
      !omit?(parameter)
    end

    def marshal?(type)
      @marshal.include?(type)
    end

    def update(**opts)
      opts = instance_variables.reject { |ivar| ivar == :@hash }.map do |ivar|
        value = instance_variable_get(ivar)
        name = ivar.to_s.gsub(/^@/, '').to_sym
        [name, value]
      end.to_h.merge(opts)

      Format.new(**opts)
    end

    @names = {
      backend: Format.new(marshal: :none, omit: [], naming_scheme: :standard, remap: false, local: true, name: :backend),
      frontend: Format.new(marshal: :all, omit: OMIT_ALL, naming_scheme: :alternative, remap: false, local: false, name: :frontend),
      create: Format.new(marshal: :none, omit: [], naming_scheme: :standard, remap: false, local: true, name: :create),
      update: Format.new(marshal: :none, omit: %i(undefined), naming_scheme: :standard, remap: false, local: true, name: :update),
      json: Format.new(marshal: { except: [:array, :tuple, :boolean, :number] }, omit: [], naming_scheme: :alternative, remap: true, local: false, name: :json),
      inspect: Format.new(marshal: :none, omit: [], naming_scheme: :standard, remap: false, local: false, name: :inspect)
    }.freeze

    def self.define(name, format)
      @names = @names.dup
      @names[name] = format
      @names.freeze
    end

    def self.instance(name)
      raise ParamsReadyError, "Unknown format '#{name}'" unless @names.key? name
      @names[name]
    end

    def self.resolve(format_or_name)
      if format_or_name.is_a? Format
        format_or_name
      elsif format_or_name.is_a? Symbol
        instance(format_or_name)
      elsif format_or_name.respond_to? :format
        format_or_name.format
      else
        raise ParamsReadyError, "Not an acceptable format: #{format_or_name}"
      end
    end
  end
end
