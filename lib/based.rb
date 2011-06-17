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
    # The base directory (object)
    attr_reader :base
    
    # The path of this directory relative to the base directory (includes a following "/" if non-empty)
    attr_reader :relativePath
    
    # The elements of the relative path as an array
    attr_reader :pathElements
    
    # The immediate name of the directory (nil for the base directory)
    attr_reader :name
    
    # The parent directory (nil for the base directory)
    attr_reader :parent
    
    # The full path of the file
    attr_reader :fullPath
    
    # initialise with un-initialised entries
    def initialize
      @entries = nil
    end
    
    # get the "entries", i.e. list of files and directories immediately contained in this directory, and cache them.
    # Note that dirExclude, fileInclude and fileExclude functions in the base directory object
    # may be applied to filter out some entries.
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
              if @base.dirExclude == nil or not @base.dirExclude.call(subDirectory)
                @dirs << subDirectory
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
    
    # Get list of files immediately contained in this directory
    def files
      getEntries()
      return @files
    end
    
    # Get list of directories immediately contained in this directory
    def dirs
      getEntries()
      return @dirs
    end
    
    # Get a list of all the sub-directories of this directory (with parents preceding children)
    def subDirs
      result = []
      for dir in dirs
        result << dir
        result += dir.subDirs
      end
      return result
    end
    
    # Get a list of all files contained within this directory
    def allFiles
      result = files
      for subDir in subDirs
        result += subDir.files
      end
      return result
    end
  end
  
  # An object representing a sub-directory (i.e. not the base directory itself)
  class SubDirectory<Directory
    
    # Construct directory object from parent directory object and this directory's name
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
  
  # An object representing the base directory
  class BaseDirectory<Directory
    
    # Function to decide if files should be included (if nil, assume all included). Subject
    # to exclusion by fileExclude
    attr_reader :fileInclude
    
    # Function to decide if files should be excluded
    attr_reader :fileExclude
    
    # Function to decide if sub-directories should be excluded (if a directory is excluded, so 
    # are all it's sub-directories and files contained within)
    attr_reader :dirExclude
    
    # Initialise from absolute file path. Options include :dirExclude, :fileInclude and :fileExclude
    def initialize(path, options = {})
      super()
      @name = nil
      @parent = nil
      @base = self
      @relativePath = ""
      @pathElements = []
      @fullPath = path.end_with?("/") ? path : path + "/"
      @dirExclude = options.fetch(:dirExclude, nil)
      @fileInclude = options.fetch(:fileInclude, nil)
      @fileExclude = options.fetch(:fileExclude, nil)
    end
  end
  
  # An object representing a file within the base directory
  class File
    # immediate name of file
    attr_reader :name
    
    # parent, i.e. containing directory
    attr_reader :parent
    
    # the base directory
    attr_reader :base
    
    # path of this file relative to base directory
    attr_reader :relativePath
    
    # elements of file path (including the name) as an array
    attr_reader :pathElements
    
    # full absolute path name of file
    attr_reader :fullPath
    
    # initialise from name and containing directory
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
