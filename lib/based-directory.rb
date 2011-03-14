module Based
  
  class Directory
    attr_reader :base, :relativePath, :pathElements, :name, :parent, :fullPath
    
    def initialize
      @entries = nil
    end
    
    def getEntries
      if @entries == nil
        @entries = Dir.entries(fullPath)
        @dirs = []
        @files = []
        for entry in @entries do
          if entry != "." and entry != ".." 
            fullEntryPath = fullPath + entry
            if ::File.directory?(fullEntryPath)
              @dirs << Directory(entry, self)
            elsif ::File.file?(fullEntryPath)
              @files << File(entry, self)
            end
          end
        end
        @dirs.sort()
        @files.sort()
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
      @fullPath = path.end_with?("/") ? path[0..-1] : path
    end
  end
  
  class File
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
