# The Based module supports the concept of a "based" directory. Typically in modern software development, 
# a project is represented by a set of sub-directories and files within a base directory. The exact location
# of the base directory is not so important (i.e. it's wherever you checked it out of source control). For a given
# file or sub-directory, one is often more interested in the path relative to the base directory, rather than 
# the absolute path. (But you still need the full path when performing an actual file operation on the file
# or directory.)
# Also, there might be files and directories that you wish to ignore. Based supports simple functional includes and
# excludes. (A bit less succint than include/exclude globs, but probably more flexible.)

module Based
  
  # A base class for directories: i.e. either the base directory itself, or a sub-directory
  class Directory
    attr_reader :base
    attr_reader :relativePath
    attr_reader :pathElements
    attr_reader :name
    attr_reader :parent
    attr_reader :fullPath
    
    def initialize
      @entries = nil
      @subDirs = nil
    end
    
    def getEntries
      if @entries == nil
        @entries = Dir.entries(fullPath)
        @dirs = []
        @files = []
        for entry in @entries
          if entry != "." and entry != ".." 
            fullEntryPath = fullPath + entry
            if ::File.directory?(fullEntryPath)
              subDirectory = SubDirectory.new(entry, self)
              if @base.dirInclude == nil or @base.dirInclude.call(subDirectory)
                if @base.dirExclude == nil or not @base.dirExclude.call(subDirectory)
                  @dirs << subDirectory
                end
              end
            elsif ::File.file?(fullEntryPath)
              file = File.new(entry, self)
              if @base.fileInclude == nil or @base.fileInclude.call(file)
                if @base.fileExclude == nil or not @base.fileExclude.call(file)
                  @files << file
                end
              end
            end
          end
        end
        @dirs.sort_by! {|dir| dir.name}
        @files.sort_by! {|file| file.name}
      end
    end
    
    def files
      getEntries()
      return @files
    end
    
    def dirs
      getEntries()
      return @dirs
    end
    
    def subDirs
      result = []
      for dir in dirs
        result << dir
        result += dir.subDirs
      end
      return result
    end
    
    def allFiles
      result = files
      for subDir in subDirs
        result += subDir.files
      end
      return result
    end
  end
  
  class SubDirectory<Directory
    
    def initialize(name, parent)
      super()
      @name = name
      @parent = parent
      @base = @parent.base
      @relativePath = @parent.relativePath + @name + "/"
      @pathElements = @parent.pathElements + [name]
      @fullPath = @parent.fullPath + @name + "/"
    end
  end
  
  class BaseDirectory<Directory
    
    attr_reader :fileInclude
    attr_reader :fileExclude
    attr_reader :dirInclude
    attr_reader :dirExclude
    
    def initialize(path, options = {})
      super()
      @name = nil
      @parent = nil
      @base = self
      @relativePath = ""
      @pathElements = []
      @fullPath = path.end_with?("/") ? path : path + "/"
      @dirInclude = options.fetch(:dirInclude, nil)
      @dirExclude = options.fetch(:dirExclude, nil)
      @fileInclude = options.fetch(:fileInclude, nil)
      @fileExclude = options.fetch(:fileExclude, nil)
    end
  end
  
  class File
    attr_reader :name
    attr_reader :parent
    attr_reader :base
    attr_reader :relativePath
    attr_reader :pathElements
    attr_reader :fullPath
    
    def initialize(name, parent)
      super()
      @name = name
      @parent = parent
      @base = @parent.base
      @relativePath = @parent.relativePath + @name
      @pathElements = @parent.pathElements + [name]
      @fullPath = @parent.fullPath + @name
    end
    
  end
  
end
