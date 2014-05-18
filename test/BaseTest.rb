
require 'test/unit'

def runProcess(process, debug=false)
  output = `#{process}`

  if (debug)
    puts output
  end
  
  if (!$?.success? || $?.exitstatus != 0)
    raise output
  end
end

runProcess(File.dirname(__FILE__) + "/../core/build.sh")

require_relative '../bindings/ruby/lib/perf.rb'
require 'json'

class TestExpose < Test::Unit::TestCase
  def setup
  end

  def teardown
  end

  def test_identity
    cfg = Perf::Config.new()

    ctx = Perf::Context.new(cfg, "idenity")
    assert_equal :no_error, ctx.error

    id = cfg.identity
    assert_not_nil id
    assert_kind_of String, id.to_s

    obj = JSON.parse(id.to_s)
    assert_not_nil obj

    assert_equal 4, obj.length
    assert_kind_of String, obj["cpu"]
    assert_kind_of String, obj["cpuCount"]
    assert_kind_of String, obj["memoryBytes"]
    assert_kind_of String, obj["binding"]
  end

  def test_timing
    cfg = Perf::Config.new()
    ctx = Perf::Context.new(cfg, "timing_test")

    test = ""

    ctx.block("test_block_10") do
      10.times do 
        test += "*"
      end
    end

    ctx.block("test_block_100") do
      100.times do 
        test += "*"
      end
    end

    ctx.block("test_block_100") do
      1000.times do 
        test += "*"
      end
    end

    ctx.block("test_block_100") do
      10000.times do 
        test += "*"
      end
    end

    obj = JSON.parse(ctx.dump)
    assert_not_nil obj
  end
end
