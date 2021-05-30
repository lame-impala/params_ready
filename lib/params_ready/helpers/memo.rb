require_relative '../extensions/undefined'
require_relative '../extensions/hash'



module ParamsReady
  module Helpers
    class Memo
      def initialize(slots = 1)
        raise ParamsReadyError, "Expected positive value for number of slots, got: '#{slots}'" unless slots > 0
        @slots = slots
        @cache = nil
      end

      def cached_value(key)
        cache = @cache
        return Extensions::Undefined if cache.nil?
        return Extensions::Undefined unless cache.key? key

        cache[key]
      end

      def cache_value(value, key)
        stale = @cache
        return if stale&.key? key

        frozen = Extensions::Hash.try_deep_freeze(value)

        fresh = if stale.nil? || @slots == 1
          { key => frozen }
        else
          kept = stale.to_a.last(@slots - 1)

          [*kept, [key, frozen]].to_h
        end

        @cache = fresh.freeze
      end
    end
  end
end