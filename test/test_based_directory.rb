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
        #puts "@baseDirPath = #{@baseDirPath}"
        @baseDir = BaseDirectory.new(@baseDirPath)
      end
      
      should "find files in top-level directory and get their names and relative paths" do
        names = @baseDir.files.map {|file| file.name}
        assert_equal ["file1.txt", "file2.txt"], names
        relativePaths = @baseDir.files.map {|file| file.relativePath}
        assert_equal ["file1.txt", "file2.txt"], relativePaths
      end
      
      should "check attributes of basedir" do
        assert_equal nil, @baseDir.name
        assert_equal nil, @baseDir.parent
        assert_equal @baseDir, @baseDir.base
        assert_equal "", @baseDir.relativePath
        assert_equal [], @baseDir.pathElements
        assert_equal "#{@baseDirPath}/", @baseDir.fullPath
      end
      
      should "find one file and check all its attributes" do
        dir2 = @baseDir.dirs[0]
        dir4 = dir2.dirs[0]
        file5 = dir4.files[0]
        assert_equal "file5.text", file5.name
        assert_equal dir4, file5.parent
        assert_equal @baseDir, file5.base
        assert_equal "dir2/dir4/file5.text", file5.relativePath
        assert_equal ["dir2", "dir4", "file5.text"], file5.pathElements
        assert_equal "#{@baseDirPath}/dir2/dir4/file5.text", file5.fullPath
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
