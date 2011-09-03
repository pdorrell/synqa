# The Based module supports the concept of a "based" directory. Typically in modern software development, 
# a project is represented by a set of sub-directories and files within a base directory. The exact location
# of the base directory is not so important (i.e. it's wherever you checked it out of source control). For a given
# file or sub-directory, one is often more interested in the path relative to the base directory, rather than 
# the absolute path. (But you still need the full path when performing an actual file operation on the file
# or directory.)
# Also, there might be files and directories that you wish to ignore. Based supports simple functional includes and
# excludes. (A bit less succint than include/exclude globs, but probably more flexible.)

#N If we don't include these classes in a module, they will more likely conflict with other top-level classes in an application that uses them
module Based
  
  # A base class for directories: i.e. either the base directory itself, or a sub-directory
  #N With no base Directory class, SubDirectory and BaseDirectory would contain duplicated code
  class Directory
    # The base directory (object)
    #N Without this, the Directory wouldn't know about the BaseDirectory it is contained in, or, it would have to navigate through a chain of parents each time to find it.
    attr_reader :base
    
    # The path of this directory relative to the base directory (includes a following "/" if non-empty)
    #N Without this, applications wanting to know the relative path would have to constantly reconstruct it, either by compaing the base dir with the full path, or by concatenating the chain of parent dir names
    attr_reader :relativePath
    
    # The elements of the relative path as an array
    #N Without this, applications want to loop through the path elements would have to iterate through the parent chain, or they would have to reparse them out of the relative path
    attr_reader :pathElements
    
    # The immediate name of the directory (nil for the base directory)
    #N Without this, we wouldn't know the local name of this directory (if it's a sub-directory), or we would have to reparse it out of the relative path
    attr_reader :name
    
    # The parent directory (nil for the base directory)
    #N Without this, we can't quickly navigate to the parent directory
    attr_reader :parent
    
    # The full path of the file
    #N Without this,  we can't easily perform actual file operations on the directory (i.e. as an actual directory in the file system)
    attr_reader :fullPath
    
    # initialise with un-initialised entries
    #N Without initialize, @entries required for getEntries won't be initialised
    def initialize
      #N If we don't pre-set @entries to nil, we won't know that we haven't yet initialised that value
      @entries = nil
    end
    
    # get the "entries", i.e. list of files and directories immediately contained in this directory, and cache them.
    # Note that dirExclude, fileInclude and fileExclude functions in the base directory object
    # may be applied to filter out some entries.
    #N Without this, information required by files and dirs methods won't be available
    def getEntries
      #N If we don't check for @entries being nil, we will be constantly repeating the same work to get the files and sub-directories in this directory
      if @entries == nil
        #N If we don't call Dir.entries, we won't get the information about what the files and sub-directories are
        @entries = Dir.entries(fullPath)
        #N If we don't initialise @dirs, we won't have a place to put the sub-directories as we find them
        @dirs = []
        #N If we don't initialise @files, we won't have a place to put the files as we find them
        @files = []
        #N If we don't loop over the entries, we won't be able to process the information about the files and sub-directories that we got from Dir.entries
        for entry in @entries
          #N If we don't check for . and .., then these entries will be included as spurious sub-directories (and also the getEntries will recursively loop around forever)
          if entry != "." and entry != ".." 
            #N If we don't calculate fullEntryPath, then we won't know the full path of the entry we are processing, and we won't be able to execute file-system functions on it
            fullEntryPath = fullPath + entry
            #N If we don't check for an entry being a directory, then we will mistakenly assume all entries are directories
            if ::File.directory?(fullEntryPath)
              #N If we don't create subDirectory, we will fail to create the information about this sub-directory (to record)
              subDirectory = SubDirectory.new(entry, self)
              #N If we don't do this check, then we will be including directories that we specified to exclude
              if @base.dirExclude == nil or not @base.dirExclude.call(subDirectory)
                #N If we don't add the subDirectory, then we won't be recording information about this sub-directory
                @dirs << subDirectory
              end
            #N If we don't check for an entry being a file (even though we already know it's not a directory), we will be mistakenly treating non-files as if they were files
            elsif ::File.file?(fullEntryPath)
              #N If we don't create file, we will fail to create information about this file (to record)
              file = File.new(entry, self)
              #N If we don't do this check, then we will be including files that we didn't specify to include
              if @base.fileInclude == nil or @base.fileInclude.call(file)
                #N If we don't do this check, then we will be including files that we specified to exclude
                if @base.fileExclude == nil or not @base.fileExclude.call(file)
                  #N If we don't add the file, then we won't be recording information about this file
                  @files << file
                end
              end
            end
          end
        end
        #N If we don't sort the sub-directoriesby name, then they will be in some random order (or ordered by something we don't care about it and which won't be consistent across copies of this set of sub-directories and files)
        @dirs.sort_by! {|dir| dir.name}
        #N If we don't sort the files by name, then they will be in some random order (or ordered by something we don't care about it and which won't be consistent across copies of this set of sub-directories and files)
        @files.sort_by! {|file| file.name}
      end
    end
    
    # Get list of files immediately contained in this directory
    #N Without files, we have no way to iterate over the files contained immediately in this directory
    def files
      #N If we don't getEntries, and it hasn't previously been called, then the @files value won't be populated
      getEntries()
      return @files
    end
    
    # Get list of directories immediately contained in this directory
    #N Without dirs, we have no way to iterate over the sub-directories contained immediately in this directory
    def dirs
      #N If we don't getEntries, and it hasn't previously been called, then the @dirs value won't be populated
      getEntries()
      return @dirs
    end
    
    # Get a list of all the sub-directories of this directory (with parents preceding children)
    #N Without subDirs, there is no easy way to iterate over all sub-directories in this directory (in particular in the base directory representing the directory tree as a whole).
    def subDirs
      #N If we don't initialse result, we won't have an array to accumulate our results int
      result = []
      #N If we don't loop over the immediate sub-directories, we won't find any of the sub-directories
      for dir in dirs
        #N If we don't store this immediate sub-directory, then it will be missing from the results (and recursively, all the sub-directories will be missing)
        result << dir
        #N If we don't recursively call subDirs, then our listing will be only one sub-directory deep
        result += dir.subDirs
      end
      return result
    end
    
    # Get a list of all files contained within this directory
    #N Without allFiles, there is no easy way to iterate over all files in this directory (in particular in the base directory representing the directory tree as a whole).
    def allFiles
      #N If we don't start with files, we will be missing the files immediately contained in this directory
      result = files
      #N If we don't loop over immediate sub-directories, we won't find any files contained within sub-directories
      for subDir in subDirs
        #N If we don't recursively call files, we won't find the files contained within this immediate sub-directory.
        result += subDir.files
      end
      return result
    end
  end
  
  # An object representing a sub-directory (i.e. not the base directory itself)
  #N Without this class, we will have no way to record information about a directory in the directory tree which is _not_ the base directory
  class SubDirectory<Directory
    
    # Construct directory object from parent directory object and this directory's name
    #N If we don't initialize, then none of the information about the sub-directory (as derived from its name and it's parent directory) will be recorded
    def initialize(name, parent)
      #N If we don't call super(), then @entries won't get initialised
      super()
      #N Without @name, we won't know this sub-directory's immediate local name
      @name = name
      #N Without @parent, we won't directly know this sub-directory's parent
      @parent = parent
      #N Without @base, we won't know directly which base directory of the directory tree we are considering this sub-directory to be part of
      @base = @parent.base
      #N Without @relativePath, we won't know directly the path of this sub-directory relative to the base directory.
      @relativePath = @parent.relativePath + @name + "/"
      #N Without @pathElements, we won't know directly the chain of local names from the base directory to this sub-directory.
      @pathElements = @parent.pathElements + [name]
      #N Without @fullPath we won't know the actual full name of this file in the file system (and we won't be able to directly perform file system operations on the file)
      @fullPath = @parent.fullPath + @name + "/"
    end
  end
  
  # An object representing the base directory
  #N Without this, we won't be able to record information about the directory which is the very base of the directory tree.
  class BaseDirectory<Directory
    
    # Function to decide if files should be included (if nil, assume all included). Subject
    # to exclusion by fileExclude
    #N Without this, we cannot specify that only some files should be included
    attr_reader :fileInclude
    
    # Function to decide if files should be excluded
    #N Without this, we cannot specify a criterion for excluding files
    attr_reader :fileExclude
    
    # Function to decide if sub-directories should be excluded (if a directory is excluded, so 
    # are all it's sub-directories and files contained within)
    #N Without this, we cannot specify a criterion for excluding directories
    attr_reader :dirExclude
    
    # Initialise from absolute file path. Options include :dirExclude, :fileInclude and :fileExclude
    #N If we don't initialize, then the BaseDirectory won't be configured correctly with the information required for the operation of the methods defined in Directory. Also the file/directory inclusion/exclusion criteria won't be applied.
    def initialize(path, options = {})
      #N If we don't call super(), then @entries won't get initialised
      super()
      #N If @name isn't nil, then we will think that the base directory is a sub-directory of some other directory, but for the purpose of being in the directory tree, it has not parent.
      @name = nil
      #N If @parent isn't nil, then we will think that the base directory is a sub-directory of some other directory, but for the purpose of being in the directory tree, it has not parent.
      @parent = nil
      #N If @base isn't self, we won't know that this directory _is_ the base of the directory tree
      @base = self
      #N Without @relativePath, we won't know the path of this directory relative to the base directory (which is itself)
      @relativePath = ""
      #N Without @pathElements, we won't know the chain of directory names from the base directory (which is itself) to itself
      @pathElements = []
      #N Without @fullPath we won't know the actual full name of this file in the file system (and we won't be able to directly perform file system operations on the file)
      @fullPath = path.end_with?("/") ? path : path + "/"
      #N Without @dirExclude, we won't be able to apply an exclusion criterion to exclude some sub-directories
      @dirExclude = options.fetch(:dirExclude, nil)
      #N Without @fileInclude, we won't be able to apply an inclusion criterion to only include some files (or we would have to indirectly specify an exclusion criterion)
      @fileInclude = options.fetch(:fileInclude, nil)
      #N Without @fileExclude, we won't be able to apply an exclusion criterion to exclude some files
      @fileExclude = options.fetch(:fileExclude, nil)
    end
  end
  
  # An object representing a file within the base directory
  #N Without this, we would have no way to record information about a file in the directory tree
  class File
    # immediate name of file
    #N Without name, we won't know what the name of the file is
    attr_reader :name
    
    # parent, i.e. containing directory
    #N Without parent, we won't know what directory the file is in
    attr_reader :parent
    
    # the base directory
    #N Without base, we won't know what is the base directory of the directory tree that this file is considered to belong to.
    attr_reader :base
    
    # path of this file relative to base directory
    #N Without relativePath, we won't know the path of this file relative to the base directory
    attr_reader :relativePath
    
    # elements of file path (including the name) as an array
    #N Without pathElements, we won't directly know the chain of sub-directories leading from the base directory to this file
    attr_reader :pathElements
    
    # full absolute path name of file
    #N Without fullPath, we won't know the absolute file path of this file, so we won't be able to perform file system operations directly on the file
    attr_reader :fullPath
    
    # initialise from name and containing directory
    #N If we don't initialize, then none of the information about the file (as derived from its name and it's parent directory) will be recorded
    def initialize(name, parent)
      #N If we don't call super, then ... (todo: possibly doesn't matter?)
      super()
      #N Without setting @name, we won't know the file's name
      @name = name
      #N Without setting @parent, we won't have a link to the directory containing the file
      @parent = parent
      #N Without setting @base, we won't have a link to the base directory
      @base = @parent.base
      #N Without setting @relativePath, we won't have the correct value for the file path relative to the base directory
      @relativePath = @parent.relativePath + @name
      #N Without setting @pathElements, we won't has a a correct chain of path elements from base directory to this file
      @pathElements = @parent.pathElements + [name]
      #N Without setting @fullPath, we won't have the correct full path of the file for performing file system operations on the file
      @fullPath = @parent.fullPath + @name
    end
    
  end
  
end
