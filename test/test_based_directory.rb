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
        assert_equal ["file1.txt", "file2.txt"], names
        relativePaths = @baseDir.files.map {|file| file.relativePath}
        assert_equal ["file1.txt", "file2.txt"], relativePaths
      end
      
      should "find sub-directories in top-level directory and get their names and relative paths" do
        names = @baseDir.dirs.map {|dir| dir.name}
        assert_equal ["dir2", "dir3"], names
        relativePaths = @baseDir.dirs.map {|dir| dir.relativePath}
        assert_equal ["dir2/", "dir3/"], relativePaths
      end
    end
  end
end
