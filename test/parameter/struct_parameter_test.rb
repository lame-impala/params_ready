require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/struct_parameter'
require_relative '../../lib/params_ready/parameter/value_parameter'
require_relative '../../lib/params_ready/input_context'
require_relative '../../lib/params_ready/result'

module ParamsReady
  module Parameter
    module StructParameterTestHelper
      def get_param_definition(default: Extensions::Undefined, optional: false, preprocessor: nil, populator: nil, postprocessor: nil)
        d = Builder.define_struct(:parameter, altn: :param) do
          add(:boolean, :checked, altn: :chck) do
            default false
          end
          add(:integer, :detail, altn: :dt) do
            default 0
          end
          add(:string, :search, altn: :srch) do
            default ""
          end
          self.default(default) unless default == Extensions::Undefined
          self.optional if optional
          preprocess &preprocessor unless preprocessor.nil?
          if populator
            populate &populator
            local
          end
          postprocess &postprocessor unless postprocessor.nil?
        end
        d
      end

      def get_param(*args, **opts)
        get_param_definition(*args, **opts).create
      end

      def get_param_with_preprocessor
        s = proc { |input, context, _definition|
          if context[:allowed] == true
            input[:dt] += 1
            input
          else
            raise ParamsReadyError, "Disallowed"
          end
        }
        d = get_param_definition preprocessor: s
        h = {
          param: {
            chck: true,
            dt: 1,
            srch: 'Stuff'
          }
        }
        [d, h]
      end

      def get_param_with_postprocessor
        s = proc { |param, context|
          if context[:allowed]
            if param[:checked].unwrap == true
              param[:detail].set_value(11)
            end
          else
            raise ParamsReadyError, "Disallowed"
          end
        }
        get_param_definition postprocessor: s
      end

      def get_param_with_populator
        ppl = proc { |context, parameter|
          raise ParamsReadyError, 'Disallowed' if context[:disallowed]

          if context[:condition]
            parameter[:checked] = false
            parameter[:detail] = 7
            parameter[:search] = 'Some'
          elsif
            parameter.set_value checked: true, detail: 5, search: 'Other'
          end
        }
        get_param_definition populator: ppl
      end
    end

    class StructParameterTest < Minitest::Test
      include StructParameterTestHelper

      def test_dup_unfreezes_a_frozen_hash
        d = get_param_definition
        _, p = d.from_hash({ parameter: { checked: true, detail: 5, search: 'stuff' }}, context: :backend)
        p.freeze
        clone = p.dup
        refute clone.frozen?
        refute clone[:checked].frozen?
        refute clone[:detail].frozen?
        refute clone[:search].frozen?
        assert_equal true, clone[:checked].unwrap
        assert_equal 5, clone[:detail].unwrap
        assert_equal 'stuff', clone[:search].unwrap
        assert_different p, clone
        assert_different p[:detail], clone[:detail]
        assert_different p[:checked], clone[:checked]
        assert_different p[:search], clone[:search]
      end

      def test_update_if_applicable_called_on_self_works_with_unfrozen_param
        d = get_param_definition
        _, p = d.from_hash({ parameter: { checked: true, detail: 5, search: 'stuff' }}, context: :backend)
        changed, u = p.update_if_applicable({ checked: false, detail: 4, search: 'other'}, [])
        assert changed
        refute u.frozen?
        assert_equal false, u[:checked].unwrap
        assert_equal 4, u[:detail].unwrap
        assert_equal 'other', u[:search].unwrap
        assert_different p, u
      end

      def test_update_if_applicable_called_on_self_works_with_frozen_param
        d = get_param_definition
        _, p = d.from_hash({ parameter: { checked: true, detail: 5, search: 'stuff' }}, context: :backend)
        p.freeze
        changed, u = p.update_if_applicable({ checked: false, detail: 4, search: 'other'}, [])
        assert changed
        assert u.frozen?
        assert_equal false, u[:checked].unwrap
        assert_equal 4, u[:detail].unwrap
        assert_equal 'other', u[:search].unwrap
        assert_different p, u
      end

      def test_update_if_applicable_called_on_child_with_different_value_works_with_unfrozen_param
        d = get_param_definition
        _, p = d.from_hash({ parameter: { checked: true, detail: 5, search: 'stuff' }}, context: :backend)

        changed, u = p.update_if_applicable('other', [:search])
        assert changed
        refute u.frozen?
        assert_equal true, u[:checked].unwrap
        assert_equal 5, u[:detail].unwrap
        assert_equal 'other', u[:search].unwrap
        assert_different p, u
        assert_different p[:checked], u[:checked]
        assert_different p[:detail], u[:detail]
        assert_different p[:search], u[:search]
      end

      def test_update_if_applicable_called_on_child_with_different_value_works_with_frozen_param
        d = get_param_definition
        _, p = d.from_hash({ parameter: { checked: true, detail: 5, search: 'stuff' }}, context: :backend)
        p.freeze
        changed, u = p.update_if_applicable('other', [:search])
        assert changed
        assert u.frozen?
        assert_equal true, u[:checked].unwrap
        assert_equal 5, u[:detail].unwrap
        assert_equal 'other', u[:search].unwrap
        assert_different p, u
        assert_same p[:checked], u[:checked]
        assert_same p[:detail], u[:detail]
        assert_different p[:search], u[:search]
        assert p[:search].frozen?
      end

      def test_update_if_applicable_called_on_child_with_equal_value_works_with_frozen_param
        d = get_param_definition
        _, p = d.from_hash({ parameter: { checked: true, detail: 5, search: 'stuff' }}, context: :backend)
        p.freeze
        changed, u = p.update_if_applicable('stuff', [:search])
        refute changed
        assert_same p, u
      end

      def test_populate_with_works_with_frozen_params
        d = get_param_definition
        _, p = d.from_hash({ parameter: { checked: true, detail: 5, search: 'stuff' }}, context: Format.instance(:backend))
        p.freeze

        clone = p.definition.create
        clone.send :populate_with, p, true
        assert_equal 'stuff', clone[:search].unwrap
        assert clone.frozen?
        assert_equal p[:search].object_id, clone[:search].object_id
      end

      def test_populate_with_works_with_frozen_params_and_a_replacement
        d = get_param_definition
        _, p = d.from_hash({ parameter: { checked: true, detail: 5, search: 'stuff' }}, context: Format.instance(:backend))
        p.freeze
        updated = p[:search].definition.create
        updated.set_value 'new'
        updated.freeze

        clone = p.definition.create
        clone.send :populate_with, p, true, search: updated
        assert_equal 'new', clone[:search].unwrap
        assert clone.frozen?
        assert_same updated, clone[:search]
      end

      def test_populate_with_works_with_unfrozen_params
        d = get_param_definition
        _, p = d.from_hash({ parameter: { checked: true, detail: 5, search: 'stuff' }}, context: Format.instance(:backend))

        clone = p.definition.create
        clone.send :populate_with, p
        assert_equal 'stuff', clone[:search].unwrap
        refute clone.frozen?
        assert_different p[:search], clone[:search]
      end

      def test_populate_with_works_with_unfrozen_params_and_a_replacement
        d = get_param_definition
        _, p = d.from_hash({ parameter: { checked: true, detail: 5, search: 'stuff' }}, context: Format.instance(:backend))
        updated = p[:search].definition.create
        updated.set_value 'new'
        updated.freeze

        clone = p.definition.create
        clone.send :populate_with, p, false, search: updated
        assert_equal 'new', clone[:search].unwrap
        refute clone.frozen?
        refute clone[:search].frozen?
        assert_different updated, clone[:search]
      end

      def test_child_can_not_be_added_after_default_has_been_set
        err = assert_raises do
          Builder.define_struct(:faulty) do
            add :integer, :first
            default first: 0
            add :integer, :second
          end
        end

        assert_equal "Child can't be added after default has been set", err.message
      end

      def test_code_reuse_with_inlude
        block = proc do
          add(:integer, :number) do
            default 10
          end
          add(:string, :search) do
            optional
          end
        end
        d = Builder.define_struct :includer do
          include &block
        end
        assert_equal [:number, :search], d.names.keys
      end

      def test_populator_sets_values_based_on_context
        d = get_param_with_populator
        f = Format.instance(:frontend)

        ctx = InputContext.new(f, { condition: true })
        _, p = d.from_hash(hash, context: ctx)
        assert_equal 7, p[:detail].unwrap
        assert_equal 'Some', p[:search].unwrap

        ctx = InputContext.new(f, { condition: false })
        _, p = d.from_hash(hash, context: ctx)
        assert_equal 5, p[:detail].unwrap
        assert_equal 'Other', p[:search].unwrap
      end

      def test_populator_reports_error_if_validator_provided
        d = get_param_with_populator
        f = Format.instance(:frontend)

        ctx = InputContext.new(f, { disallowed: true })
        result, _param = d.from_hash(hash, context: ctx)
        refute result.ok?
        assert result.errors['parameter'].first.is_a? PopulatorError
      end

      def test_preprocessor_can_alter_input_value
        d, hash = get_param_with_preprocessor
        f = Format.instance(:frontend)
        ctx = InputContext.new(f, { allowed: true })

        _, p = d.from_hash(hash, context: ctx)
        assert_equal 2, p[:detail].unwrap
        assert_equal 'Stuff', p[:search].unwrap
      end

      def test_preprocessor_bypassed_when_format_local
        d, _ = get_param_with_preprocessor
        f = Format.instance(:backend)
        r, p = d.from_input({ checked: true, detail: 1, search: 'Stuff'}, context: f)
        assert r.ok?, r.error&.message
        assert_equal 1, p[:detail].unwrap
      end

      def test_preprocessor_reports_error_if_validator_provided
        d, hash = get_param_with_preprocessor
        f = Format.instance(:frontend)
        ctx = InputContext.new(f, { allowed: false })
        validator = Result.new(d.name)
        result, _param = d.from_hash(hash, context: ctx, validator: validator)
        refute result.ok?
        assert result.errors['parameter'].first.is_a? PreprocessorError
      end

      def test_postprocessor_can_alter_value
        d = get_param_with_postprocessor
        hash = { param: { chck: true, dt: 1, srch: 'Stuff' }}

        f = Format.instance(:frontend)
        ctx = InputContext.new(f, { allowed: true })
        _, p = d.from_hash(hash, context: ctx)
        assert_equal true, p[:checked].unwrap
        assert_equal 11, p[:detail].unwrap
        assert_equal 'Stuff', p[:search].unwrap
      end

      def test_postprocessor_bypassed_when_format_local
        d = get_param_with_postprocessor
        f = Format.instance(:backend)
        r, p = d.from_input({ checked: true, detail: 1, search: 'Stuff'}, context: f)
        assert r.ok?, r.error&.message
        assert_equal 1, p[:detail].unwrap
      end

      def test_postprocessor_reports_error_if_validator_provided
        d = get_param_with_postprocessor
        hash = { param: { chck: true, dt: 1, srch: 'Stuff' }}
        f = Format.instance(:frontend)
        ctx = InputContext.new(f, { allowed: false })
        validator = Result.new(d.name)
        result, p = d.from_hash(hash, context: ctx, validator: validator)
        refute result.ok?
        assert result.errors['parameter'].first.is_a? PostprocessorError
        assert_equal true, p[:checked].unwrap
        assert_equal 1, p[:detail].unwrap
        assert_equal 'Stuff', p[:search].unwrap
      end

      def test_default_is_inferred_correctly
        p = get_param default: :inferred
        assert_equal(false, p[:checked].unwrap)
        assert_equal(0, p[:detail].unwrap)
        assert_equal("", p[:search].unwrap)
      end

      def test_uninitialized_struct_parameter_raises_when_child_queried
        p = get_param
        exc = assert_raises do
          p[:checked]
        end
        assert_equal("parameter: value is nil", exc.message)
      end

      def test_unwrap_returns_complete_hash_with_backend_names
        p = get_param
        p[:checked] = false
        p[:detail] = 3
        p[:search] = 'foo'
        h = p.unwrap
        assert_equal false, h[:checked]
        assert_equal 3, h[:detail]
        assert_equal 'foo', h[:search]
      end

      def test_uninitialized_struct_parameter_is_fully_initialized_by_assignment
        p = get_param
        p[:search] = "jack"
        p.freeze
        assert_equal(false, p[:checked].unwrap)
      end

      def test_uninitialized_optional_struct_parameter_returns_nil_when_child_queried
        p = get_param optional: true
        assert_nil(p[:checked])
      end

      def test_struct_parameter_writes_nil_if_value_is_default
        p = get_param default: { checked: true, detail: 3 }
        assert_equal true, p[:checked].unwrap
        assert_equal 3, p[:detail].unwrap
        assert_equal '', p[:search].unwrap
        assert_nil(p.to_hash_if_eligible(Intent.instance(:frontend)))
      end

      def test_struct_parameter_writes_everything_if_value_is_default_and_default_not_omitted
        p = get_param default: { checked: true, detail: 3 }
        assert_equal({ parameter: { checked: true, detail: 3, search: "" }}, p.to_hash_if_eligible(Intent.instance(:backend)))
      end

      def test_struct_parameter_omits_default_values_on_write_if_some_values_differ_from_default
        p = get_param default: { checked: true, detail: 3 }
        p[:checked] = false
        p[:detail] = 5
        p[:search] = "joe"
        assert_equal({ parameter: {detail: 5, search: 'joe' }}, p.to_hash_if_eligible(Intent.instance(:minify_only)))
        assert_equal({ param: {dt: '5', srch: 'joe' }}, p.to_hash_if_eligible(Intent.instance(:frontend)))
      end

      def test_struct_parameter_set_to_correct_values_or_defaults_from_populated_hash
        d = get_param_definition
        _, p = d.from_hash({ param: { srch: 'kate' }})
        assert_equal false, p[:checked].unwrap
        assert_equal 0, p[:detail].unwrap
        assert_equal "kate", p[:search].unwrap

        _, p = d.from_hash({ param: { chck: true, srch: 'kate' }})
        assert_equal true, p[:checked].unwrap
        assert_equal 0, p[:detail].unwrap
        assert_equal "kate", p[:search].unwrap

        _, p = d.from_hash({ param: { srch: 'joe', dt: 2 }})
        assert_equal false, p[:checked].unwrap
        assert_equal 2, p[:detail].unwrap
        assert_equal "joe", p[:search].unwrap
      end
    end

    class Base64MarshallerTest < Minitest::Test
      def get_def
        Builder.define_struct(:parameter, altn: :param) do
          add(:string, :type)
          add(:struct, :user) do
            add(:string, :name)
            add(:integer, :role)
          end

          marshal using: :base64
        end
      end

      def test_marshaller_works
        d = get_def
        _, p1 = d.from_input({ type: 'account', user: { name: 'User1', role: 5 }}, context: :backend)

        out = p1.for_output(:frontend)
        _, p2 = d.from_input(out)
        assert_equal p1, p2
      end
    end

    class RestrictionIntentBehaviour < Minitest::Test
      def get_param
        Builder.define_struct(:parameter, altn: :parameter) do
          add(:string, :name) do
            optional
          end
          add(:tuple, :date) do
            marshal using: :string, separator: '|'
            field :integer, :day
            field :integer, :month
            optional
          end
          add(:polymorph, :category) do
            identifier :ppt
            type :integer, :id
            type :string, :name
            optional
          end
          add(:array, :people) do
            prototype :struct, :person do
              add :string, :name
              add :string, :job do
                optional
              end
              add :array, :roles do
                prototype :integer, :role
              end
            end
          end
        end.create
      end

      def assert_restriction(parameter, method, list, exp)
        restriction = Restriction.send(method, *list)
        output = parameter.for_output(:backend, restriction: restriction)
        assert_equal exp, output

        list = list.empty? ? [] : [{ parameter.name => list }]
        restriction = Restriction.send(method, *list)
        output = parameter.to_hash(:backend, restriction: restriction)
        assert_equal exp, output[parameter.name]
      end

      def test_only_permitted_values_are_dumped
        p = get_param
        p[:name] = 'People list'
        p[:date] = '22|05'
        p[:category] = { id: 1 }
        p[:people] = [
          { name: "George", job: "author", roles: [0, 1] },
          { name: "Paola", job: "editor", roles: [2, 4] }
        ]
        exp = {
          name: 'People list',
          date: [22, 5],
          category: { id: 1 },
          people: [
            { name: "George", job: "author", roles: [0, 1] },
            { name: "Paola", job: "editor", roles: [2, 4] }
          ],
        }
        assert_restriction p, :blanket_permission, [], exp

        list = [:name, :date, :category, people: [:name, :job, :roles]]
        assert_restriction p, :permit, list, exp

        list = [people: [:name]]
        exp = { people: [{ name: 'George' }, { name: 'Paola' }] }
        assert_restriction p, :permit, list, exp

        list = [:name, :date, :category, people: [:job, :roles]]
        exp = { people: [{ name: 'George' }, { name: 'Paola' }] }
        assert_restriction p, :prohibit, list, exp

        list = [people: [:bogus]]
        exp = { people: [{}, {}] }
        assert_restriction p, :permit, list, exp

        list = [:category, :people]
        exp = { name: 'People list', date: [22, 5] }
        assert_restriction p, :prohibit, list, exp
      end
    end

    class StructWithNonOptionalChildrenBehaviour < Minitest::Test
      def get_def
        Builder.define_struct :param do
          add :struct, :nested do
            add :integer, :number do
              constrain :operator, :<=, 10, strategy: :undefine
            end
            add :string, :text
          end
        end
      end

      def test_raises_on_unwrap_if_child_is_undefined
        d = get_def
        
        r, p = d.from_input({ nested: { number: 5 }})
        refute r.ok?
        err = assert_raises(ValueMissingError) do
          p.unwrap
        end

        assert_equal 'param: value is nil', err.message
      end

      def test_does_not_raise_using_unwrap_or_with_default
        d = get_def

        r, p = d.from_input({ nested: { number: 5 }})
        refute r.ok?
        exp = { nested: { integer: 5, text: 'foo' }}

        res = p.unwrap_or(exp)

        assert_equal exp, res
      end

      def test_does_not_raise_using_unwrap_or_with_block
        d = get_def

        r, p = d.from_input({ nested: { number: 5 }})
        refute r.ok?
        exp = { nested: { integer: 11, text: 'bar' }}

        res = p.unwrap_or do
          exp
        end

        assert_equal exp, res
      end

      def test_does_not_raise_using_unwrap_or_if_nested_invalidated
        d = get_def

        r, p = d.from_input({ nested: { number: 5, text: 'foo' }})
        assert r.ok?

        p[:nested][:number].instance_variable_set :@value, Extensions::Undefined

        exp = { nested: { integer: 5, text: 'foo' }}
        res = p.unwrap_or(exp)

        assert_equal exp, res
      end
    end

    class StructOptionalDefaultBeviour < Minitest::Test
      include StructParameterTestHelper

      def test_writes_nil_if_undefined_and_formatting_is_minify_only
        p = get_param default: { checked: true, detail: 3, search: 'some' }, optional: true
        assert_nil p.to_hash_if_eligible(Intent.instance(:minify_only))
      end

      def test_writes_empty_hash_if_values_eq_defaults_and_formatting_is_minify_only
        p = get_param default: { checked: true, detail: 3, search: 'some' }, optional: true
        p[:checked] = false
        p[:detail] = 0
        p[:search] = ''
        assert_equal({ parameter: {}}, p.to_hash_if_eligible(Intent.instance(:minify_only)))
      end

      def test_sets_to_default_if_input_nil
        d = get_param_definition default: { checked: true, detail: 3, search: 'some' }, optional: true
        r, p = d.from_hash({})

        assert r.ok?
        assert p.is_default?
      end
    end

    class StructDefaultBehaviour < Minitest::Test
      include StructParameterTestHelper

      def test_writes_empty_hash_if_values_eq_defaults_and_not_overall_default_and_formatting_is_minify_only
        p = get_param default: { checked: true, detail: 3, search: 'some' }
        p[:checked] = false
        p[:detail] = 0
        p[:search] = ''
        assert_equal({ parameter: {}}, p.to_hash_if_eligible(Intent.instance(:minify_only)))
      end

      def test_writes_placeholder_if_values_eq_defaults_and_not_overall_default_and_formatting_is_frontend
        p = get_param default: { checked: true, detail: 3, search: 'some' }
        p[:checked] = false
        p[:detail] = 0
        p[:search] = ''
        assert_equal({ param: '0'}, p.to_hash_if_eligible(Intent.instance(:frontend)))
      end

      def test_for_output_returns_empty_hash_where_to_hash_would_return_placeholder
        p = get_param default: { checked: true, detail: 3, search: 'some' }
        p[:checked] = false
        p[:detail] = 0
        p[:search] = ''
        assert_equal({}, p.for_output(Intent.instance(:frontend)))
      end

      def test_writes_nil_if_values_eq_overall_default_and_formatting_is_frontend
        p = get_param default: { checked: true, detail: 3, search: 'some' }
        p[:checked] = true
        p[:detail] = 3
        p[:search] = "some"
        assert_nil p.to_hash_if_eligible(Intent.instance(:frontend))
      end

      def test_sets_children_to_defaults_if_set_from_empty_hash
        d = get_param_definition default: { checked: true, detail: 3, search: 'some' }
        _, p = d.from_input({})
        assert_equal false, p[:checked].unwrap
        assert_equal 0, p[:detail].unwrap
        assert_equal "", p[:search].unwrap
      end

      def test_sets_children_to_defaults_if_set_with_placeholder
        d = get_param_definition default: { checked: true, detail: 3, search: 'some' }
        _, p = d.from_input({ param: '0' })
        assert_equal false, p[:checked].unwrap
        assert_equal 0, p[:detail].unwrap
        assert_equal "", p[:search].unwrap
      end

      def test_sets_to_overall_default_if_set_from_nil
        d = get_param_definition default: { checked: true, detail: 3, search: 'some' }
        _, p = d.from_hash({ param: nil })
        assert_equal true, p[:checked].unwrap
        assert_equal 3, p[:detail].unwrap
        assert_equal "some", p[:search].unwrap
      end
    end

    class StructNilDefaultBehaviour < Minitest::Test
      include StructParameterTestHelper

      def test_writes_nil_if_the_value_is_default
        p = get_param default: nil
        assert_nil p.to_hash_if_eligible(Intent.instance(:minify_only))
      end

      def test_returns_nil_on_child_access_if_the_value_is_default
        p = get_param default: nil
        assert_nil p[:checked]
      end

      def test_can_be_set_to_nil
        p = get_param default: nil
        p.set_value nil
        refute p.is_definite?
      end

      def test_initializes_children_when_set_via_child_access
        p = get_param default: nil
        p[:checked] = true
        assert p.is_definite?
        assert_equal true, p[:checked].unwrap
        assert_equal 0, p[:detail].unwrap
        assert_equal '', p[:search].unwrap
      end

      def test_can_be_set_to_nil_via_set_value
        p = get_param default: nil
        p[:detail] = 4
        p.set_value nil
        refute p.is_definite?
      end

      def test_can_be_set_to_nil_via_update_in
        p = get_param default: nil
        p[:detail] = 4
        u = p.update_in(nil, [])
        assert p.is_definite?
        refute u.is_definite?
        assert_nil u.unwrap
      end

      def test_can_be_set_to_nil_via_update_in_if_frozen
        p = get_param default: nil
        p[:detail] = 4
        p.freeze
        u = p.update_in(nil, [])
        assert p.is_definite?
        refute u.is_definite?
        assert_nil u.unwrap
      end
    end

    class StructOptionalBehaviour < Minitest::Test
      include StructParameterTestHelper

      def test_writes_nil_when_intent_minimal_and_parameter_uninitialized
        p = get_param optional: true
        assert_nil p.to_hash_if_eligible(Intent.instance(:minify_only))
      end

      def test_writes_empty_hash_if_values_eq_defaults_and_formatting_is_backend
        p = get_param optional: true
        p[:checked] = false
        p[:detail] = 0
        p[:search] = ''
        assert_equal({ parameter: {}}, p.to_hash_if_eligible(Intent.instance(:minify_only)))
      end

      def test_writes_placeholder_if_values_eq_defaults_and_not_overall_default_and_formatting_is_frontend
        p = get_param optional: true
        p[:checked] = false
        p[:detail] = 0
        p[:search] = ''
        assert_equal({ param: '0'}, p.to_hash_if_eligible(Intent.instance(:frontend)))
      end

      def test_writes_nil_if_not_set_and_formatting_is_frontend
        p = get_param optional: true
        assert_nil p.to_hash_if_eligible(Intent.instance(:frontend))
      end

      def test_sets_children_to_defaults_if_set_from_empty_hash
        d = get_param_definition optional: true
        _, p = d.from_hash({ param: {}})
        assert_equal false, p[:checked].unwrap
        assert_equal 0, p[:detail].unwrap
        assert_equal "", p[:search].unwrap
      end

      def test_sets_children_to_defaults_if_set_with_placeholder
        d = get_param_definition optional: true
        _, p = d.from_hash({ param: '0' })
        assert_equal false, p[:checked].unwrap
        assert_equal 0, p[:detail].unwrap
        assert_equal "", p[:search].unwrap
      end

      def test_sets_to_nil_if_set_from_nil
        d = get_param_definition optional: true
        _, p = d.from_hash({ param: nil })
        refute p.is_definite?
        assert_nil p[:checked]
        assert_nil p[:detail]
        assert_nil p[:search]
      end

      def test_initializes_children_when_set_via_child_access
        p = get_param optional: true
        p[:checked] = true
        assert p.is_definite?
        assert_equal true, p[:checked].unwrap
        assert_equal 0, p[:detail].unwrap
        assert_equal '', p[:search].unwrap
      end

      def test_can_be_set_to_nil_via_set_value
        p = get_param optional: true
        p[:detail] = 4
        p.set_value nil
        refute p.is_definite?
      end

      def test_can_be_set_to_nil_via_update_in
        p = get_param optional: true
        p[:detail] = 4
        u = p.update_in(nil, [])
        assert p.is_definite?
        refute u.is_definite?
      end

      def test_can_be_set_to_nil_via_update_n_if_frozen
        p = get_param optional: true
        p[:detail] = 4
        p.freeze
        u = p.update_in(nil, [])
        assert p.is_definite?
        refute u.is_definite?
      end
    end

    class EqualEqlStructTest < Minitest::Test
      def get_def
        Builder.define_struct :test do
          add :integer, :a
          add :string, :b
        end
      end

      def test_parameters_from_same_definition_and_same_value_equal_each_other
        d = get_def
        _, a = d.from_input({ a: 5, b: 'foo' })
        _, b = d.from_input({ a: 5, b: 'foo' })
        assert_params_equal(a, b)
      end

      def test_parameters_from_same_definition_and_different_value_equal_each_other_not
        d = get_def

        _, a = d.from_input({ a: 5, b: 'foo' })
        _, b = d.from_input({ a: 6, b: 'foo' })
        refute_params_equal(a, b)
      end

      def test_parameters_from_different_definition_and_same_value_equal_each_other_not
        da = get_def
        db = get_def

        _, a = da.from_input({ a: 5, b: 'foo' })
        _, b = db.from_input({ a: 6, b: 'foo' })
        refute_params_equal(a, b)
      end
    end
  end
end