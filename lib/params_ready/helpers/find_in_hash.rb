require_relative '../extensions/undefined'
require_relative 'key_map'

module ParamsReady
  module Helpers
    module FindInHash
      def self.find_in_hash(hash, name_or_path)
        return false, Extensions::Undefined if hash.nil?

        found = if name_or_path.is_a? Array
          *path, name = name_or_path
          Helpers::KeyMap::Mapping::Path.dig(name, hash, path)
        else
          Extensions::Hash.indifferent_access(hash, name_or_path, Extensions::Undefined)
        end

        return false, Extensions::Undefined if found == Extensions::Undefined
        return true, found
      end
    end
  end
end