require_relative '../error'
require_relative '../extensions/undefined'
require_relative '../extensions/hash'

module ParamsReady
  module Helpers
    class KeyMap
      class Mapping
        class Path
          attr_reader :path, :names

          def initialize(path, names = [])
            @path = path.map(&:to_sym).freeze
            @names = names
          end

          def add_names(names)
            names.each{ |name| add_name(name) }
          end

          def add_name(name)
            @names << name
          end

          def dig(name, hash)
            self.class.dig(name, hash, @path)
          end

          def self.dig(name, hash, path)
            result = path.reduce(hash) do |current, name|
              next unless Extensions::Hash.acts_as_hash?(current)

              Extensions::Hash.indifferent_access current, name, nil
            end

            return Extensions::Undefined unless Extensions::Hash.acts_as_hash?(result)

            Extensions::Hash.indifferent_access result, name, Extensions::Undefined
          end

          def store(name, value, hash)
            self.class.store(name, value, hash, @path)
          end

          def self.store(name, value, hash, path)
            return if value == Extensions::Undefined

            result = path.reduce(hash) do |current, name|
              current[name] ||= {}
              current[name]
            end

            result[name] = value
            result
          end

          def =~(other)
            raise ParamsReadyError, "Can't match path with #{other.class.name}" unless other.is_a? Path
            path == other.path
          end

          def ==(other)
            raise ParamsReadyError, "Can't compare path with #{other.class.name}" unless other.is_a? Path
            path == other.path && names == other.names
          end
        end

        def initialize(alt_path, alt_names, std_path, std_names)
          if alt_names.length != std_names.length
            msg = "Expected equal number of alternative and standard names, got #{alt_names.length}/#{std_names.length}"
            raise ParamsReadyError, msg
          end

          @alt = Path.new(alt_path, alt_names)
          @std = Path.new(std_path, std_names)
        end

        def add_names(altn, stdn)
          @alt.add_name altn
          @std.add_name stdn
        end

        def remap(from, to, input, target)
          path(from).names.each_with_index do |input_name, idx|
            value = dig(from, input_name, input)
            target_name = path(to).names[idx]
            store(to, target_name, value, target)
          end
        end

        def merge!(other)
          raise ParamsReadyError, "Can't merge non_matching mapping" unless self =~ other

          @alt.add_names(other.alt.names)
          @std.add_names(other.std.names)
        end

        def dig(schema, name, hash)
          path(schema).dig(name, hash)
        end

        def store(schema, name, value, hash)
          path(schema).store(name, value, hash)
        end

        def path(schema)
          case schema
          when :alt then @alt
          when :std then @std
          else
            raise ParamsReadyError, "Unexpected naming schema: #{schema}"
          end
        end

        def =~(other)
          raise ParamsReadyError, "Can't match path with #{other.class.name}" unless other.is_a? Mapping
          return false unless path(:alt) =~ other.path(:alt)
          return false unless path(:std) =~ other.path(:std)

          true
        end

        protected
        attr_reader :alt, :std
      end

      def initialize
        @mappings = []
      end

      def map(from, to:)
        alt_path, alt_names = self.class.split_map(from)
        std_path, std_names = self.class.split_map(to)
        mapping = Mapping.new(alt_path, alt_names, std_path, std_names)
        merge_or_add_mapping(mapping)
        self
      end

      def merge_or_add_mapping(mapping)
        if (existing = @mappings.find { |candidate| candidate =~ mapping })
          existing.merge!(mapping)
        else
          @mappings << mapping
        end
        mapping
      end

      def to_standard(hash)
        remap(:alt, :std, hash)
      end

      def to_alternative(hash)
        remap(:std, :alt, hash)
      end

      def remap(from, to, input)
        @mappings.each_with_object({}) do |mapping, result|
          mapping.remap(from, to, input, result)
        end
      end

      def freeze
        @mappings.each(&:freeze)
        super
      end

      def self.split_map(array)
        raise ParamsReadyError, "Array expected, got: #{array.class.name}" unless array.is_a? Array
        names = array.last || []
        raise ParamsReadyError, "Array expected, got: #{names.class.name}" unless names.is_a? Array
        paths = array[0...-1]
        [paths, names]
      end
    end
  end
end