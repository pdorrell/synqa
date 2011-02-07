
class RelativePathWithHash
  attr_reader :relativePath, :hash
  
  def initialize(relativePath, hash)
    @relativePath = relativePath
    @hash = hash
  end
  
  def inspect
    return "RelativePathWithHash[#{relativePath}, #{hash}]"
  end
end

class HashCommand
  
  attr_reader :command, :length, :spacerLen
  
  def initialize(command, length, spacerLen)
    @command = command
    @length = length
    @spacerLen = spacerLen
  end
  
  def parseFileHashLine(baseDir, fileHashLine)
    hash = fileHashLine[0...length]
    fullPath = fileHashLine[(length + spacerLen)..-1]
    if fullPath.start_with?(baseDir)
      return RelativePathWithHash.new(fullPath[baseDir.length..-1], hash)
    elsif fullPath == "-"
      puts "Ignoring hash line for '-' file (caused by no files in directory)"
      return nil
    else
      raise "File #{fullPath} from hash line is not in base dir #{baseDir}"
    end
  end
  
  def to_s
    return command.join(" ")
  end
end

class Sha256SumCommand<HashCommand
  def initialize
    super(["sha256sum"], 64, 2)
  end
end

class Sha256Command<HashCommand
  def initialize
    super(["sha256", "-r"], 64, 1)
  end
end

def normalisedDir(baseDir)
  return baseDir.end_with?("/") ? baseDir : baseDir + "/"
end
  
class DirContentHost
    
  attr_reader :hashCommand, :pathPrefix
    
  def initialize(hashCommand, pathPrefix = "")
    @hashCommand = hashCommand
    @pathPrefix = pathPrefix
  end
  
  def findDirectoriesCommand(baseDir)
    return ["#{@pathPrefix}find", baseDir, "-type", "d", "-print"]
  end
  
  def listDirectories(baseDir)
    baseDir = normalisedDir(baseDir)
    output = getCommandOutput(findDirectoriesCommand(baseDir))
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
    return directories
  end
  
  def findFilesCommand(baseDir)
    return ["#{@pathPrefix}find", baseDir, "-type", "f", "-print"]
  end
  
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
    
  def getCommandOutput(command)
    puts "#{command.inspect} ..."
    return IO.popen(command)
  end    

  def getContentTree(baseDir)
    contentTree = ContentTree.new()
    for dir in listDirectories(baseDir)
      contentTree.addDir(dir)
    end
    for fileHash in listFileHashes(baseDir)
      contentTree.addFile(fileHash.relativePath, fileHash.hash)
    end
    return contentTree
  end
end

class SshContentHost<DirContentHost
  
  attr_reader :shell, :scpProgram, :host
    
  def initialize(hashCommand, shell, scpProgram, host)
    super(hashCommand)
    @shell = shell.is_a?(String) ? [shell] : shell
    @scpProgram = scpProgram.is_a?(String) ? [scpProgram] : scpProgram
    @host = host
  end
  
  def locationDescriptor(baseDir)
    baseDir = normalisedDir(baseDir)
    return "#{host}:#{baseDir} (connect = #{shell}/#{scpProgram}, hashCommand = #{hashCommand})"
  end
  
  def executeRemoteCommand(commandString)
    output = getCommandOutput(shell + [host, commandString])
    puts " executing #{commandString} on #{host} using #{shell.join(" ")} ..."
    while (line = output.gets)
      yield line.chomp
    end
  end
    
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

  def listFileHashLines(baseDir)
    baseDir = normalisedDir(baseDir)
    remoteFileHashLinesCommand = findFilesCommand(baseDir) + ["|", "xargs"] + @hashCommand.command
    executeRemoteCommand(remoteFileHashLinesCommand.join(" ")) do |line| 
      puts " #{line}"
      yield line 
    end
  end
end

class CygwinLocalContentHost<DirContentHost
  
  def initialize(hashCommand, cygwinPath = "")
    super(hashCommand, cygwinPath)
  end
  
  def locationDescriptor(baseDir)
    baseDir = normalisedDir(baseDir)
    return "#{baseDir} (cygwinPath = #{pathPrefix.inspect}, hashCommand = #{hashCommand})"
  end

  def getFileHashLine(filePath)
    command = hashCommand.command
    output = getCommandOutput([pathPrefix + command[0]] + command[1..-1] + [filePath])
    puts "  hash of #{filePath}"
    hashLine = nil
    while (line = output.gets)
      hashLine = line.chomp
      puts "    #{hashLine}"
    end
    return hashLine
  end

  def listFileHashLines(baseDir)
    baseDir = normalisedDir(baseDir)
    output = getCommandOutput(findFilesCommand(baseDir))
    baseDirLen = baseDir.length
    puts "Listing files ..."
    while (line = output.gets)
      filePath = line.chomp
      puts " #{filePath}"
      if filePath.start_with?(baseDir)
        relativePath = filePath[baseDirLen..-1]
        yield getFileHashLine(filePath)
      else
        raise "File #{filePath} is not contained within base directory #{baseDir}"
      end
    end
  end

  def getCommandOutput(command)
    puts "#{command.inspect} ..."
    return IO.popen([{"CYGWIN" => "nodosfilewarning"}] + command)
  end    
end

class FileContent
  attr_reader :name, :hash, :parentPathElements, :copyDestination, :toBeDeleted
  
  def initialize(name, hash, parentPathElements)
    @name = name
    @hash = hash
    @parentPathElements = parentPathElements
    @copyDestination = nil
    @toBeDeleted = false
  end
  
  def markToCopy(destinationDirectory)
    @copyDestination = destinationDirectory
  end
  
  def markToDelete
    @toBeDeleted = true
  end
  
  def to_s
    return "#{name} (#{hash})"
  end
  
  def fullPath
    return parentPathElements.join("/")
  end
end

class ContentTree
  attr_reader :name, :pathElements, :files, :dirs, :fileByName, :dirByName
  attr_reader :copyDestination, :toBeDeleted
  
  def initialize(name = nil, parentPathElements = nil)
    @name = name
    @pathElements = name == nil ? [] : parentPathElements + [name]
    @files = []
    @dirs = []
    @fileByName = {}
    @dirByName = {}
    @copyDestination = nil
    @toBeDeleted = false
  end
  
  def markToCopy(destinationDirectory)
    @copyDestination = destinationDirectory
  end
  
  def markToDelete
    @toBeDeleted = true
  end
  
  def fullPath
    return @pathElements.join("/")
  end
  
  def getPathElements(path)
    return path.is_a?(String) ? (path == "" ? [] : path.split("/")) : path
  end
  
  def getContentTreeForSubDir(subDir)
    dirContentTree = dirByName.fetch(subDir, nil)
    if dirContentTree == nil
      dirContentTree = ContentTree.new(subDir, @pathElements)
      dirs << dirContentTree
      dirByName[subDir] = dirContentTree
    end
    return dirContentTree
  end
  
  def addDir(dirPath)
    pathElements = getPathElements(dirPath)
    if pathElements.length > 0
      pathStart = pathElements[0]
      restOfPath = pathElements[1..-1]
      getContentTreeForSubDir(pathStart).addDir(restOfPath)
    end
  end
  
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
  
  def showIndented(name = "", indent = "  ", currentIndent = "")
    puts "#{currentIndent}#{name}"
    if copyDestination != nil
      puts "#{currentIndent} [COPY to #{copyDestination.fullPath}]"
    end
    if toBeDeleted
      puts "#{currentIndent} [DELETE]"
    end
    nextIndent = currentIndent + indent
    for dir in dirs do
      dir.showIndented("#{dir.name}/", indent = indent, currentIndent = nextIndent)
    end
    for file in files do
      puts "#{nextIndent}#{file.name}  - #{file.hash}"
      if file.copyDestination != nil
        puts "#{nextIndent} [COPY to #{file.copyDestination.fullPath}]"
      end
      if file.toBeDeleted
        puts "#{nextIndent} [DELETE]"
      end
    end
  end
  
  def writeLinesToFile(outFile, prefix = "")
    for dir in dirs do
      outFile.puts("D #{prefix}#{dir.name}\n")
      dir.writeLinesToFile(outFile, "#{prefix}#{dir.name}/")
    end
    for file in files do
      outFile.puts("F #{file.hash} #{prefix}#{file.name}\n")
    end
  end
  
  def writeToFile(fileName)
    puts "Writing content tree to file #{fileName} ..."
    outFile = File.open(fileName, "w")
    writeLinesToFile(outFile)
    outFile.close()
    puts " content tree written to file #{fileName}"
  end
  
  @@dirLineRegex = /^D (.*)$/
  @@fileLineRegex = /^F ([^ ]*) (.*)$/
  
  def self.readFromFile(fileName, name = "")
    puts "Reading content tree from file #{fileName} ..."
    contentTree = ContentTree.new(name)
    File.open(fileName).each_line do |line|
      puts " line #{line}"
      dirLineMatch = @@dirLineRegex.match(line)
      if dirLineMatch
        dirName = dirLineMatch[1]
        puts " adding directory #{dirName} ..."
        contentTree.addDir(dirName)
      else
        fileLineMatch = @@fileLineRegex.match(line)
        if fileLineMatch
          hash = fileLineMatch[1]
          fileName = fileLineMatch[2]
          puts " adding file hash #{fileName} #{hash} ..."
          contentTree.addFile(fileName, hash)
        else
          raise "Invalid line in content tree file: #{line.inspect}"
        end
      end
    end
    return contentTree
  end
  
  def markSyncOperationsForDestination(destination)
    markCopyOperations(destination)
    destination.markDeleteOptions(self)
  end
  
  def getDir(dir)
    return dirByName.fetch(dir, nil)
  end
  
  def getFile(file)
    return fileByName.fetch(file, nil)
  end
  
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

class ContentLocation
  attr_reader :host, :baseDir, :cachedContentFile
  
  def initialize(host, baseDir, cachedContentFile = nil)
    @host = host
    @baseDir = normalisedDir(baseDir)
    @cachedContentFile = cachedContentFile
  end
  
  def listDirectories
    return host.listDirectories(baseDir)
  end
  
  def listFileHashes
    return host.listFileHashes(baseDir)
  end
  
  def to_s
    return host.locationDescriptor(baseDir)
  end
  
  def getContentTree
    contentTree = host.getContentTree(baseDir)
    if cachedContentFile != nil
      contentTree.writeToFile(cachedContentFile)
    end
    return contentTree
  end
  
  def getCachedContentTree
    if cachedContentFile == nil
      puts "No cached content file specified for location"
      return nil
    elsif File.exists?(cachedContentFile)
      return ContentTree.readFromFile(cachedContentFile, baseDir)
    else
      puts "Cached content file #{cachedContentFile} does not yet exist."
      return nil
    end
  end
  
end

class SyncOperation
  attr_reader :sourceLocation, :destinationLocation
  
  def initialize(sourceLocation, destinationLocation)
    @sourceLocation = sourceLocation
    @destinationLocation = destinationLocation
  end
  
  def getContentTrees
    @sourceContent = @sourceLocation.getContentTree()
    @destinationContent = @destinationLocation.getContentTree()
  end
  
  def markSyncOperations
    @sourceContent.markSyncOperationsForDestination(@destinationContent)
    puts " ================================================ "
    puts "After marking for sync --"
    @sourceContent.showIndented()
    @destinationContent.showIndented()
  end
end

