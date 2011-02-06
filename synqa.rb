
class HashCommand
  
  attr_reader :command, :length, :spacerLen
  
  def initialize(command, length, spacerLen)
    @command = command
    @length = length
    @spacerLen = spacerLen
  end
end

class Sha256SumCommand<HashCommand
  def initialize
    super(["sha256sum"], 64, 2)
  end
end

class DirContentReader
    
  attr_reader :shell, :host, :pathPrefix, :hashCommand
    
  def initialize(hashCommand, shell, host, pathPrefix = "")
    puts "DirContentReader.initialize , hashCommand = #{hashCommand} pathPrefix = #{pathPrefix}"
    @hashCommand = hashCommand
    @shell = shell
    @host = host
    @pathPrefix = pathPrefix
  end
  
  def findDirectoriesCommand(baseDir)
    return ["#{@pathPrefix}find.exe", baseDir, "-type", "d", "-print"]
  end
  
  def listDirectories(baseDir)
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
    return ["#{@pathPrefix}find.exe", baseDir, "-type", "f", "-print"]
  end
  
  def listFileHashLines(baseDir)
    output = getCommandOutput(findFilesCommand(baseDir))
    hashLines = []
    baseDirLen = baseDir.length
    puts "Listing files ..."
    while (line = output.gets)
      filePath = line.chomp
      puts " #{filePath}"
      if filePath.start_with?(baseDir)
        relativePath = filePath[baseDirLen..-1]
        hashLine = getFileHashLine(filePath)
        hashLines << hashLine
      else
        raise "File #{filePath} is not contained within base directory #{baseDir}"
      end
    end
    return hashLines
  end
    
end

class CygwinLocalContentReader<DirContentReader
  
  def initialize(hashCommand, cygwinPath = "")
    super(hashCommand, nil, nil, cygwinPath)
    puts "pathPrefix = #{@pathPrefix}"
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

  def getCommandOutput(command)
    puts "#{command.inspect} ..."
    return IO.popen([{"CYGWIN" => "nodosfilewarning"}] + command)
  end    
end

  
  
