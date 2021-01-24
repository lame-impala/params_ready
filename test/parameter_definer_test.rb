require_relative '../lib/params_ready/parameter_definer'
require_relative 'test_helper'

module ParamsReady
  class A
    include ParameterDefiner
    define_parameter(:boolean, :para, altn: :A) do
      default false
    end

    define_parameter(:boolean, :parb, altn: :B) do
      default true
    end

    define_parameter(:string, :string, altn: :str)
    define_parameter(:integer, :number, altn: :num)

    define_relation(:users, altn: :usr) do
      capture :string, :number
    end

    define_relation(:posts, altn: :ps) do
      add :boolean, :flag, altn: :flg do
        default true
      end
    end
  end

  class B < A
    define_parameter :boolean, :parb, altn: :b do
      default true
    end

    define_relation(:posts, altn: :pss) do
      add :boolean, :flag, altn: :flg do
        default true
      end
    end
  end

  class C < A
    define_parameter :boolean, :para, altn: :a do
      default true
    end

    define_parameter :boolean, :parc, altn: :c do
      default true
    end

    define_relation(:posts, altn: :pts) do
      add :boolean, :flag, altn: :flg do
        default true
      end
    end
  end

  class ParameterDefinerInheritanceTest < Minitest::Test
    def test_param_inheritance_works
      c = C
      cparams = c.all_parameters
      assert_equal(:a, cparams[:para].altn)
      assert_equal(:B, cparams[:parb].altn)
      refute_nil cparams[:parc]

      b = B
      bparams = b.all_parameters
      assert_equal(:A, bparams[:para].altn)
      assert_equal(:b, bparams[:parb].altn)
      assert_nil bparams[:parc]

      a = A
      aparams = a.all_parameters
      assert_equal(:A, aparams[:para].altn)
      assert_equal(:B, aparams[:parb].altn)
      assert_nil aparams[:parc]
    end

    def test_relation_inheritance_works
      c = C
      cdom = c.all_relations
      assert_equal(:usr, cdom[:users].altn)
      assert_equal(:pts, cdom[:posts].altn)

      b = B
      bdom = b.all_relations
      assert_equal(:usr, bdom[:users].altn)
      assert_equal(:pss, bdom[:posts].altn)

      a = A
      adom = a.all_relations
      assert_equal(:usr, adom[:users].altn)
      assert_equal(:ps, adom[:posts].altn)
    end
  end
end