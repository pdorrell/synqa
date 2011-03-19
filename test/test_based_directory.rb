require 'helper'

require 'based-directory'

module Based
  
  class BaseDirectoryTestCase < Test::Unit::TestCase
    include Based
  end

  class TestBaseDirectory < BaseDirectoryTestCase
    context "A base directory" do
      setup do
        @baseDirPath = ::File.expand_path(::File.join(::File.dirname(__FILE__), "data", "dir1"))
        puts "@baseDirPath = #{@baseDirPath}"
        @baseDir = BaseDirectory.new(@baseDirPath)
      end
      
      should "find files in top-level directory and get their names and relative paths" do
        names = @baseDir.files.map {|file| file.name}
        assert_equal names, ["file1.txt", "file2.txt"]
        relativePaths = @baseDir.files.map {|file| file.relativePath}
        assert_equal relativePaths, ["file1.txt", "file2.txt"]
      end
    end
  end
end
