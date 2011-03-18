module Based
  
  class Directory
    attr_reader :base, :relativePath, :pathElements, :name, :parent, :fullPath
    
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
              @dirs << SubDirectory.new(entry, self)
            elsif ::File.file?(fullEntryPath)
              @files << File.new(entry, self)
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
    
    def initialize(path)
      super()
      @name = nil
      @parent = nil
      @base = self
      @relativePath = ""
      @pathElements = []
      @fullPath = path.end_with?("/") ? path : path + "/"
    end
  end
  
  class File
    attr_reader :name, :parent, :base, :relativePath, :pathElements, :fullPath
    
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
