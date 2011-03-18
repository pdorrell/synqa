require 'time'

module Synqa

  # Check if the last executed process exited with status 0, if not, raise an exception
  def checkProcessStatus(description)
    processStatus = $?
    if not processStatus.exited?
      raise "#{description}: process did not exit normally"
    end
    exitStatus = processStatus.exitstatus
    if exitStatus != 0
      raise "#{description}: exit status = #{exitStatus}"
    end
  end
    
  # An object representing a file path relative to a base directory, and a hash string
  class RelativePathWithHash
    # The relative file path (e.g. c:/dir/subdir/file.txt relative to c:/dir would be subdir/file.txt)
    attr_reader :relativePath
    
    # The hash code, e.g. a1c5b67fdb3cf0df8f1d29ae90561f9ad099bada44aeb6b2574ad9e15f2a84ed
    attr_reader :hash
    
    def initialize(relativePath, hash)
      @relativePath = relativePath
      @hash = hash
    end
    
    def inspect
      return "RelativePathWithHash[#{relativePath}, #{hash}]"
    end
  end

  # A command to be executed on the remote system which calculates a hash value for
  # a file (of a given length), in the format: *hexadecimal-hash* *a-fixed-number-of-characters* *file-name*
  class HashCommand
    # The command - a string or array of strings e.g. "sha256sum" or ["sha256", "-r"]
    attr_reader :command 

    # The length of the calculated hash value e.g. 64 for sha256
    attr_reader :length
    
    # The number of characters between the hash value and the file name (usually 1 or 2)
    attr_reader :spacerLen
    
    def initialize(command, length, spacerLen)
      @command = command
      @length = length
      @spacerLen = spacerLen
    end

    # Parse a hash line relative to a base directory, returning a RelativePathWithHash
    def parseFileHashLine(baseDir, fileHashLine)
      hash = fileHashLine[0...length]
      fullPath = fileHashLine[(length + spacerLen)..-1]
      if fullPath.start_with?(baseDir)
        return RelativePathWithHash.new(fullPath[baseDir.length..-1], hash)
      else
        raise "File #{fullPath} from hash line is not in base dir #{baseDir}"
      end
    end
    
    def to_s
      return command.join(" ")
    end
  end
  
  # Hash command for sha256sum, which generates a 64 hexadecimal digit hash, and outputs two characters between
  # the hash and the file name.
  class Sha256SumCommand<HashCommand
    def initialize
      super(["sha256sum"], 64, 2)
    end
  end
  
  # Hash command for sha256, which generates a 64 hexadecimal digit hash, and outputs one character between
  # the hash and the file name, and which requires a "-r" argument to put the hash value first.  
  class Sha256Command<HashCommand
    def initialize
      super(["sha256", "-r"], 64, 1)
    end
  end
  
  # Put "/" at the end of a directory name if it is not already there.
  def normalisedDir(baseDir)
    return baseDir.end_with?("/") ? baseDir : baseDir + "/"
  end
  

  # Base class for an object representing a remote system where the contents of a directory
  # on the system are enumerated by one command to list all sub-directories and another command 
  # to list all files in the directory and their hash values.
  class DirContentHost
    
    # The HashCommand object used to calculate and parse hash values of files
    attr_reader :hashCommand
    
    # Prefix required for *find* command (usually nothing, since it should be on the system path)
    attr_reader :pathPrefix
    
    def initialize(hashCommand, pathPrefix = "")
      @hashCommand = hashCommand
      @pathPrefix = pathPrefix
    end
    
    # Generate the *find* command which will list all the sub-directories of the base directory
    def findDirectoriesCommand(baseDir)
      return ["#{@pathPrefix}find", baseDir, "-type", "d", "-print"]
    end
    
    # Return the list of sub-directories relative to the base directory
    def listDirectories(baseDir)
      baseDir = normalisedDir(baseDir)
      command = findDirectoriesCommand(baseDir)
      output = getCommandOutput(command)
      directories = []
      baseDirLen = baseDir.length
      puts "Listing directories ..."
      while (line = output.gets)
        line = line.chomp
        puts " #{line}"
        if line.start_with?(baseDir)
          directories << line[baseDirLen..-1]
        else
          raise "Directory #{line} is not a sub-directory of base directory #{baseDir}"
        end
      end
      output.close()
      checkProcessStatus(command)
      return directories
    end
    
    # Generate the *find* command which will list all the files within the base directory
    def findFilesCommand(baseDir)
      return ["#{@pathPrefix}find", baseDir, "-type", "f", "-print"]
    end

    # List file hashes by executing the command to hash each file on the output of the
    # *find* command which lists all files, and parse the output.
    def listFileHashes(baseDir)
      baseDir = normalisedDir(baseDir)
      fileHashes = []
      listFileHashLines(baseDir) do |fileHashLine|
        fileHash = self.hashCommand.parseFileHashLine(baseDir, fileHashLine)
        if fileHash != nil
          fileHashes << fileHash
        end
      end
      return fileHashes
    end
    
    # Return the enumerated lines of the command's output
    def getCommandOutput(command)
      puts "#{command.inspect} ..."
      return IO.popen(command)
    end    
    
    # Construct the ContentTree for the given base directory
    def getContentTree(baseDir)
      contentTree = ContentTree.new()
      contentTree.time = Time.now.utc
      for dir in listDirectories(baseDir)
        contentTree.addDir(dir)
      end
      for fileHash in listFileHashes(baseDir)
        contentTree.addFile(fileHash.relativePath, fileHash.hash)
      end
      return contentTree
    end
  end
  
  # Representation of a remote system accessible via SSH
  class SshContentHost<DirContentHost
    
    # The SSH client, e.g. ["ssh"] or ["plink","-pw","mysecretpassword"] (i.e. command + args as an array)
    attr_reader :shell
    
    # The SCP client, e.g. ["scp"] or ["pscp","-pw","mysecretpassword"] (i.e. command + args as an array)
    attr_reader :scpProgram
    
    # The remote host, e.g. "username@host.example.com"
    attr_reader :host
    
    # The SCP command as a string
    attr_reader :scpCommandString
    
    def initialize(host, hashCommand, shell, scpProgram)
      super(hashCommand)
      @host = host
      @shell = shell.is_a?(String) ? [shell] : shell
      @scpProgram = scpProgram.is_a?(String) ? [scpProgram] : scpProgram
      @scpCommandString = @scpProgram.join(" ")
    end
    
    # Return readable description of base directory on remote system
    def locationDescriptor(baseDir)
      baseDir = normalisedDir(baseDir)
      return "#{host}:#{baseDir} (connect = #{shell}/#{scpProgram}, hashCommand = #{hashCommand})"
    end
    
    # execute an SSH command on the remote system, yielding lines of output
    # (or don't actually execute, if dryRun is true)
    def executeRemoteCommand(commandString, dryRun = false)
      puts "SSH #{host} (#{shell.join(" ")}): executing #{commandString}"
      if not dryRun
        output = getCommandOutput(shell + [host, commandString])
        while (line = output.gets)
          yield line.chomp
        end
        output.close()
        checkProcessStatus("SSH #{host} #{commandString}")
      end
    end
    
    # execute an SSH command on the remote system, displaying output to stdout, 
    # (or don't actually execute, if dryRun is true)
    def ssh(commandString, dryRun = false)
      executeRemoteCommand(commandString, dryRun) do |line|
        puts line
      end
    end
    
    # Return a list of all subdirectories of the base directory (as paths relative to the base directory)
    def listDirectories(baseDir)
      baseDir = normalisedDir(baseDir)
      puts "Listing directories ..."
      directories = []
      baseDirLen = baseDir.length
      executeRemoteCommand(findDirectoriesCommand(baseDir).join(" ")) do |line|
        puts " #{line}"
        if line.start_with?(baseDir)
          directories << line[baseDirLen..-1]
        else
          raise "Directory #{line} is not a sub-directory of base directory #{baseDir}"
        end
      end
      return directories
    end
    
    # Yield lines of output from the command to display hash values and file names
    # of all files within the base directory
    def listFileHashLines(baseDir)
      baseDir = normalisedDir(baseDir)
      remoteFileHashLinesCommand = findFilesCommand(baseDir) + ["|", "xargs", "-r"] + @hashCommand.command
      executeRemoteCommand(remoteFileHashLinesCommand.join(" ")) do |line| 
        puts " #{line}"
        yield line 
      end
    end
    
    # List all files within the base directory to stdout
    def listFiles(baseDir)
      baseDir = normalisedDir(baseDir)
      executeRemoteCommand(findFilesCommand(baseDir).join(" ")) do |line| 
        puts " #{line}"
      end
    end
    
    # Get the remote path of the directory or file on the host, in the format required by SCP
    def getScpPath(path)
      return host + ":" + path
    end
  end
  
  # An object representing the content of a file within a ContentTree.
  # The file may be marked for copying (if it's in a source ContentTree) 
  # or for deletion (if it's in a destination ContentTree)
  class FileContent
    # The name of the file
    attr_reader :name
    
    # The hash value of the file's contents
    attr_reader :hash
    
    # The components of the relative path where the file is found
    attr_reader :parentPathElements
    
    # The destination to which the file should be copied
    attr_reader :copyDestination
    
    # Should this file be deleted
    attr_reader :toBeDeleted
    
    def initialize(name, hash, parentPathElements)
      @name = name
      @hash = hash
      @parentPathElements = parentPathElements
      @copyDestination = nil
      @toBeDeleted = false
    end
    
    # Mark this file to be copied to a destination directory (from a destination content tree)
    def markToCopy(destinationDirectory)
      @copyDestination = destinationDirectory
    end
    
    # Mark this file to be deleted
    def markToDelete
      @toBeDeleted = true
    end
    
    def to_s
      return "#{name} (#{hash})"
    end
    
    # The full (relative) name of this file in the content tree
    def fullPath
      return (parentPathElements + [name]).join("/")
    end
  end
  
  # A "content tree" consisting of a description of the contents of files and
  # sub-directories within a base directory. The file contents are described via
  # cryptographic hash values.
  # Each sub-directory within a content tree is also represented as a ContentTree.
  class ContentTree
    # name of the sub-directory within the containing directory (or nil if this is the base directory)
    attr_reader :name
    
    # path elements from base directory leading to this one
    attr_reader :pathElements
    
    # files within this sub-directory (as FileContent's)
    attr_reader :files
    
    # immediate sub-directories of this directory
    attr_reader :dirs
    
    # the files within this sub-directory, indexed by file name
    attr_reader :fileByName
    
    # immediate sub-directories of this directory, indexed by name  
    attr_reader :dirByName
    
    # where this directory should be copied to
    attr_reader :copyDestination
    
    # whether this directory should be deleted
    attr_reader :toBeDeleted
    
    # the UTC time (on the local system, even if this content tree represents a remote directory)
    # that this content tree was constructed. Only set for the base directory.
    attr_accessor :time
    
    def initialize(name = nil, parentPathElements = nil)
      @name = name
      @pathElements = name == nil ? [] : parentPathElements + [name]
      @files = []
      @dirs = []
      @fileByName = {}
      @dirByName = {}
      @copyDestination = nil
      @toBeDeleted = false
      @time = nil
    end
    
    # mark this directory to be copied to a destination directory
    def markToCopy(destinationDirectory)
      @copyDestination = destinationDirectory
    end
    
    # mark this directory (on a remote system) to be deleted
    def markToDelete
      @toBeDeleted = true
    end
    
    # the full path of the directory that this content tree represents (relative to the base directory)
    def fullPath
      return @pathElements.join("/")
    end
    
    # convert a path string to an array of path elements (or return it as is if it's already an array)
    def getPathElements(path)
      return path.is_a?(String) ? (path == "" ? [] : path.split("/")) : path
    end
    
    # get the content tree for a sub-directory (creating it if it doesn't yet exist)
    def getContentTreeForSubDir(subDir)
      dirContentTree = dirByName.fetch(subDir, nil)
      if dirContentTree == nil
        dirContentTree = ContentTree.new(subDir, @pathElements)
        dirs << dirContentTree
        dirByName[subDir] = dirContentTree
      end
      return dirContentTree
    end
    
    # add a sub-directory to this content tree
    def addDir(dirPath)
      pathElements = getPathElements(dirPath)
      if pathElements.length > 0
        pathStart = pathElements[0]
        restOfPath = pathElements[1..-1]
        getContentTreeForSubDir(pathStart).addDir(restOfPath)
      end
    end
    
    # recursively sort the files and sub-directories of this content tree alphabetically
    def sort!
      dirs.sort_by! {|dir| dir.name}
      files.sort_by! {|file| file.name}
      for dir in dirs
        dir.sort!
      end
    end
    
    # given a relative path, add a file and hash value to this content tree
    def addFile(filePath, hash)
      pathElements = getPathElements(filePath)
      if pathElements.length == 0
        raise "Invalid file path: #{filePath.inspect}"
      end
      if pathElements.length == 1
        fileName = pathElements[0]
        fileContent = FileContent.new(fileName, hash, @pathElements)
        files << fileContent
        fileByName[fileName] = fileContent
      else
        pathStart = pathElements[0]
        restOfPath = pathElements[1..-1]
        getContentTreeForSubDir(pathStart).addFile(restOfPath, hash)
      end
    end
    
    # date-time format for reading and writing times, e.g. "2007-12-23 13:03:99.012 +0000"
    @@dateTimeFormat = "%Y-%m-%d %H:%M:%S.%L %z"
    
    # pretty-print this content tree
    def showIndented(name = "", indent = "  ", currentIndent = "")
      if time != nil
        puts "#{currentIndent}[TIME: #{time.strftime(@@dateTimeFormat)}]"
      end
      if name != ""
        puts "#{currentIndent}#{name}"
      end
      if copyDestination != nil
        puts "#{currentIndent} [COPY to #{copyDestination.fullPath}]"
      end
      if toBeDeleted
        puts "#{currentIndent} [DELETE]"
      end
      nextIndent = currentIndent + indent
      for dir in dirs
        dir.showIndented("#{dir.name}/", indent = indent, currentIndent = nextIndent)
      end
      for file in files
        puts "#{nextIndent}#{file.name}  - #{file.hash}"
        if file.copyDestination != nil
          puts "#{nextIndent} [COPY to #{file.copyDestination.fullPath}]"
        end
        if file.toBeDeleted
          puts "#{nextIndent} [DELETE]"
        end
      end
    end

    # write this content tree to an open file, indented
    def writeLinesToFile(outFile, prefix = "")
      if time != nil
        outFile.puts("T #{time.strftime(@@dateTimeFormat)}\n")
      end
      for dir in dirs
        outFile.puts("D #{prefix}#{dir.name}\n")
        dir.writeLinesToFile(outFile, "#{prefix}#{dir.name}/")
      end
      for file in files
        outFile.puts("F #{file.hash} #{prefix}#{file.name}\n")
      end
    end
    
    # write this content tree to a file (in a format which readFromFile can read back in)
    def writeToFile(fileName)
      puts "Writing content tree to file #{fileName} ..."
      File.open(fileName, "w") do |outFile|
        writeLinesToFile(outFile)
      end
    end
    
    # regular expression for directory entries in content tree file
    @@dirLineRegex = /^D (.*)$/
    
    # regular expression for file entries in content tree file
    @@fileLineRegex = /^F ([^ ]*) (.*)$/
    
    # regular expression for time entry in content tree file
    @@timeRegex = /^T (.*)$/
    
    # read a content tree from a file (in format written by writeToFile)
    def self.readFromFile(fileName)
      contentTree = ContentTree.new()
      puts "Reading content tree from #{fileName} ..."
      IO.foreach(fileName) do |line|
        dirLineMatch = @@dirLineRegex.match(line)
        if dirLineMatch
          dirName = dirLineMatch[1]
          contentTree.addDir(dirName)
        else
          fileLineMatch = @@fileLineRegex.match(line)
          if fileLineMatch
            hash = fileLineMatch[1]
            fileName = fileLineMatch[2]
            contentTree.addFile(fileName, hash)
          else
            timeLineMatch = @@timeRegex.match(line)
            if timeLineMatch
              timeString = timeLineMatch[1]
              contentTree.time = Time.strptime(timeString, @@dateTimeFormat)
            else
              raise "Invalid line in content tree file: #{line.inspect}"
            end
          end
        end
      end
      return contentTree
    end

    # read a content tree as a map of hashes, i.e. from relative file path to hash value for the file
    # Actually returns an array of the time entry (if any) and the map of hashes
    def self.readMapOfHashesFromFile(fileName)
      mapOfHashes = {}
      time = nil
      File.open(fileName).each_line do |line|
        fileLineMatch = @@fileLineRegex.match(line)
          if fileLineMatch
            hash = fileLineMatch[1]
            fileName = fileLineMatch[2]
            mapOfHashes[fileName] = hash
          end
        timeLineMatch = @@timeRegex.match(line)
        if timeLineMatch
          timeString = timeLineMatch[1]
          time = Time.strptime(timeString, @@dateTimeFormat)
        end
      end
      return [time, mapOfHashes]
    end
    
    # Mark operations for this (source) content tree and the destination content tree
    # in order to synch the destination content tree with this one
    def markSyncOperationsForDestination(destination)
      markCopyOperations(destination)
      destination.markDeleteOptions(self)
    end
    
    # Get the named sub-directory content tree, if it exists
    def getDir(dir)
      return dirByName.fetch(dir, nil)
    end
    
    # Get the named file & hash value, if it exists
    def getFile(file)
      return fileByName.fetch(file, nil)
    end
    
    # Mark copy operations, given that the corresponding destination directory already exists.
    # For files and directories that don't exist in the destination, mark them to be copied.
    # For sub-directories that do exist, recursively mark the corresponding sub-directory copy operations.
    def markCopyOperations(destinationDir)
      for dir in dirs
        destinationSubDir = destinationDir.getDir(dir.name)
        if destinationSubDir != nil
          dir.markCopyOperations(destinationSubDir)
        else
          dir.markToCopy(destinationDir)
        end
      end
      for file in files
        destinationFile = destinationDir.getFile(file.name)
        if destinationFile == nil or destinationFile.hash != file.hash
          file.markToCopy(destinationDir)
        end
      end
    end
    
    # Mark delete operations, given that the corresponding source directory exists.
    # For files and directories that don't exist in the source, mark them to be deleted.
    # For sub-directories that do exist, recursively mark the corresponding sub-directory delete operations.
    def markDeleteOptions(sourceDir)
      for dir in dirs
        sourceSubDir = sourceDir.getDir(dir.name)
        if sourceSubDir == nil
          dir.markToDelete()
        else
          dir.markDeleteOptions(sourceSubDir)
        end
      end
      for file in files
        sourceFile = sourceDir.getFile(file.name)
        if sourceFile == nil
          file.markToDelete()
        end
      end
    end
  end
  
  # Base class for a content location which consists of a base directory
  # on a local or remote system.
  class ContentLocation
    
    # The name of a file used to hold a cached content tree for this location (can optionally be specified)
    attr_reader :cachedContentFile
    
    def initialize(cachedContentFile)
      @cachedContentFile = cachedContentFile
    end
    
    # Get the cached content file name, if specified, and if the file exists
    def getExistingCachedContentTreeFile
      if cachedContentFile == nil
        puts "No cached content file specified for location"
        return nil
      elsif File.exists?(cachedContentFile)
        return cachedContentFile
      else
        puts "Cached content file #{cachedContentFile} does not yet exist."
        return nil
      end
    end
    
    # Delete any existing cached content file
    def clearCachedContentFile
      if cachedContentFile and File.exists?(cachedContentFile)
        puts " deleting cached content file #{cachedContentFile} ..."
        File.delete(cachedContentFile)
      end
    end
    
    # Get the cached content tree (if any), read from the specified cached content file.
    def getCachedContentTree
      file = getExistingCachedContentTreeFile
      if file
        return ContentTree.readFromFile(file)
      else
        return nil
      end
    end
    
    # Read a map of file hashes (mapping from relative file name to hash value) from the
    # specified cached content file
    def getCachedContentTreeMapOfHashes
      file = getExistingCachedContentTreeFile
      if file
        puts "Reading cached file hashes from #{file} ..."
        return ContentTree.readMapOfHashesFromFile(file)
      else
        return [nil, {}]
      end
    end
    
  end
  
  # A directory of files on a local system. The corresponding content tree
  # can be calculated directly using Ruby library functions.
  class LocalContentLocation<ContentLocation
    
    # the base directory
    attr_reader :baseDirectory
    # the ruby class that generates the hash, e.g. Digest::SHA256
    attr_reader :hashClass
    
    def initialize(baseDirectory, hashClass, cachedContentFile = nil, options = {})
      super(cachedContentFile)
      @baseDirectory = baseDirectory
      @hashClass = hashClass
    end
    
    # get the path as required for an SCP command
    def getScpPath(relativePath)
      return getFullPath(relativePath)
    end
    
    # get the full path of a relative path (i.e. of a file/directory within the base directory)
    def getFullPath(relativePath)
      return @baseDirectory.fullPath + relativePath
    end
    
    # get the content tree for this base directory by iterating over all
    # sub-directories and files within the base directory (and excluding the excluded files)
    # and calculating file hashes using the specified Ruby hash class
    # If there is an existing cached content file, use that to get the hash values
    # of files whose modification time is earlier than the time value for the cached content tree.
    # Also, if a cached content file is specified, write the final content tree back out to the cached content file.
    def getContentTree
      cachedTimeAndMapOfHashes = getCachedContentTreeMapOfHashes
      cachedTime = cachedTimeAndMapOfHashes[0]
      cachedMapOfHashes = cachedTimeAndMapOfHashes[1]
      contentTree = ContentTree.new()
      contentTree.time = Time.now.utc
      for subDir in @baseDirectory.subDirs
        contentTree.addDir(subDir.relativePath)
      end
      for file in @baseDirectory.allFiles
        cachedDigest = cachedMapOfHashes[file.relativePath]
        if cachedTime and cachedDigest and File.stat(file.fullPath).mtime < cachedTime
          digest = cachedDigest
        else
          digest = hashClass.file(file.fullPath).hexdigest
        end
        contentTree.addFile(file.relativePath, digest)
      end
      contentTree.sort!
      if cachedContentFile != nil
        contentTree.writeToFile(cachedContentFile)
      end
      return contentTree
    end
  end
  
  # A directory of files on a remote system
  class RemoteContentLocation<ContentLocation
    # the remote username@host value
    attr_reader :host
    
    # the base directory on the remote system
    attr_reader :baseDir
    
    def initialize(host, baseDir, cachedContentFile = nil)
      super(cachedContentFile)
      @host = host
      @baseDir = normalisedDir(baseDir)
    end
    
    # list files within the base directory on the remote host
    def listFiles()
      host.listFiles(baseDir)
    end
    
    # the command string required to execute SCP (e.g. "scp" or "pscp", possibly with extra args)
    def scpCommandString
      return host.scpCommandString
    end
    
    # get the full path of a relative path
    def getFullPath(relativePath)
      return baseDir + relativePath
    end
    
    # get the full path of a file as required in an SCP command (i.e. with username@host prepended)
    def getScpPath(relativePath)
      return host.getScpPath(getFullPath(relativePath))
    end
    
    # execute an SSH command on the remote host (or just pretend, if dryRun is true)
    def ssh(commandString, dryRun = false)
      host.ssh(commandString, dryRun)
    end
    
    # list all sub-directories of the base directory on the remote host
    def listDirectories
      return host.listDirectories(baseDir)
    end
    
    # list all the file hashes of the files within the base directory
    def listFileHashes
      return host.listFileHashes(baseDir)
    end
    
    def to_s
      return host.locationDescriptor(baseDir)
    end

    # Get the content tree, from the cached content file if it exists, 
    # otherwise get if from listing directories and files and hash values thereof
    # on the remote host. And also, if the cached content file name is specified, 
    # write the content tree out to that file.
    def getContentTree
      if cachedContentFile and File.exists?(cachedContentFile)
        return ContentTree.readFromFile(cachedContentFile)
      else
        contentTree = host.getContentTree(baseDir)
        contentTree.sort!
        if cachedContentFile != nil
          contentTree.writeToFile(cachedContentFile)
        end
        return contentTree
      end
    end
    
  end
  
  # The operation of synchronising files on the remote directory with files on the local directory.
  class SyncOperation
    # The source location (presumed to be local)
    attr_reader :sourceLocation
    
    # The destination location (presumed to be remote)
    attr_reader :destinationLocation
    
    def initialize(sourceLocation, destinationLocation)
      @sourceLocation = sourceLocation
      @destinationLocation = destinationLocation
    end
    
    # Get the local and remote content trees
    def getContentTrees
      @sourceContent = @sourceLocation.getContentTree()
      @destinationContent = @destinationLocation.getContentTree()
    end
    
    # On the local and remote content trees, mark the copy and delete operations required
    # to sync the remote location to the local location.
    def markSyncOperations
      @sourceContent.markSyncOperationsForDestination(@destinationContent)
      puts " ================================================ "
      puts "After marking for sync --"
      puts ""
      puts "Local:"
      @sourceContent.showIndented()
      puts ""
      puts "Remote:"
      @destinationContent.showIndented()
    end
    
    # Delete the local and remote cached content files (which will force a full recalculation
    # of both content trees next time)
    def clearCachedContentFiles
      @sourceLocation.clearCachedContentFile()
      @destinationLocation.clearCachedContentFile()
    end
    
    # Do the sync. Options: :full = true means clear the cached content files first, :dryRun
    # means don't do the actual copies and deletes, but just show what they would be.
    def doSync(options = {})
      if options[:full]
        clearCachedContentFiles()
      end
      getContentTrees()
      markSyncOperations()
      dryRun = options[:dryRun]
      if not dryRun
        @destinationLocation.clearCachedContentFile()
      end
      doAllCopyOperations(dryRun)
      doAllDeleteOperations(dryRun)
      if (@destinationLocation.cachedContentFile and @sourceLocation.cachedContentFile and
          File.exists?(@sourceLocation.cachedContentFile))
        FileUtils::Verbose.cp(@sourceLocation.cachedContentFile, @destinationLocation.cachedContentFile)
      end
    end

    # Do all the copy operations, copying local directories or files which are missing from the remote location
    def doAllCopyOperations(dryRun)
      doCopyOperations(@sourceContent, @destinationContent, dryRun)
    end
    
    # Do all delete operations, deleting remote directories or files which do not exist at the local location
    def doAllDeleteOperations(dryRun)
      doDeleteOperations(@destinationContent, dryRun)
    end
    
    # Execute a (local) command, or, if dryRun, just pretend to execute it.
    # Raise an exception if the process exit status is not 0.
    def executeCommand(command, dryRun)
      puts "EXECUTE: #{command}"
      if not dryRun
        system(command)
        checkProcessStatus(command)
      end
    end
    
    # Recursively perform all marked copy operations from the source content tree to the
    # destination content tree, or if dryRun, just pretend to perform them.
    def doCopyOperations(sourceContent, destinationContent, dryRun)
      for dir in sourceContent.dirs
        if dir.copyDestination != nil
          sourcePath = sourceLocation.getScpPath(dir.fullPath)
          destinationPath = destinationLocation.getScpPath(dir.copyDestination.fullPath)
          executeCommand("#{destinationLocation.scpCommandString} -r #{sourcePath} #{destinationPath}", dryRun)
        else
          doCopyOperations(dir, destinationContent.getDir(dir.name), dryRun)
        end
      end
      for file in sourceContent.files
        if file.copyDestination != nil
          sourcePath = sourceLocation.getScpPath(file.fullPath)
          destinationPath = destinationLocation.getScpPath(file.copyDestination.fullPath)
          executeCommand("#{destinationLocation.scpCommandString} #{sourcePath} #{destinationPath}", dryRun)
        end
      end
    end
    
    # Recursively perform all marked delete operations on the destination content tree, 
    # or if dryRun, just pretend to perform them.
    def doDeleteOperations(destinationContent, dryRun)
      for dir in destinationContent.dirs
        if dir.toBeDeleted
          dirPath = destinationLocation.getFullPath(dir.fullPath)
          destinationLocation.ssh("rm -r #{dirPath}", dryRun)
        else
          doDeleteOperations(dir, dryRun)
        end
      end
      for file in destinationContent.files
        if file.toBeDeleted
          filePath = destinationLocation.getFullPath(file.fullPath)
          destinationLocation.ssh("rm #{filePath}", dryRun)
        end
      end
    end
  end
end
