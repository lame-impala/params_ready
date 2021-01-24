require_relative '../lib/params_ready/parameter_user'
require_relative '../lib/params_ready/parameter_definer'

class SM
  include ParamsReady::ParameterDefiner

  define_parameter(:hash, :complex, altn: :cpx) do
    memoize

    add :array, :nested_attrs, altn: :na do
      prototype :hash do
        add :string, :name
        add :integer, :id
        add :date, :valid_thru
      end
    end
    add :string, :name
    add :integer, :status
    add :date, :start_at
  end

  define_parameter(:string, :string, altn: :str) do
    constrain :enum, %w(bogus real virtual)
    default 'bogus'
  end

  define_parameter(:integer, :number, altn: :num) do
    constrain :range, 1..10
    default 5
  end

  define_relation(:users, altn: :usr) do
    capture :string, :number
    fixed_operator_predicate :email_like, altn: :eml_lk, attr: :email do
      operator :like
      type :value, :string
      optional
    end
    paginate 100, 500
    order do
      column :email, :asc
      column :name, :asc
      column :hits, :desc
      default [:email, :asc]
    end
  end
end

class AM
  include ParamsReady::ParameterUser
  extend ParamsReady::Helpers::ParameterDefinerClassMethods

  define_parameter(:boolean, :para, altn: :A) do
    default false
  end

  define_parameter(:boolean, :parb, altn: :X) do
    default true
  end

  include_parameters SM
  include_relations SM

  define_relation(:posts, altn: :ps) do
    memoize
    add :boolean, :flag, altn: :flg do
      default true
    end
    paginate 50, 1000
    order do
      column :date, :asc
      column :like, :desc
    end
  end

  use_parameter :para
  use_parameter :parb
  use_parameter :complex, only: [:benchmark]

  use_relation :users, except: [:bogus]
  use_relation :posts, except: [:bogus]
end
