
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

class DirContentReader
    
  attr_reader :hashCommand, :pathPrefix
    
  def initialize(hashCommand, pathPrefix = "")
    @hashCommand = hashCommand
    @pathPrefix = pathPrefix
  end
  
  def findDirectoriesCommand(baseDir)
    return ["#{@pathPrefix}find", baseDir, "-type", "d", "-print"]
  end
  
  def normalisedDir(baseDir)
    return baseDir.end_with?("/") ? baseDir : baseDir + "/"
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
      fileHashes << self.hashCommand.parseFileHashLine(baseDir, fileHashLine)
    end
    return fileHashes
  end
    
  def getCommandOutput(command)
    puts "#{command.inspect} ..."
    return IO.popen(command)
  end    
end

class SshContentReader<DirContentReader
  
  attr_reader :shell, :host
    
  def initialize(hashCommand, shell, host)
    super(hashCommand)
    @shell = shell.is_a?(String) ? [shell] : shell
    @host = host
  end
  
  def locationDescriptor(baseDir)
    baseDir = normalisedDir(baseDir)
    return "#{host}:#{baseDir} (shell = #{shell}, hashCommand = #{hashCommand})"
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

class CygwinLocalContentReader<DirContentReader
  
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
  attr_reader :name, :hash
  
  def initialize(name, hash)
    @name = name
    @hash = hash
  end
  
  def to_s
    return "#{name} (#{hash})"
  end
end
  
class ContentTree
  attr_reader :name, :files, :dirs, :fileByName, :dirByName
  
  def initialize(name)
    @name = name
    @files = []
    @dirs = []
    @fileByName = {}
    @dirByName = {}
  end
  
  def getPathElements(path)
    return path.is_a?(String) ? (path == "" ? [] : path.split("/")) : path
  end
  
  def getContentTreeForSubDir(subDir)
    dirContentTree = dirByName.fetch(subDir, nil)
    if dirContentTree == nil
      dirContentTree = ContentTree.new(subDir)
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
      fileContent = FileContent.new(fileName, hash)
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
    nextIndent = currentIndent + indent
    for dir in dirs do
      dir.showIndented("#{dir.name}/", indent = indent, currentIndent = nextIndent)
    end
    for file in files do
      puts "#{nextIndent}#{file.name}  - #{file.hash}"
    end
  end
end

class ContentLocation
  attr_reader :host, :baseDir
  
  def initialize(host, baseDir)
    @host = host
    @baseDir = baseDir
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
    contentTree = ContentTree.new(baseDir)
    for dir in listDirectories()
      contentTree.addDir(dir)
    end
    for fileHash in listFileHashes()
      contentTree.addFile(fileHash.relativePath, fileHash.hash)
    end
    return contentTree
  end
end

