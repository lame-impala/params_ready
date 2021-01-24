require_relative '../test_helper'
require_relative '../../lib/params_ready/parameter/polymorph_parameter'
require_relative '../../lib/params_ready/parameter/value_parameter'
require_relative '../../lib/params_ready/input_context'

module ParamsReady
  module Parameter
    class PolymorphParameterTest < Minitest::Test
      def get_param_definition(
        default: Extensions::Undefined,
        optional: false,
        int_default: Extensions::Undefined,
        int_optional: false,
        string_default: Extensions::Undefined,
        string_optional: false,
        identifier: nil
      )

        Builder.define_polymorph(:parameter, altn: :param) do
          identifier(identifier) unless identifier.nil?
          type(:integer, :integer, altn: :int) do
            default(int_default) unless int_default == Extensions::Undefined
            self.optional if int_optional
          end
          type(:string, :string, altn: :str) do
            default(string_default) unless string_default == Extensions::Undefined
            self.optional if string_optional
          end
          default(default) unless default == Extensions::Undefined
          self.optional if optional
        end
      end

      def get_param(*args, **opts)
        get_param_definition(*args, **opts).create
      end

      def get_complex_param_definition
        Builder.define_polymorph :variable, altn: :pm do
          type :string, :simple, altn: :spl do
            default 'default'
          end
          type :hash, :complex, altn: :cpx do
            add :integer, :first, altn: :fst
            add :string, :second, altn: :scd
          end
          identifier :ppt
          default :simple
        end
      end

      def get_complex_param
        get_complex_param_definition.create
      end

      def test_dumps_only_permitted_value_to_hash
        d = get_complex_param_definition

        _, p = d.from_hash({ variable: { complex: { first: 5, second: 'second'}}}, context: Format.instance(:backend))
        exp = { variable: { complex: { first: 5 }}}
        assert_equal exp, p.to_hash(Format.instance(:backend), restriction: Restriction.permit(variable: [{ complex: :first }]))
        assert_equal exp, p.to_hash(Format.instance(:backend), restriction: Restriction.prohibit(variable: [{ complex: :second }]))

        _, p = d.from_hash({ variable: { simple: 'other' }}, context: Format.instance(:backend))
        assert_equal({}, p.to_hash(Format.instance(:backend), restriction: Restriction.permit(variable: [{ complex: :first }])))
        assert_equal({}, p.to_hash(Format.instance(:backend), restriction: Restriction.prohibit(variable: [{ complex: :second }, :simple])))
      end

      def test_square_bracket_access_works_if_child_is_set
        p = get_complex_param
        p.set_value_as({ first: 1, second: 'two' }, :complex)
        assert_equal({ first: 1, second: 'two' }, p[:complex].unwrap)
      end

      def test_square_bracket_access_fails_if_child_is_nil
        p = get_complex_param
        p.set_value_as 'other', :simple
        err = assert_raises do
          p[:complex]
        end
        assert_equal "Type 'complex' is not set, current type: 'simple'", err.message
      end

      def test_definition_raises_with_forbidden_alternative_name_or_name
        types1 = [
          ValueParameterDefinition.new(:integer, Value::IntegerCoder, altn: :ppt).finish,
          ValueParameterDefinition.new(:string, Value::StringCoder, altn: :str).finish
        ]
        exc = assert_raises do
          PolymorphParameterDefinition.new(:variable, altn: :poly, identifier: :ppt, types: types1)
        end
        assert_equal "Identifier already taken: ppt", exc.message
        types2 = [
          ValueParameterDefinition.new(:ppt, Value::IntegerCoder, altn: :int).finish,
          ValueParameterDefinition.new(:string, Value::StringCoder, altn: :str).finish
        ]
        exc = assert_raises do
          PolymorphParameterDefinition.new(:variable, altn: :poly, identifier: :ppt, types: types2)
        end
        assert_equal "Identifier already taken: ppt", exc.message

        exc = assert_raises do
          Builder.define_polymorph :raising do
            identifier :ppt
            type types1[0]
          end
        end
        assert_equal "Reserved alternative: ppt", exc.message

        exc = assert_raises do
          Builder.define_polymorph :raising do
            identifier :ppt
            type types2[0]
          end
        end
        assert_equal "Reserved name: ppt", exc.message
      end

      def test_definition_raises_with_reused_alternative_name_or_name
        types = [
          ValueParameterDefinition.new(:integer, Value::IntegerCoder, altn: :int).finish,
          ValueParameterDefinition.new(:string, Value::StringCoder, altn: :int).finish
        ]
        exc = assert_raises do
          PolymorphParameterDefinition.new(:variable, altn: :poly, identifier: :ppt, types: types)
        end
        assert_equal "Reused alternative: int", exc.message
        types = [
          ValueParameterDefinition.new(:integer, Value::IntegerCoder, altn: :int).finish,
          ValueParameterDefinition.new(:integer, Value::StringCoder, altn: :str).finish
        ]
        exc = assert_raises do
          PolymorphParameterDefinition.new(:variable, altn: :poly, identifier: :ppt, types: types)
        end
        assert_equal "Reused name: integer", exc.message
      end

      def test_type_identifier_can_be_rewritten
        param = get_param default: :string, string_default: 'FOO', int_default: 11, identifier: :xy
        out = param.format(Format.instance(:frontend))
        assert_equal({ xy: :str }, out)
        _, recreated = param.definition.from_input({ xy: :int })

        assert_equal 11, recreated[:integer].unwrap
      end

      def test_to_type_raises_when_called_on_unset_param
        param = get_param
        exc = assert_raises do
          param.to_type
        end
        assert_equal "parameter: value is nil", exc.message
      end

      def test_set_value_as_works
        param = get_param
        refute param.is_definite?
        param.set_value_as 'foo', :string
        assert param.is_definite?
        assert_equal 'foo', param.to_type.unwrap
        param.set_value_as 2, :integer
        assert param.is_definite?
        assert_equal 2, param.to_type.unwrap
      end

      def test_to_hash_if_eligible_returns_nil_if_value_is_default_and_intent_is_frontend
        param = get_param default: :string, string_default: 'foo'
        assert_equal 'foo', param.to_type.unwrap
        hash = param.to_hash_if_eligible(Intent.instance(:frontend))
        assert_nil(hash)
      end

      def test_to_hash_if_eligible_does_write_if_value_is_default_but_always_flag_is_true
        param = get_param default: :string, string_default: 'foo'
        assert_equal :string, param.type
        hash = param.to_hash_if_eligible Intent.instance(:marshal_only)
        assert_equal({ parameter: { string: 'foo' }}, hash)
      end

      def test_to_hash_if_eligible_uses_identifier_if_value_is_type_default_and_always_flag_is_false
        param = get_param int_default: 5
        refute param.is_definite?
        assert_nil param.type
        param.set_value_as 5, :integer
        hash = param.to_hash_if_eligible(Intent.instance(:frontend))
        assert_equal({ param: { ppt: :int }}, hash)
        hash = param.to_hash_if_eligible Intent.instance(:minify_only)
        assert_equal({ parameter: { ppt: :integer }}, hash)
      end

      def test_to_hash_if_eligible_does_write_value_is_type_default_but_always_flag_is_true
        param = get_param string_default: 'foo'
        refute param.is_definite?
        param.set_value_as 'foo', :string
        hash = param.to_hash_if_eligible(Intent.instance(:marshal_alternative))
        assert_equal({ param: { str: 'foo' }}, hash)
        hash = param.to_hash_if_eligible(Intent.instance(:marshal_only))
        assert_equal({ parameter: { string: 'foo' }}, hash)
      end

      def test_from_hash_raises_with_obligatory_parameter_when_hash_is_nil
        d = get_param_definition
        hash = {}
        r, _ = d.from_hash hash
        assert_equal "errors for parameter -- parameter: value is nil", r.error.message
      end

      def test_from_hash_uses_default_when_hash_is_nil
        d = get_param_definition default: :string, string_default: 'foo'
        hash = {}
        _, param = d.from_hash(hash)
        assert_equal "foo", param.to_type.unwrap
      end

      def test_from_hash_uses_type_default_if_value_is_identifier
        d = get_param_definition string_default: 'foo'
        hash = { param: { ppt: :str }}
        _, param = d.from_hash(hash)
        assert_equal "foo", param.to_type.unwrap
      end

      def test_from_hash_sets_value_correctly_if_it_is_listed_under_alternative_name
        d = get_param_definition
        hash = { param: { str: 'bar' }}
        _, param = d.from_hash(hash)
        assert_equal "bar", param.to_type.unwrap
        assert_equal :string, param.type
      end

      def test_from_hash_sets_value_correctly_if_it_is_listed_under_name
        d = get_param_definition
        hash = { parameter: { integer: 10 }}
        _, param = d.from_hash(hash, context: Format.instance(:backend))
        assert_equal 10, param.to_type.unwrap
      end


      def test_from_hash_works_with_context_object
        d = get_param_definition
        hash = { param: { str: 'bar' }}
        ctx = InputContext.new(Format.instance(:frontend), {})
        _, param = d.from_hash(hash, context: ctx)
        assert_equal "bar", param.to_type.unwrap
        assert_equal :string, param.type
      end

      def test_equals_works_with_polymorph
        p1 = get_param
        p2 = p1.dup
        refute_equal p1, p2
        p1.set_value_as 'foo', :string
        refute_equal p1, p2
        p2.set_value_as 'foo', :string
        assert_equal p1, p2
        p1.set_value_as 'bar', :string
        refute_equal p1, p2
        p1.set_value_as 2, :integer
        refute_equal p1, p2
      end
    end

    class PolymorphParameterUpdateInTest < Minitest::Test
      def get_def
        Builder.define_polymorph :updating do
          identifier :ppt
          type :hash, :complex do
            add :integer, :detail
            add :string, :search
          end

          type :integer, :scalar
        end
      end

      def initial_value
        { updating: { complex: { detail: 1, search: 'a'}} }
      end

      def complex_value
        { complex: { detail: 2, search: 'b' }}
      end

      def scalar_value
        { scalar: 10 }
      end

      def test_update_if_applicable_works_if_called_on_unfrozen_self
        d = get_def
        _, p = d.from_hash(initial_value)
        changed, u = p.update_if_applicable(complex_value, [])
        assert changed
        assert_equal({ detail: 2, search: 'b'}, u[:complex].unwrap)
        assert_different u, p
        assert_different u[:complex], p[:complex]
        refute u.frozen?
        refute u[:complex].frozen?
      end

      def test_update_if_applicable_works_if_called_with_changed_type_on_unfrozen_self
        d = get_def
        _, p = d.from_hash(initial_value)

        changed, u = p.update_if_applicable(scalar_value, [])
        assert changed
        assert_equal(10, u[:scalar].unwrap)
        assert_different u, p
        refute u.frozen?
        refute u[:scalar].frozen?
      end

      def test_update_if_applicable_works_if_called_on_frozen_self
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable(complex_value, [])
        assert changed
        assert_different u, p
        assert_different u[:complex], p[:complex]

        assert u.frozen?
        assert u[:complex].frozen?
      end

      def test_update_if_applicable_works_if_called_with_changed_type_on_frozen_self
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable(scalar_value, [])
        assert changed
        assert_equal(10, u[:scalar].unwrap)
        assert_different u, p
        assert u.frozen?
        assert u[:scalar].frozen?
      end

      def test_update_if_applicable_works_if_called_on_complex_child_of_unfrozen_parameter
        d = get_def
        _, p = d.from_hash(initial_value)

        changed, u = p.update_if_applicable(complex_value[:complex], [:complex])
        assert changed
        assert_equal({ detail: 2, search: 'b'}, u[:complex].unwrap)
        assert_different u, p
        assert_different u[:complex], p[:complex]
        refute u.frozen?
        refute u[:complex].frozen?
      end

      def test_update_if_applicable_works_if_called_on_complex_child_of_unfrozen_parameter_with_different_value
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable(complex_value[:complex], [:complex])
        assert changed
        assert_equal({ detail: 2, search: 'b'}, u[:complex].unwrap)
        assert_different u, p
        assert_different u[:complex], p[:complex]
        assert u.frozen?
        assert u[:complex].frozen?
      end

      def test_update_if_applicable_works_if_called_on_atomic_descendant_of_unfrozen_parameter_with_different_value
        d = get_def
        _, p = d.from_hash(initial_value)

        changed, u = p.update_if_applicable(10, [:complex, :detail])
        assert changed
        assert_equal({ detail: 10, search: 'a'}, u[:complex].unwrap)
        refute_same u, p
        refute_same u[:complex], p[:complex]
        refute_same u[:complex][:detail], p[:complex][:detail]
        refute_same u[:complex][:search], p[:complex][:search]
        refute u.frozen?
        refute u[:complex].frozen?
        refute u[:complex][:detail].frozen?
        refute u[:complex][:search].frozen?
      end

      def test_update_if_applicable_works_if_called_on_atomic_descendant_of_frozen_parameter_with_different_value
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable(10, [:complex, :detail])
        assert changed
        assert_equal({ detail: 10, search: 'a'}, u[:complex].unwrap)
        refute_same u, p
        refute_same u[:complex], p[:complex]
        refute_same u[:complex][:detail], p[:complex][:detail]
        assert_same u[:complex][:search], p[:complex][:search]
        assert u.frozen?
        assert u[:complex].frozen?
        assert u[:complex][:detail].frozen?
        assert u[:complex][:search].frozen?
      end

      def test_update_if_applicable_works_if_called_on_atomic_descendant_of_frozen_parameter_with_same_value
        d = get_def
        _, p = d.from_hash(initial_value)
        p.freeze

        changed, u = p.update_if_applicable(1, [:complex, :detail])
        refute changed
        assert_equal({ detail: 1, search: 'a'}, u[:complex].unwrap)
        assert_same u, p
        assert u.frozen?
      end
    end
  end
end