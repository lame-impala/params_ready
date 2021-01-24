module ParamsReady
  module Extensions
    module Hash
      refine ::Hash do
        def deep_merge(other)
          merger = proc { |_, v1, v2| ::Hash === v1 && ::Hash === v2 ? v1.merge(v2, &merger) : v2 }
          merge(other, &merger)
        end
      end

      def self.try_deep_freeze(object)
        if object.is_a? ::Hash
          object.values.each do |value|
            try_deep_freeze(value)
          end
        end
        object.freeze
        object
      end

      def self.acts_as_hash?(object)
        return false unless object.respond_to? :[]
        return false unless object.respond_to? :key?
        return false unless object.respond_to? :fetch

        true
      end

      def self.indifferent_access(hash, key, default)
        hash.fetch(key) do
          case key
          when String
            hash.fetch(key.to_sym, default)
          when Symbol
            hash.fetch(key.to_s, default)
          else
            string_key = key.to_s
            hash.fetch(string_key) do
              hash.fetch(string_key.to_sym, default)
            end
          end
        end
      end
    end
  end
end
