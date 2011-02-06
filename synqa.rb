
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
  
  def listFileHashes(baseDir)
    output = getCommandOutput(findFilesCommand(baseDir))
    files = []
    baseDirLen = baseDir.length
    puts "Listing files ..."
    while (line = output.gets)
      filePath = line.chomp
      puts " #{filePath}"
      if line.start_with?(baseDir)
        relativePath = filePath[baseDirLen..-1]
        hash = getFileHash(filePath)
        files << [relativePath, hash]
      else
        raise "File #{line} is not contained within base directory #{baseDir}"
      end
    end
    return files
  end
    
end

class CygwinLocalContentReader<DirContentReader
  
  def initialize(hashCommand, cygwinPath = "")
    super(hashCommand, nil, nil, cygwinPath)
    puts "pathPrefix = #{@pathPrefix}"
  end
  
  def getFileHash(filePath)
    output = getCommandOutput([pathPrefix + hashCommand[0]] + hashCommand[1..-1] + [filePath])
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

  
  
