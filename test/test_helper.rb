require 'minitest/autorun.rb'
require 'minitest/rg'
require 'byebug'
require 'forwardable'

require 'arel'
require 'active_record'
require 'ruby2_keywords'
require_relative '../lib/params_ready/intent'
require_relative '../lib/params_ready/parameter/value_parameter'
require_relative '../lib/params_ready/parameter/struct_parameter'
require_relative '../lib/params_ready/parameter/tuple_parameter'
require_relative '../lib/params_ready/parameter/polymorph_parameter'

# https://jpospisil.com/2014/06/16/the-definitive-guide-to-arel-the-sql-manager-for-ruby.html
conn = ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
Arel::Table.engine = ActiveRecord::Base

marshal_alternative = ParamsReady::Format.new(marshal: :all, omit: [], naming_scheme: :alternative, remap: true, local: true, name: :maa)
ParamsReady::Format.define(:marshal_alternative, marshal_alternative)

alternative_only = ParamsReady::Format.new(marshal: :none, omit: [], naming_scheme: :alternative, remap: true, local: false, name: :alo)
ParamsReady::Format.define(:alternative_only, alternative_only)

marshal_only = ParamsReady::Format.new(marshal: :all, omit: [], naming_scheme: :standard, remap: false, local: false, name: :mao)
ParamsReady::Format.define(:marshal_only, marshal_only)

minify_only = ParamsReady::Format.new(marshal: :none, omit: ParamsReady::Format::OMIT_ALL, naming_scheme: :standard, remap: false, local: false, name: :mio)
ParamsReady::Format.define(:minify_only, minify_only)

class DummyObject
  def initialize(value)
    @value = value
  end

  def say
    "Wrapped value: '#{@value}'"
  end

  def format
    @value
  end

  def inspect
    "DummyObject(#{@value})"
  end

  alias_method :to_s, :inspect
end

class String
  def unquote
    gsub(/[\\"]/, '')
  end

  def unformat
    gsub("\n", ' ').gsub(/\s+/, ' ').strip
  end
end


class DummyConnection
  attr_reader :last_query

  def initialize(result = [])
    @result = result
    @last_query = nil
  end

  def execute(query)
    @last_query = query
    @result
  end
end

class DummyScope
  def initialize(model, conn = DummyConnection.new)
    @model = model
    @where = []
    @ordering = nil
    @offset = nil
    @limit = nil
    @includes = nil
    @joins = nil
    @select_list = nil
    @count
    @connection = conn
  end

  def connection
    @connection
  end

  def to_sql
    "SELECT stuff FROM stuff"
  end

  def count
    1
  end

  def to_hash
    {
      joins: @joins,
      where: @where,
      ordering: @ordering,
      offset: @offset,
      limit: @limit,
      includes: @includes
    }
  end

  def arel_table
    @model.arel_table
  end

  def select(*sl)
    @select_list = Array(sl)
    self
  end

  def where(*clauses)
    @where += clauses
    self
  end

  def order(arel)
    @ordering = arel
    self
  end

  def reorder(arel)
    order(arel)
  end

  def joins(name)
    @joins ||= []
    @joins << name
    self
  end

  def includes(arr)
    @includes = arr
    self
  end

  def offset(val)
    @offset = val
    self
  end

  def limit(val)
    @limit = val
    self
  end
end

class DummyModel
  def self.arel_table
    Arel::Table.new table_name
  end

  def self.all
    DummyScope.new(self)
  end
end

class User < DummyModel
  def self.table_name
    :users
  end

  attr_reader :email, :role, :subscriptions, :id, :profile, :audience

  def initialize(id:, email:, role:, subscriptions: [], profile: nil, audience: 0)
    @id = id
    @email = email
    @role = role
    @subscriptions = subscriptions
    profile.user = self if profile
    @profile = profile
    @audience = audience
  end
end

class Subscription < DummyModel
  def self.table_name
    :subscriptions
  end

  attr_reader :channel, :valid, :user_id, :user

  def initialize(channel:, valid:, user: nil)
    @user = user
    @channel = channel
    @valid = valid
  end

  def user_id
    @user&.id
  end
end

class Profile < DummyModel
  def self.table_name
    :profiles
  end

  attr_reader :id, :about
  attr_accessor :user

  def initialize(id:, about:, user: nil)
    @id = id
    @user = user
    @about = about
  end

  def user_id
    @user&.id
  end
end

class Post < DummyModel
  def self.table_name
    :posts
  end

  attr_reader :id, :subject
  attr_accessor :user

  def initialize(id:, subject:, user: nil)
    @id = id
    @user = user
    @subject = subject
  end

  def user_id
    @user&.id
  end
end

class Company < DummyModel
  def self.table_name
    :companies
  end

  attr_reader :id, :name, :vatid
  def initialize(id:, name:, vatid:)
    @id = id
    @name = name
    @vatid = vatid
  end
end

def get_complex_param_definition
  ParamsReady::Builder.define_hash(:parameter, altn: :parameter) do
    add(:string, :detail, altn: :d) do
      optional
    end
    add(:array, :roles, altn: :rr) do
      prototype :integer, :role
      optional
    end
    add(:hash, :actions, altn: :aa) do
      add(:boolean, :view, altn: :v) do
        optional
      end
      add(:boolean, :edit, altn: :e) do
        optional
      end
      optional
    end
    add(:tuple, :score, altn: :s) do
      marshal using: :string, separator: '|'
      field :integer, :guess
      field :integer, :hit
      optional
    end
    add(:polymorph, :evaluation, altn: :e) do
      identifier :ppt
      type :integer, :rating, altn: :r
      type :string, :note, altn: :n
      optional
    end
  end
end

def get_complex_param
  get_complex_param_definition.create
end

def assert_different(a, b)
  assert_operator a.object_id, :!=, b.object_id
end

def assert_same(a, b)
  assert_equal a.object_id, b.object_id
end

def with_query_context(restrictions:, data: {})
  restrictions.each do |restriction|
    restriction = if restriction.nil?
      ParamsReady::Restriction.blanket_permission
    else
      restriction
    end

    yield ParamsReady::QueryContext.new(restriction, data: data)
  end
end

DummyParam = Struct.new(:name, :altn)

def hash_diff(first, second)
  keys = first.keys | second.keys

  keys.reduce([{}, {}]) do |result, key|
    fvalue = first[key]
    svalue = second[key]

    next result if fvalue == svalue

    if fvalue.is_a?(Hash) && svalue.is_a?(Hash)
      fdiff, sdiff = hash_diff(fvalue, svalue)
      result[0][key] = fdiff
      result[1][key] = sdiff
    else
      result[0][key] = fvalue
      result[1][key] = svalue
    end
    result
  end
end


module ActionCtrl
  class Parameters
    extend Forwardable
    def_delegators :@hash, :[], :key?, :fetch

    def initialize(hash)
      @hash = hash
    end
  end

  def __unwrap__
    @hash
  end
end

def assert_params_equal(a, b)
  assert_equal a, b
  assert_equal a.hash, b.hash
  assert a.eql?(b)
  assert b.eql?(a)
end

def refute_params_equal(a, b)
  refute_equal a, b
  refute_equal a.hash, b.hash
  refute a.eql?(b)
  refute b.eql?(a)
end
