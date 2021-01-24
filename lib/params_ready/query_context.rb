require 'forwardable'
require_relative 'restriction'

module ParamsReady
  class QueryContext
    include Restriction::Wrapper
    extend Forwardable
    attr_reader :data
    def_delegator :data, :[]

    def initialize(restriction, data = {})
      @data = data.freeze
      raise ParamsReadyError, "Restriction expected, got: #{restriction.inspect}" unless restriction.is_a? Restriction
      @restriction = restriction.freeze
    end

    def clone(restriction:)
      QueryContext.new restriction, data
    end
  end
end
