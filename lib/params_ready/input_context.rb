require 'forwardable'
require_relative 'format'

module ParamsReady
  class InputContext
    include Format::Wrapper
    extend Forwardable

    attr_reader :data

    def_delegator :data, :[]

    def initialize(format, data = {})
      @format = Format.resolve(format).freeze
      @data = data.freeze
    end

    def self.resolve(unknown)
      case unknown
      when nil
        Format.instance(:frontend)
      when InputContext, Format
        unknown
      when Symbol
        Format.instance(unknown)
      else
        raise ParamsReadyError, "Unexpected type for InputContext: #{unknown.class.name}"
      end
    end
  end
end
