require 'helper'

module Synqa
  class TestHashCommand < Test::Unit::TestCase
    context "A hash command" do
      setup do
        @hashCommand = HashCommand.new("sha21", 16, 3)
      end
      
      should "extract relative path and hash" do
        pathWithHash = @hashCommand.parseFileHashLine("/home/dir/", "abcdeabcde012345   /home/dir/subdir/file.txt")
        assert_equal "abcdeabcde012345", pathWithHash.hash
        assert_equal "subdir/file.txt", pathWithHash.relativePath
      end
    end
  end
end
