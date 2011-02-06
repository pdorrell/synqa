
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
  
  def findDirectoriesOutput(baseDir)
    return getCommandOutput(findDirectoriesCommand(baseDir))
  end
  
  def listDirectories(baseDir)
    output = findDirectoriesOutput(baseDir)
    directories = []
    baseDirLen = baseDir.length
    while (line = output.gets)
      line = line.chomp
      if line.start_with?(baseDir)
        directories << line[baseDirLen..-1]
      else
        raise "Directory #{line} is not a sub-directory of base directory #{baseDir}"
      end
    end
    return directories
  end
end

class CygwinLocalContentReader<DirContentReader
  
  def initialize(hashCommand, cygwinPath = "")
    super(hashCommand, nil, nil, cygwinPath)
    puts "pathPrefix = #{@pathPrefix}"
  end

  def getCommandOutput(command)
    puts "#{command.inspect} ..."
    return IO.popen([{"CYGWIN" => "nodosfilewarning"}] + command)
  end    
end

  
  
