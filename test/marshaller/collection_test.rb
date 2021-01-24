require_relative '../test_helper'
require_relative '../../lib/params_ready/marshaller/collection'

module ParamsReady
  module Marshaller
    class CollectionTest < Minitest::Test
      def test_added_instance_can_be_retrieved
        fc = ClassCollection.new :foo
        fc.add_instance String, :instance1
        fc.add_instance Array, :instance2

        assert_equal :instance1, fc.instance(String)
        assert_equal :instance2, fc.instance(Array)
        assert_nil fc.instance(Hash)
        assert fc.instance?(String)
        refute fc.instance?(Hash)
      end

      def test_add_instance_fails_if_instance_exists
        fc = ClassCollection.new :foo
        fc.add_instance String, :instance1
        err = assert_raises do
          fc.add_instance String, :instance2
        end
        assert_equal "Marshaller for 'String' already exists", err.message
      end

      def test_add_instance_fails_unless_instance_frozen
        fc = ClassCollection.new :foo
        err = assert_raises do
          fc.add_instance String, 'instance'
        end
        assert_equal "Marshaller must be frozen", err.message
      end

      def test_added_factory_can_be_retrieved
        fc = ClassCollection.new :foo
        fc.add_factory :string, :factory1
        fc.add_factory :array, :factory2

        assert_equal :factory1, fc.factory(:string)
        assert_equal :factory2, fc.factory(:array)
        assert_nil fc.factory(:hash)
        assert fc.factory?(:string)
        refute fc.factory?(:hash)
      end

      def test_add_factory_fails_if_factory_exists
        fc = ClassCollection.new :foo
        fc.add_factory :string, :factory1
        err = assert_raises do
          fc.add_factory :string, :factory2
        end
        assert_equal "Name 'string' already taken", err.message
      end

      def test_add_factory_fails_unless_factory_frozen
        fc = ClassCollection.new :foo
        err = assert_raises do
          fc.add_factory :string, 'factory'
        end
        assert_equal "Factory must be frozen", err.message
      end

      def test_set_default_fails_unless_instance_frozen
        fc = ClassCollection.new :foo
        err = assert_raises do
          fc.default = 'default'
        end
        assert_equal "Marshaller must be frozen", err.message
      end

      def test_set_default_fails_if_already_set
        fc = ClassCollection.new :foo
        fc.default = :default1
        err = assert_raises do
          fc.default = :default2
        end
        assert_equal "Default already defined", err.message
      end

      def test_default_can_be_set_and_retrieved
        fc = ClassCollection.new :foo
        fc.default = :default1
        assert fc.default?
        assert_equal :default1, fc.default
      end

      def test_reverse_merge_works_for_instances
        rec = ClassCollection.new :foo
        rec.add_instance String, :string_to_keep
        rec.add_instance Hash, :hash_instance

        dnr = ClassCollection.new :foo
        dnr.add_instance String, :string_to_omit
        dnr.add_instance Array, :array_instance

        res = rec.reverse_merge(dnr)
        assert_equal :string_to_keep, res.instance(String)
        assert_equal :hash_instance, res.instance(Hash)
        assert_equal :array_instance, res.instance(Array)
      end

      def test_reverse_merge_works_for_factories
        rec = ClassCollection.new :foo
        rec.add_factory :string, :string_to_keep
        rec.add_factory :hash, :hash_factory

        dnr = ClassCollection.new :foo
        dnr.add_factory :string, :string_to_omit
        dnr.add_factory :array, :array_factory

        res = rec.reverse_merge(dnr)
        assert_equal :string_to_keep, res.factory(:string)
        assert_equal :hash_factory, res.factory(:hash)
        assert_equal :array_factory, res.factory(:array)
      end

      def test_reverse_merge_works_for_default
        rec = ClassCollection.new :foo
        rec.default = :default1

        dnr = ClassCollection.new :foo
        dnr.default = :default2

        res = rec.reverse_merge(dnr)
        assert_equal :default1, res.default

        rec = ClassCollection.new :foo
        res = rec.reverse_merge(dnr)
        assert_equal :default2, res.default
      end
    end
  end
end
