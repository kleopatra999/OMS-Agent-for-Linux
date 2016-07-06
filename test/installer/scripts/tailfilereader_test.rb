require 'test/unit'
require_relative '../../../installer/scripts/tailfilereader.rb'

class TailFileReaderTest < Test::Unit::TestCase
  TMP_DIR = File.dirname(__FILE__) + "/../tmp/test_tailfilereader"
  def setup
    @base_dir = ENV['BASE_DIR']
    @ruby_dir = "#{@base_dir}/source/ext/ruby"

    FileUtils.rm_rf(TMP_DIR)
    FileUtils.mkdir_p(TMP_DIR)
    @pos_file = "#{TMP_DIR}/tail.pos"
  end

  def teardown
    if TMP_DIR
      FileUtils.rm_rf(TMP_DIR)
    end
  end

  def create(opt={}, file)
    $options = opt
    Tailscript::NewTail.new([file])
  end

  def test_initialize
    file = "#{TMP_DIR}/tail.txt"
    File.open(file, "w") 
    tailreader = create({}, file)
    assert_equal(tailreader.paths, ["#{TMP_DIR}/tail.txt"])
  end
  
  def test_read_from_head
    file = "#{TMP_DIR}/tail.txt"
    input = File.open(file, "w") 
    input.puts "test1"
    input.puts "test2"
    input.flush

    tailreader = create({:pos_file => @pos_file, :read_from_head => true}, file)
    $stdout = StringIO.new('', 'w')
    tailreader.start  

    output = $stdout.string.split("\n")
    assert_equal(2, output.length)
    assert_equal("test2", output[1])
    assert_equal("test1", output[0])
    input.close()
    $stdout.close
  end

  def test_rotate
    file = "#{TMP_DIR}/tail.txt"
    input = File.open(file, "w")
    input.puts "test 1"
    input.puts "test 2"
    input.flush

    tailreader = create({:pos_file => @pos_file}, file)
    tailreader.start    
    
    input.puts "test 3"
    input.puts "test 4"
    input.flush
    
    $stdout = StringIO.new('', 'w')
    tailreader.start
 
    output = $stdout.string.split("\n")
    assert_equal(2, output.length)
    assert_equal("test 3", output[0])
    assert_equal("test 4", output[1])
  end 

  def test_rotate_readfromhead
    file = "#{TMP_DIR}/tail.txt"
    input = File.open(file, "w")
    input.puts "test 1"
    input.puts "test 2"
    input.flush

    tailreader = create({:pos_file => @pos_file, :read_from_head => true}, file)
    tailreader.start

    input.puts "test 3"
    input.puts "test 4"
    input.flush

    $stdout = StringIO.new('', 'w')
    tailreader.start
    output = $stdout.string.split("\n")
    assert_equal(4, output.length)
    assert_equal("test 1", output[0])
    assert_equal("test 2", output[1])
    assert_equal("test 3", output[2])
    assert_equal("test 4", output[3])
  end 
end

