
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
    return "#{@pathPrefix}find #{baseDir} -type d -print"
  end
  
  def findDirectories(baseDir)
    command = findDirectoriesCommand(baseDir)
    puts "#{command} ..."
    system({"CYGWIN" => "nodosfilewarning"}, command)
  end
end

class CygwinLocalContentReader<DirContentReader
  
  def initialize(hashCommand, cygwinPath = "")
    super(hashCommand, nil, nil, cygwinPath)
    puts "pathPrefix = #{@pathPrefix}"
  end

end

  
  
