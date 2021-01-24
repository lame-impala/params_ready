require 'forwardable'
require_relative 'restriction'
require_relative 'format'
require_relative 'parameter/parameter'

module ParamsReady
  class Intent
    extend Forwardable
    include Restriction::Wrapper
    include Format::Wrapper

    def clone(restriction:)
      Intent.new @format, restriction, data: @data
    end

    attr_reader :data, :hash

    def initialize(format, restriction = Restriction.blanket_permission, data: nil)
      @format = Format.resolve(format).freeze
      raise ParamsReadyError, "Restriction expected, got: #{restriction.inspect}" unless restriction.is_a? Restriction
      @restriction = restriction
      @data = check_data(data)
      @hash = [@format, @restriction, @data].hash
      freeze
    end

    def check_data(data)
      return if data.nil?
      # The reason we require data object to be
      # a Parameter is that it must be deep frozen
      # for the output memoizing feature to work properly.
      raise 'Data object must be a parameter' unless data.is_a? Parameter::Parameter
      raise 'Data object must be frozen' unless data.frozen?

      data
    end

    def omit?(parameter)
      return true unless permitted?(parameter)
      @format.omit?(parameter)
    end

    def preserve?(parameter)
      !omit?(parameter)
    end

    def self.instance(name)
      format = Format.instance(name)
      Intent.new(format)
    end

    def self.resolve(intent_or_name)
      if intent_or_name.is_a? Intent
        intent_or_name
      else
        instance(intent_or_name)
      end
    end

    def ==(other)
      return false unless other.is_a?(Intent)
      return true if object_id == other.object_id
      restriction == other.restriction && format == other.format && data == other.data
    end

    def eql?(other)
      self == other
    end
  end
end
