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
    
    attr_reader :fileInclude, :fileExclude, :dirInclude, :dirExclude
    
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
