require 'helper'

module Synqa
  
  class SynqaTestCase < Test::Unit::TestCase
    include Synqa
  end
  
  class TestHashCommand < SynqaTestCase
    context "A hash command" do
      setup do
        @hashCommand = HashCommand.new("sha32", 16, 3)
      end
      
      should "extract relative path and hash" do
        pathWithHash = @hashCommand.parseFileHashLine("/home/dir/", "abcdeabcde012345   /home/dir/subdir/file.txt")
        assert_equal "abcdeabcde012345", pathWithHash.hash
        assert_equal "subdir/file.txt", pathWithHash.relativePath
      end
      
      should "complain about mis-matched base dir" do
        assert_raise RuntimeError do
          @hashCommand.parseFileHashLine("/home/dir/", "abcdeabcde012345   /homes/dir/subdir/file.txt")
        end
      end
    end
  end
  
  class TestNormalisedDir < SynqaTestCase
    should "add / if missing" do
      assert_equal "home/dir/", normalisedDir("home/dir")
    end
    should "not add / if already at end" do
      assert_equal "home/dir/", normalisedDir("home/dir/")
    end
  end
end
