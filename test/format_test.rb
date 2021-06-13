require_relative 'test_helper'
require_relative '../lib/params_ready/format'

module ParamsReady
  class FormatTest < Minitest::Test
    def test_update_without_params_returns_clone
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :test)
      updated = f.update
      assert_equal(f.instance_variable_get(:@marshal), updated.instance_variable_get(:@marshal))
      assert_equal([:undefined].to_set, updated.instance_variable_get(:@omit))
      assert_equal(:alternative, updated.instance_variable_get(:@naming_scheme))
      assert_equal(true, updated.instance_variable_get(:@remap))
    end

    def test_update_with_params_returns_updated_object
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      updated = f.update(marshal: { except: [:array] }, omit: [:nil, :undefined], naming_scheme: :standard, remap: false, local: true, name: :new)
      assert_equal(Helpers::Rule.instance(except: [:array]), updated.instance_variable_get(:@marshal))
      assert_equal([:nil, :undefined].to_set, updated.instance_variable_get(:@omit))
      assert_equal(:standard, updated.instance_variable_get(:@naming_scheme))
      assert_equal(false, updated.instance_variable_get(:@remap))
      assert_equal(:new, updated.name)
      assert_equal(true, updated.local?)
    end

    def assert_formats_equal(f1, f2)
      assert_equal f1, f2, 'Formats expected to be equal'
      assert_equal f1.hash, f2.hash, 'Format hashes expected to be equal'
    end

    def assert_formats_not_equal(f1, f2)
      assert_operator f1, :!=, f2, 'Formats expected not to be equal'
      assert_operator f1.hash, :!=, f2.hash, 'Format hashes expected not to be equal'
    end

    def test_format_equals_to_self
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      assert_formats_equal f, f
    end

    def test_format_equals_to_clone
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      assert_formats_equal f, f.update
    end

    def test_format_equals_to_identical
      f1 = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      f2 = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      assert_formats_equal f1, f2
    end

    def test_not_equals_if_marshal_option_updated
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      assert_formats_not_equal f, f.update(marshal: { only: [:value]})
    end

    def test_not_equals_if_omit_option_updated
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      assert_formats_not_equal f, f.update(omit: [:undefined, :nil])
    end

    def test_not_equals_if_naming_scheme_updated
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      assert_formats_not_equal f, f.update(naming_scheme: :standard)
    end

    def test_not_equals_if_remap_updated
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      assert_formats_not_equal f, f.update(remap: false)
    end

    def test_not_equals_if_local_updated
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      assert_formats_not_equal f, f.update(local: true)
    end

    def test_not_equals_if_name_updated
      f = Format.new(marshal: { only: [:value, :number] }, omit: [:undefined], naming_scheme: :alternative, remap: true, local: false, name: :old)
      assert_formats_not_equal f, f.update(name: :other)
    end
  end
end