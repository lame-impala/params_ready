require 'benchmark'
require 'memory_profiler'

require_relative 'params_ready_test_helper'
require_relative 'memoizing_parameter'

class ParamsReadyBenchmark < Minitest::Test
  def input
    {
      A: true,
      X: false,
      ps: {
        flg: false
      },
      cpx: {
        na: [
          {
            name: 'N1',
            id: 1,
            valid_thru: '2020-08-06'
          },
          {
            name: 'N2',
            id: 2,
            valid_thru: '2020-08-30'
          }
        ],
        name: 'C1',
        status: 5,
        start_at: '2020-06-12'
      },
      usr: {
        str: 'bogus',
        num: 5,
        eml_lk: 'john'
      }
    }
  end

  def test_benchmark
    # skip('Takes some time')

    [
      :benchmark_ordering_on_unfrozen_params,
      :benchmark_ordering_on_frozen_params,
      :benchmark_ordering_on_memoizing_params
    ].shuffle.each do |method|
      send(method)
    end
  end

  def benchmark_ordering_on_unfrozen_params
    a = A.new
    r, prms = a.send :populate_state_for, :benchmark, input
    assert r.ok?, r.error

    res = Benchmark.measure do
      10000.times do
        prms.toggle :users, :name
      end
    end
    puts "Toggle order with unfrozen params:\n#{res}"
  end

  def benchmark_ordering_on_frozen_params
    a = A.new
    r, prms = a.send :populate_state_for, :benchmark, input
    assert r.ok?, r.error

    prms.freeze
    res = Benchmark.measure do
      10000.times do
        prms.toggle :users, :name
      end
    end
    puts "Toggle order with frozen params:\n#{res}"
  end

  def benchmark_ordering_on_memoizing_params
    a = AM.new
    r, prms = a.send :populate_state_for, :benchmark, input
    assert r.ok?, r.error
    prms.freeze
    res = Benchmark.measure do
      10000.times do
        prms.toggle :users, :name
      end
    end
    puts "Toggle order with memoizing params:\n#{res}"
  end

  def test_profile
    # skip('Really verbose')
    profile_ordering_on_unfrozen_params
    profile_ordering_on_frozen_params
    profile_ordering_on_memoizing_params
  end

  def profile_ordering_on_unfrozen_params
    a = A.new
    _, prms = a.send :populate_state_for, :benchmark, input

    res = MemoryProfiler.report do
      prms.toggle :users, :name
      prms.toggle :users, :name
    end
    puts "#####################################"
    puts "Toggle order with unfrozen params:"
    puts "#####################################"
    puts "#{res.pretty_print}"
  end

  def profile_ordering_on_frozen_params
    a = A.new
    _, prms = a.send :populate_state_for, :benchmark, input

    prms.freeze

    res = MemoryProfiler.report do
      prms.toggle :users, :name
      prms.toggle :users, :name
    end
    puts "###################################"
    puts "Toggle order with frozen params:"
    puts "###################################"
    puts "#{res.pretty_print}"
  end

  def profile_ordering_on_memoizing_params
    a = AM.new
    _, prms = a.send :populate_state_for, :benchmark, input

    prms.freeze

    res = MemoryProfiler.report do
      prms.toggle :users, :name
      prms.toggle :users, :name
    end
    puts "###################################"
    puts "Toggle order with memoizing params:"
    puts "###################################"
    puts "#{res.pretty_print}"
  end
end