#N If time is not required, we won't be able to get current time to write in the content tree
require 'time'
#N If net/ssh is not required, we won't be able to log in using Ruby SSH
require 'net/ssh'
#N If net/scp is not required,  we won't be able to copy files using Ruby SCP
require 'net/scp'
#N If fileutils is not required, we won't be able to create local directories or copy local files
require 'fileutils'

#N If module is not defined, methods & class names may conflict with top-level objects in other code
module Synqa

  # ensure that a directory exists
  #N If not defined, there won't be a convenient way for calling code to create a directory for putting cached content files in
  def ensureDirectoryExists(directoryName)
    #N If we don't check that a directory exists, we'll get an error trying to create a directory that already exists
    if File.exist? directoryName
      #N If we don't check that the existing directory is a directory, then the calling code will assume it exists, but actually it's a file (or maybe a symlink)
      if not File.directory? directoryName
        #N If we don't raise this as a fatal error, then we would have to think of some way to carry on, which there isn't really
        raise "#{directoryName} is a non-directory file"
      end
    else
      #N If we don't call this, the missing directory won't get created.
      FileUtils.makedirs(directoryName)
    end
  end

  # Return the enumerated lines of the command's output
  def getCommandOutput(command)
    #N If we don't output the command it won't be echoed before it's output appears
    puts "#{command.inspect} ..."
    #N If we don't call this, the command won't run(?) and it's output won't be available
    return IO.popen(command)
  end    
    
  # Check if the last executed process exited with status 0, if not, raise an exception
  def checkProcessStatus(description)
    #N Without this, we won't know the status of the last process
    processStatus = $?
    #N If we don't check for exited, then we might report an invalid or undefined status value
    if not processStatus.exited?
      raise "#{description}: process did not exit normally"
    end
    #N Without this, we won't know if the status was non-zero
    exitStatus = processStatus.exitstatus
    #N If we don't check for zero, then we'll always raise an error, even for success
    if exitStatus != 0
      #N If we don't raise the error, then an invalid exit status will seem to exit successfully
      raise "#{description}: exit status = #{exitStatus}"
    end
  end
    
  # An object representing a file path relative to a base directory, and a hash string
  #N Without this class, we have no way to describe a file as a relative path, relative to a base directory.
  class RelativePathWithHash
    # The relative file path (e.g. c:/dir/subdir/file.txt relative to c:/dir would be subdir/file.txt)
    #N Without this, we won't know what the relative path is
    attr_reader :relativePath
    
    # The hash code, e.g. a1c5b67fdb3cf0df8f1d29ae90561f9ad099bada44aeb6b2574ad9e15f2a84ed
    #N Without this, we won't have an economically sized indicator of the file's exact contents
    attr_reader :hash

    #N Without this, we won't be able to construct the object representing the file path and the hash of its contents in a single expression (also there is no other way to set the read-only attributes)
    def initialize(relativePath, hash)
      #N Without this, we won't rememeber the relative path value
      @relativePath = relativePath
      #N Without this, we won't remember the file's cryptographic hash of its contents
      @hash = hash
    end

    #N Without this, it's more work to output the description of this object
    def inspect
      #N Without this output, we won't know what class it belongs to or what the relative path and file content hash is
      return "RelativePathWithHash[#{relativePath}, #{hash}]"
    end
  end

  # A command to be executed on the remote system which calculates a hash value for
  # a file (of a given length), in the format: *hexadecimal-hash* *a-fixed-number-of-characters* *file-name*
  #N Without this base class, we won't have an organised consistent way to execute different hashing commands on the remote system and read the output of those commands
  class HashCommand
    # The command - a string or array of strings e.g. "sha256sum" or ["sha256", "-r"]
    #N Without command, we won't know what command (possibly with arguments) to execute on the remote system
    attr_reader :command 

    # The length of the calculated hash value e.g. 64 for sha256
    #N Without this, we won't know how many characters of hash value to read from the output line
    attr_reader :length
    
    # The number of characters between the hash value and the file name (usually 1 or 2)
    #N Without this, we won't know how many space characters to expect between the file name and the hash value in the output line
    attr_reader :spacerLen
    
    #N Without this we won't be able to construct the hash command object in a single expression (also there is no other way to set the read-only attributes)
    def initialize(command, length, spacerLen)
      #N Without this we won't remember the command to execute (on each file)
      @command = command
      #N Without this we won't remember how long a hash value to expect from the output line
      @length = length
      #N Without this we won't remember how many space characters to expect in the output line between the file name and the hash value
      @spacerLen = spacerLen
    end

    # Parse a hash line relative to a base directory, returning a RelativePathWithHash
    #N Without this method, we won't know how to parse the line of output from the hash command applied to the file
    def parseFileHashLine(baseDir, fileHashLine)
      #N Without this we won't get the hash line from the last <length> characters of the output line
      hash = fileHashLine[0...length]
      #N Without this we won't read the full file path from the output line preceding the spacer and the hash value
      fullPath = fileHashLine[(length + spacerLen)..-1]
      #N Without checking that the full path matches the base directory, we would fail to make this redundant check that the remote system has applied to the hash to the file we expected it to be applied to
      if fullPath.start_with?(baseDir)
        #N If we won't return this, we will fail to return the object representing the relative path & hash.
        return RelativePathWithHash.new(fullPath[baseDir.length..-1], hash)
      else
        #N If we don't raise this error (which hopefully won't ever happen anyway), there won't be any sensible value we can return from this method
        raise "File #{fullPath} from hash line is not in base dir #{baseDir}"
      end
    end
    
    #N Without this, the default string value of the hash command object will be less indicative of what it is
    def to_s
      #N Without this we won't see the command as a command and a list of arguments
      return command.join(" ")
    end
  end
  
  # Hash command for sha256sum, which generates a 64 hexadecimal digit hash, and outputs two characters between
  # the hash and the file name.
  #N Without this, we can't use the sha256sum command (which is available on some systems and which outputs a 2-space spacer)
  class Sha256SumCommand<HashCommand
    def initialize
      #N Without this, command name, hash length and spacer length won't be defined
      super(["sha256sum"], 64, 2)
    end
  end
  
  # Hash command for sha256, which generates a 64 hexadecimal digit hash, and outputs one character between
  # the hash and the file name, and which requires a "-r" argument to put the hash value first.  
  #N Without this, we can't use the sha256 command (which is available on some systems, which requires a '-r' argument if the file name is to appear _before_ the hash value, and which, in that case, has a 1-space spacer)
  class Sha256Command<HashCommand
    def initialize
      #N Without this, command name, hash length and spacer length won't be defined
      super(["sha256", "-r"], 64, 1)
    end
  end
  
  # Put "/" at the end of a directory name if it is not already there.
  #N Without this method, we will constantly be testing if directory paths have '/' at the end and adding it if it doesn't
  def normalisedDir(baseDir)
    return baseDir.end_with?("/") ? baseDir : baseDir + "/"
  end

  # Base class for an object representing a remote system where the contents of a directory
  # on the system are enumerated by one command to list all sub-directories and another command 
  # to list all files in the directory and their hash values.
  #N Without this base class, all its methods would have to be included in SshContentHost, and there wouldn't be even the possibility of defining an alternative implementation of LocalContentLocation which used 'find' on a local system to find sub-directories and files within a directory tree (but such an implementation is not included in this module)
  class DirContentHost
    
    # The HashCommand object used to calculate and parse hash values of files
    #N Without this we wouldn't know what hash command to execute on the (presumably remove) system, or, we wouldn't hash at all, and we would need to return the actual file contents, in which case we might as well just copy all file data every time we synced the data, which would be very inefficient.
    attr_reader :hashCommand
    
    # Prefix required for *find* command (usually nothing, since it should be on the system path)
    attr_reader :pathPrefix

    #N Without constructor we could not create object with read-only attribute values
    def initialize(hashCommand, pathPrefix = "")
      #N Without this, would not know the how to execute and parse the result of the hash command
      @hashCommand = hashCommand
      #N Without this, would not know how to execute 'find' if it's not on the path
      @pathPrefix = pathPrefix
    end
    
    # Generate the *find* command which will list all the sub-directories of the base directory
    #N Without this, wouldn't know how to execute 'find' command to list all sub-directories of specified directory
    def findDirectoriesCommand(baseDir)
      #N Without path prefix, wouldn't work if 'find' is not on path, without baseDir, wouldn't know which directory to start, without '-type d' would list more than just directories, without -print, would not print out the values found (or is that the default anyway?)
      return ["#{@pathPrefix}find", baseDir, "-type", "d", "-print"]
    end
    
    # Return the list of sub-directories relative to the base directory
    #N Without this method, would not be able to list the directories of a base directory, as part of getting the content tree (be it local or remote)
    def listDirectories(baseDir)
      #N if un-normalised, code assuming '/' at the end might be one-off
      baseDir = normalisedDir(baseDir)
      #N without the command, we don't know what command to execute to list the directories
      command = findDirectoriesCommand(baseDir)
      #N without this, the command won't execute, or we it might execute in a way that doesn't let us read the output
      output = getCommandOutput(command)
      #N without initial directories, we would have nowhere to accumulate the directory relative paths
      directories = []
      #N without the base dir length, we don't know how much to chop off the path names to get the relative path names
      baseDirLen = baseDir.length
      #N without this, would not get feedback that we are listing directories (which might be a slow remote command)
      puts "Listing directories ..."
      #N without looping over the output, we wouldn't be reading the output of the listing command
      while (line = output.gets)
        #N without chomping, eoln would be included in the directory paths
        line = line.chomp
        #N without this, would not get feedback about each directory listed
        puts " #{line}"
        #N without this check, unexpected invalid output not including the base directory would be processed as if nothing had gone wrong
        if line.start_with?(baseDir)
          #N without this, the directory in this line of output wouldn't be recorded
          directories << line[baseDirLen..-1]
        else
          #N if we don't raise the error, an expected result (probably a sign of some important error) would be ignored
          raise "Directory #{line} is not a sub-directory of base directory #{baseDir}"
        end
      end
      #N if we don't close the output, then un-opened output stream objects will accumulate (and leak resources)
      output.close()
      #N if we don't check the process status, then a failed command will be treated as if it had succeeded (i.e. as if there were no directories found)
      checkProcessStatus(command)
      return directories
    end
    
    # Generate the *find* command which will list all the files within the base directory
    #N without this method, we wouldn't know what command to use to list all the files in the base directory
    def findFilesCommand(baseDir)
      #N Without path prefix, wouldn't work if 'find' is not on path, without baseDir, wouldn't know which directory to start, without '-type f' would list more than just directories, without -print, would not print out the values found (or is that the default anyway?)
      return ["#{@pathPrefix}find", baseDir, "-type", "f", "-print"]
    end

    # List file hashes by executing the command to hash each file on the output of the
    # *find* command which lists all files, and parse the output.
    #N Without this, would not be able to list all the files in the base directory and the hashes of their contents (as part of getting the content tree)
    def listFileHashes(baseDir)
      #N Un-normalised, an off-by-one error would occur when 'subtracting' the base dir off the full paths to get relative paths
      baseDir = normalisedDir(baseDir)
      #N Without this, we would have nowhere to accumulate the file hash objects
      fileHashes = []
      #N Without this, we would not be executing and parsing the results of the file-listing command
      listFileHashLines(baseDir) do |fileHashLine|
        #N Without this, we would not be parsing the result line containing this file and its hash value
        fileHash = self.hashCommand.parseFileHashLine(baseDir, fileHashLine)
        #N Without this check we would be accumulating spurious nil values returned from listFileHashLines (even though listFileHashLines doesn't actually do that)
        if fileHash != nil
          #N Without this, we would fail to include this file & hash in the list of file hashes.
          fileHashes << fileHash
        end
      end
      return fileHashes
    end
    
    # Construct the ContentTree for the given base directory
    #N Without this, wouldn't know how to construct a content tree from a list of relative directory paths and relative file paths with associated hash values
    def getContentTree(baseDir)
      #N Without this, wouldn't have an empty content tree that we could start filling with dir & file data
      contentTree = ContentTree.new()
      #N Without this, wouldn't record the time of the content tree, and wouldn't be able to determine from a file's modification time that it had been changed since that content tree was recorded.
      contentTree.time = Time.now.utc
      #N Without this, the listed directories won't get included in the content tree
      for dir in listDirectories(baseDir)
        #N Without this, this directory won't get included in the content tree
        contentTree.addDir(dir)
      end
      #N Without this, the listed files and hashes won't get included in the content tree
      for fileHash in listFileHashes(baseDir)
        #N Without this, this file & hash won't get included in the content tree
        contentTree.addFile(fileHash.relativePath, fileHash.hash)
      end
      return contentTree
    end
  end
  
  # Execute a (local) command, or, if dryRun, just pretend to execute it.
  # Raise an exception if the process exit status is not 0.
  #N Without this method, wouldn't have an easy way to execute a command, echoing the command before it's executed, and optionally only doing a 'dry run', i.e. not running the command at all.
  def executeCommand(command, dryRun)
    #N Without this, the command won't be echoed
    puts "EXECUTE: #{command}"
    #N Without this check, the command will be executed even if it is meant to be a dry run
    if not dryRun
      #N Without this, the command won't actualy be execute even when it is meant to be run
      system(command)
      #N Without this check, a failed command will be treated as if it had executed successfully
      checkProcessStatus(command)
    end
  end
  
  # Base SSH/SCP implementation
  #N Without this base class, we wouldn't be able to share code between the internal (i.e. Ruby library) and external (i.e. separate executables) implementations of SSH & SCP.
  class BaseSshScp
    #N Without these, we wouldn't know the username, host name or standard format combination of the two
    attr_reader :userAtHost, :user, :host
    
    #N Without this method we wouldn't have a convenient way to set username & host from a single user@host value.
    def setUserAtHost(userAtHost)
      @userAtHost = userAtHost
      @user, @host = @userAtHost.split("@")
    end
    
    #N Without a base close method, implementations that don't need anything closed will fail when 'close' is called on them.
    def close
      # by default do nothing - close any cached connections
    end
    
    # delete remote directory (if dryRun is false) using "rm -r"
    #N Without this method, there won't be any way to delete a directory and it's contents on a remote system
    def deleteDirectory(dirPath, dryRun)
      #N Without this, the required ssh command to recursive remove a directory won't be (optionally) executed. Without the '-r', the attempt to delete the directory won't be successful.
      ssh("rm -r #{dirPath}", dryRun)
    end

    # delete remote file (if dryRun is false) using "rm"
    #N Without this method, there won't be any way to delete a file from the remote system
    def deleteFile(filePath, dryRun)
      #N Without this, the required ssh command to delete a file won't be (optionally) executed.
      ssh("rm #{filePath}", dryRun)
    end
  end
  
  # SSH/SCP using Ruby Net::SSH & Net::SCP
  #N Without this class, we could not run SSH and SCP commands (required for file synching) via the internal Ruby library, i.e. Net::SSH).
  class InternalSshScp<BaseSshScp
    
    #N Without an initialiser, we could not prepare a variable to hold a cached SSH connection
    def initialize
      @connection = nil
    end
    
    #N Without this method, we can't get a cached SSH connection (opening a new one if necessary)
    def connection
      #N Without this check, we would get a new connection even though we already have a new one
      if @connection == nil
        #N Without this, we don't get feedback about an SSH connection being opened
        puts "Opening SSH connection to #{user}@#{host} ..."
        #N Without this, we won't actually connect to the SSH host
        @connection = Net::SSH.start(host, user)
      end
      return @connection
    end
    
    #N Without this method, we can't get a connection for doing SCP commands (i.e. copying files or directories from local to remote system)
    def scpConnection
      return connection.scp
    end
    
    #N Without this we can't close the connection when we have finished with it (so it might "leak")
    def close()
      #N Without this check, we'll be trying to close the connection even if there isn't one, or it was already closed
      if @connection != nil
        #N Without this we won't get feedback about the SSH connection being closed
        puts "Closing SSH connection to #{user}@#{host} ..."
        #N Without this the connection won't actually get closed
        @connection.close()
        #N Without this we won't know the connection has been closed, because a nil @connection represents "no open connection"
        @connection = nil
      end
    end
    
    # execute command on remote host (if dryRun is false), yielding lines of output
    #N Without this method, we can't execute SSH commands on the remote host, echoing the command first, and optionally executing the command (or optionally not executing it and just doing a "dry run")
    def ssh(commandString, dryRun)
      #N Without this we won't have a description to display (although the value is only used in the next statement)
      description = "SSH #{user}@#{host}: executing #{commandString}"
      #N Without this the command description won't be echoed
      puts description
      #N Without this check, the command will execute even when it's only meant to be a dry run
      if not dryRun
        #N Without this, the command won't execute, and we won't have the output of the command
        outputText = connection.exec!(commandString)
        #N Without this check, there might be a nil exception, because the result of exec! can be nil(?)
        if outputText != nil then
          #N Without this, the output text won't be broken into lines
          for line in outputText.split("\n") do
            #N Without this, the code iterating over the output of ssh won't receive the lines of output
            yield line
          end
        end
      end
    end

    # copy a local directory to a remote directory (if dryRun is false)
    #N Without this method there won't be an easy way to copy a local directory to a remote directory (optionally doing only a dry run)
    def copyLocalToRemoteDirectory(sourcePath, destinationPath, dryRun)
      #N Without this there won't be a description of the copy operation that can be displayed to the user as feedback
      description = "SCP: copy directory #{sourcePath} to #{user}@#{host}:#{destinationPath}"
      #N Without this the user won't see the echoed description
      puts description
      #N Without this check, the files will be copied even if it is only meant to be a dry run.
      if not dryRun
        #N Without this, the files won't actually be copied.
        scpConnection.upload!(sourcePath, destinationPath, :recursive => true)
      end
    end
    
    # copy a local file to a remote directory (if dryRun is false)
    #N Without this method there won't be an easy way to copy a single local file to a remove directory (optionally doing only a dry run)
    def copyLocalFileToRemoteDirectory(sourcePath, destinationPath, dryRun)
      #N Without this there won't be a description of the copy operation that can be displayed to the user as feedback
      description = "SCP: copy file #{sourcePath} to #{user}@#{host}:#{destinationPath}"
      #N Without this the user won't see the echoed description
      puts description
      #N Without this check, the file will be copied even if it is only meant to be a dry run.
      if not dryRun
        #N Without this, the file won't actually be copied.
        scpConnection.upload!(sourcePath, destinationPath)
      end
    end

  end
  
  # SSH/SCP using external commands, such as "plink" and "pscp"
  #N Without this class, there would be no way to do SSH/SCP operations using external applications (and we would have to use Net::SSH, which is perfectly OK anyway)
  class ExternalSshScp<BaseSshScp
    # The SSH client, e.g. ["ssh"] or ["plink","-pw","mysecretpassword"] (i.e. command + args as an array)
    #N With this, we won't know how to execute the SSH client
    attr_reader :shell
    
    # The SCP client, e.g. ["scp"] or ["pscp","-pw","mysecretpassword"] (i.e. command + args as an array)
    #N Without this, we won't which executable (and necessary arguments) to run for SCP commands
    attr_reader :scpProgram

    # The SCP command as a string
    #N Without this, we won't be able to pass the SCP command as a single string argument to the method executeCommand
    attr_reader :scpCommandString

    #N Without initialize, we won't be able to construct an SSH/SCP object initialised with read-only attributes representing the SSH shell application and the SCP application.
    def initialize(shell, scpProgram)
      #N Without this we won't have the remote shell command as an array of executable + arguments
      @shell = shell.is_a?(String) ? [shell] : shell
      #N Without this we won't have the SCP command as an array of executable + arguments
      @scpProgram = scpProgram.is_a?(String) ? [scpProgram] : scpProgram
      #N Without this we won't have the SCP command as single string of white-space separated executable + arguments
      @scpCommandString = @scpProgram.join(" ")
    end
    
    # execute command on remote host (if dryRun is false), yielding lines of output
    #N Without this, won't be able to execute ssh commands using an external ssh application
    def ssh(commandString, dryRun)
      #N Without this, command being executed won't be echoed to output
      puts "SSH #{userAtHost} (#{shell.join(" ")}): executing #{commandString}"
      #N Without this check, the command will execute even it it's meant to be a dry run
      if not dryRun
        #N Without this, the command won't actually execute and return lines of output
        output = getCommandOutput(shell + [userAtHost, commandString])
        #N Without this loop, the lines of output won't be processed
        while (line = output.gets)
          #N Without this, the lines of output won't be passed to callers iterating over this method
          yield line.chomp
        end
        #N Without closing, the process handle will leak resources
        output.close()
        #N Without a check on status, a failed execution will be treated as a success (yielding however many lines were output before an error occurred)
        checkProcessStatus("SSH #{userAtHost} #{commandString}")
      end
    end
    
    # copy a local directory to a remote directory (if dryRun is false)
    #N Without this method, a local directory cannot be copied to a remote directory using an external SCP application
    def copyLocalToRemoteDirectory(sourcePath, destinationPath, dryRun)
      #N Without this, the external SCP application won't actually be run to copy the directory
      executeCommand("#{@scpCommandString} -r #{sourcePath} #{userAtHost}:#{destinationPath}", dryRun)
    end
    
    # copy a local file to a remote directory (if dryRun is false)
    #N Without this method, a local file cannot be copied to a remote directory using an external SCP application
    def copyLocalFileToRemoteDirectory(sourcePath, destinationPath, dryRun)
      #N Without this, the external SCP application won't actually be run to copy the file
      executeCommand("#{@scpCommandString} #{sourcePath} #{userAtHost}:#{destinationPath}", dryRun)
    end
    
  end
  
  # Representation of a remote system accessible via SSH
  #N Without this class, there won't be a way to represent details of a remote host that ssh&scp commands can be executed against by a chosen implementation of SSH&SCP
  class SshContentHost<DirContentHost
    
    # The remote SSH/SCP login, e.g. SSH via "username@host.example.com"
    #N Without this, we won't know how to execute SSH & SCP commands
    attr_reader :sshAndScp
    
    #N Without initialize, it won't be possible to construct an object representing a remote host and the means to execute SSH & SCP commands and return hash values of remote file contents (with read-only attributes)
    def initialize(userAtHost, hashCommand, sshAndScp = nil)
      #N Without calling super, the hash command won't be configured
      super(hashCommand)
      #N Without this, the SSH & SCP implementation won't be configured
      @sshAndScp = sshAndScp != nil ?  sshAndScp : InternalSshScp.new()
      #N Without this, the SSH & SCP implementation won't be configured with the user/host details to connect to.
      @sshAndScp.setUserAtHost(userAtHost)
    end
    
    #N Without this method, we cannot easily display the user@host details
    def userAtHost
      return @sshAndScp.userAtHost
    end
    
    #N Without this method, we cannot easily close any cached connections in the SSH & SCP implementation
    def closeConnections()
      #N Without this, the connections won't be closed
      @sshAndScp.close()
    end
    
    # Return readable description of base directory on remote system
    #N Without this, we have no easy way to display a description of a directory location on this remote host
    def locationDescriptor(baseDir)
      #N Without this, the directory being displayed might be missing the final '/'
      baseDir = normalisedDir(baseDir)
      return "#{userAtHost}:#{baseDir} (connect = #{shell}/#{scpProgram}, hashCommand = #{hashCommand})"
    end
    
    # execute an SSH command on the remote system, yielding lines of output
    # (or don't actually execute, if dryRun is false)
    #N Without this method, we won't have an easy way to execute a remote command on the host, echoing the command details first (so that we can see what command is to be executed), and possibly only doing a dry run and not actually executing the command
    def ssh(commandString, dryRun = false)
      #N Without this, the command won't actually be executed
      sshAndScp.ssh(commandString, dryRun) do |line|
        #N Without this, this line of output won't be available to the caller
        yield line
      end
    end
    
    # delete a remote directory, if dryRun is false
    #N Without this, we won't have an easy way to delete a directory on the remote system, echoing the command used to delete the directory, and optionally only doing a dry run
    def deleteDirectory(dirPath, dryRun)
      #N Without this, the deletion command won't be run at all
      sshAndScp.deleteDirectory(dirPath, dryRun)
    end
    
    # delete a remote file, if dryRun is false
    #N Without this, we won't have an easy way to delete a file on the remote system, echoing the command used to delete the file, and optionally only doing a dry run
    def deleteFile(filePath, dryRun)
      #N Without this, the deletion command won't be run at all
      sshAndScp.deleteFile(filePath, dryRun)
    end
    
    # copy a local directory to a remote directory, if dryRun is false
    #N Without this, we won't have an easy way to copy a local directory to a directory in the remote system, echoing the command used to copy the directory, and optionally only doing a dry run
    def copyLocalToRemoteDirectory(sourcePath, destinationPath, dryRun)
      #N Without this, the copy command won't be run at all
      sshAndScp.copyLocalToRemoteDirectory(sourcePath, destinationPath, dryRun)
    end
    
    # copy a local file to a remote directory, if dryRun is false
    #N Without this, we won't have an easy way to copy a local file to a directory in the remote system, echoing the command used to copy the file, and optionally only doing a dry run
    def copyLocalFileToRemoteDirectory(sourcePath, destinationPath, dryRun)
      #N Without this, the copy command won't be run at all
      sshAndScp.copyLocalFileToRemoteDirectory(sourcePath, destinationPath, dryRun)
    end
    
    # Return a list of all subdirectories of the base directory (as paths relative to the base directory)
    #N Without this we won't have a way to list the relative paths of all directories within a particular base directory on the remote system.
    def listDirectories(baseDir)
      #N Without this, the base directory might be missing the final '/', which might cause a one-off error when 'subtracting' the base directory name from the absolute paths to get relative paths
      baseDir = normalisedDir(baseDir)
      #N Without this, we won't know that directories are about to be listed
      puts "Listing directories ..."
      #N Without this, we won't have an empty array ready to accumulate directory relative paths
      directories = []
      #N Without this, we won't know the length of the base directory to remove from the beginning of the absolute directory paths
      baseDirLen = baseDir.length
      #N Without this, the directory-listing command won't be executed
      ssh(findDirectoriesCommand(baseDir).join(" ")) do |line|
        #N Without this, we won't get feedback about which directories were found
        puts " #{line}"
        #N Without this check, we might ignore an error that somehow resulted in directories being listed that aren't within the specified base directory
        if line.start_with?(baseDir)
          #N Without this, the relative path of this directory won't be added to the list
          directories << line[baseDirLen..-1]
        else
          #N Without raising this error, an unexpected directory not in the base directory would just be ignored
          raise "Directory #{line} is not a sub-directory of base directory #{baseDir}"
        end
      end
      return directories
    end
    
    # Yield lines of output from the command to display hash values and file names
    # of all files within the base directory
    #N Without this, where would be no way to list all files in a directory on the remote system and determine the hash of the contents of the file
    def listFileHashLines(baseDir)
      #N Without this, the base directory might be missing the final '/', which might cause a one-off error when 'subtracting' the base directory name from the absolute paths to get relative paths
      baseDir = normalisedDir(baseDir)
      #N Without this, we wouldn't know what command to run remotely to loop over the output of the file-files command and run the hash command on each line of output
      remoteFileHashLinesCommand = findFilesCommand(baseDir) + ["|", "xargs", "-r"] + @hashCommand.command
      #N Without this we wouldn't actually run the command just defined
      ssh(remoteFileHashLinesCommand.join(" ")) do |line| 
        #N Without this the line of output wouldn't be echoed to the user
        puts " #{line}"
        #N Without this the line of output (with a file name and a hash value) wouldn't be available to the caller of this method
        yield line 
      end
    end
    
    # List all files within the base directory to stdout
    #N Without this, we wouldn't have a way to list what files are currently in the target directory on the remote host (i.e. if we wanted to see what files where currently there)
    def listFiles(baseDir)
      #N Without this, the base directory might be missing the final '/', which might cause a one-off error when 'subtracting' the base directory name from the absolute paths to get relative paths
      baseDir = normalisedDir(baseDir)
      #N Without this we wouldn't be executing the command to list all files in the remote directory
      ssh(findFilesCommand(baseDir).join(" ")) do |line| 
        #N Without this we wouldn't be echoing the file name on this line for the user to read
        puts " #{line}"
      end
    end
    
  end
  
  # An object representing the content of a file within a ContentTree.
  # The file may be marked for copying (if it's in a source ContentTree) 
  # or for deletion (if it's in a destination ContentTree)
  #N Without this we would have no way to represent a named file within directory tree (so named with its relative path), and its contents
  class FileContent
    # The name of the file
    #N Without this, we won't know what the name of the file is
    attr_reader :name
    
    # The hash value of the file's contents
    #N Without this, we wouldn't know whether the file's contents are the same or not as the contents of some other file
    attr_reader :hash
    
    # The components of the relative path where the file is found
    #N Without this we wouldn't have that path broken into components corresponding to steps on the tree from its "root" to the branch corresponding to this file.
    attr_reader :parentPathElements
    
    # The destination to which the file should be copied
    #N Without this we won't know where this file is to be individually copied to (for files that cannot be copied as part of a larger group)
    attr_reader :copyDestination
    
    # Should this file be deleted
    #N Without this we won't know whether this file is to be deleted (or not)
    attr_reader :toBeDeleted
    
    #N Without this we can't construct an object representing our initial knowledge of a file that exists (and which we might later decide to mark for copying or for deletion)
    def initialize(name, hash, parentPathElements)
      #N Without this we won't remember the name of the file
      @name = name
      #N Without this we won't know the hash of the contents of the file
      @hash = hash
      #N Without this we won't know the path elements of the sub-directory (within the directory tree) containing the file
      @parentPathElements = parentPathElements
      #N Without this the file object won't be in a default state of _not_ to be copied
      @copyDestination = nil
      #N Without this the file object won't be in a default state of _not_ to be deleted
      @toBeDeleted = false
    end
    
    # Mark this file to be copied to a destination directory (from a destination content tree)
    #N Without this we can't decide to copy a local file to a remote directory
    def markToCopy(destinationDirectory)
      #N Without this we won't remember that the file is to be copied to the destination directory
      @copyDestination = destinationDirectory
    end
    
    # Mark this file to be deleted
    #N Without this we can't decide to delete a remote file
    def markToDelete
      #N Without this we won't remember that this file is to be deleted
      @toBeDeleted = true
    end
    
    #N Without this we can't easily and compactly display the file name and hash value
    def to_s
      return "#{name} (#{hash})"
    end
    
    # The relative name of this file in the content tree (relative to the base dir)
    #N Without this we can't easily reconstruct the relative path as a single string
    def relativePath
      return (parentPathElements + [name]).join("/")
    end
  end
  
  # A "content tree" consisting of a description of the contents of files and
  # sub-directories within a base directory. The file contents are described via
  # cryptographic hash values.
  # Each sub-directory within a content tree is also represented as a ContentTree.
  #N Without this we can't represent information about the contents of a set of files within sub-directories within a base directory on a local or remote system in a manner that let's us easily determine how a directory tree on a local system is different from the directory tree on a remote system (so we can efficiently sync from local to remote)
  class ContentTree
    # name of the sub-directory within the containing directory (or nil if this is the base directory)
    #N Without this we don't know the local name of the sub-directory (other then the base directory, for which we don't know or care about its local name, or it might not even have one, if its the actual root directory of the mounted file system)
    attr_reader :name
    
    # path elements from base directory leading to this one
    #N Without this we wouldn't have the path broken into components corresponding to steps on the tree from its "root" to the branch corresponding to this file.
    attr_reader :pathElements
    
    # files within this sub-directory (as FileContent's)
    #N Without this we won't know what files are directly contained in this sub-directory
    attr_reader :files
    
    # immediate sub-directories of this directory
    #N Without this we won't know what directories are immediately contained in this sub-directory
    attr_reader :dirs
    
    # the files within this sub-directory, indexed by file name
    #N Without this we won't be able to directly and quickly retrieve a file by it's name (e.g. we already know the name of a file in another directory, and we want to find the same file it it exists in this directory)
    attr_reader :fileByName
    
    # immediate sub-directories of this directory, indexed by name  
    #N Without this we won't be able to directly and quickly retrieve a sub-directory by it's name (e.g. we already know the name of a sub-directory in another directory, and we want to find the same sub-directory it it exists in this directory)
    attr_reader :dirByName
    
    # where this directory should be copied to
    #N Without this we won't be able to know that this directory (and all its contents) is marked for copying to another directory on a remote system.
    attr_reader :copyDestination
    
    # whether this directory should be deleted
    #N Without this we won't be able to know that the directory and all its contents are to be deleted.
    attr_reader :toBeDeleted
    
    # the UTC time (on the local system, even if this content tree represents a remote directory)
    # that this content tree was constructed. Only set for the base directory.
    #N Without this we won't be able to timestamp what time information about the base directory was read (so we can know if files within the content tree have changed because we see that their modification times are later than this timestamp)
    attr_accessor :time
    
    #N Without this we won't be able to initialise information about this directory based on knowing it's name and it's relative path, ready to have information about files and sub-directories added to it, and ready to be marked for deletion or copying as required.
    def initialize(name = nil, parentPathElements = nil)
      #N Without this we won't remember the name of the directory
      @name = name
      #N Without this we won't know the path elements of the sub-directory (within the directory tree) containing this directory
      @pathElements = name == nil ? [] : parentPathElements + [name]
      #N Without this we won't be ready to add files to the list of files in this directory
      @files = []
      #N Without this we won't be ready to add directories to the list of sub-directories immediately contained in this directory
      @dirs = []
      #N Without this we won't be ready to add files so we can look them up by name
      @fileByName = {}
      #N Without this we won't be ready to add immediate sub-directories so we can look them up by name
      @dirByName = {}
      #N Without this the directory object won't be in a default state of _not_ to be copied
      @copyDestination = nil
      #N Without this the directory object won't be in a default state of _not_ to be deleted
      @toBeDeleted = false
      #N Without this the directory object won't be in a default state of not yet having set the timestamp
      @time = nil
    end
    
    # mark this directory to be copied to a destination directory
    #N Without this we can't mark a directory to be copied to a directory on a remote system
    def markToCopy(destinationDirectory)
      #N Without this it won't be marked for copying
      @copyDestination = destinationDirectory
    end
    
    # mark this directory (on a remote system) to be deleted
    #N Without this we can't mark a directory (on a remote system) to be deleted
    def markToDelete
      #N Without this it won't be marked for deletion
      @toBeDeleted = true
    end
    
    # the path of the directory that this content tree represents, relative to the base directory
    #N Without this we can't know the relative path of the sub-directory within the content tree
    def relativePath
      #N Without this the path elements won't be joined together with "/" to get the relative path as a single string
      return @pathElements.join("/")
    end
    
    # convert a path string to an array of path elements (or return it as is if it's already an array)
    #N Without this we can't start from a path and decompose it into elements (optionally allowing for the case where the conversion has already been done)
    def getPathElements(path)
      #N Without this path as a single string won't be decomposed into a list of elements
      return path.is_a?(String) ? (path == "" ? [] : path.split("/")) : path
    end
    
    # get the content tree for a sub-directory (creating it if it doesn't yet exist)
    #N Without this we can't create the content tree for an immediate sub-directory of the directory represented by this content tree (which means we can't recursively create the full content tree for this directory)
    def getContentTreeForSubDir(subDir)
      #N Without this we won't know if the relevant sub-directory content tree hasn't already been created
      dirContentTree = dirByName.fetch(subDir, nil)
      #N Without this check, we'll be recreated the sub-directory content tree, even if we know it has already been created
      if dirContentTree == nil
        #N Without this the new sub-directory content tree won't be created
        dirContentTree = ContentTree.new(subDir, @pathElements)
        #N Without this the new sub-directory won't be added to the list of sub-directories of this directory
        dirs << dirContentTree
        #N Without this we won't be able to find the sub-directory content tree by name
        dirByName[subDir] = dirContentTree
      end
      return dirContentTree
    end
    
    # add a sub-directory to this content tree
    # Without this we won't be able to add a sub-directory (given as a path with possibly more than one element) into the content tree
    def addDir(dirPath)
      #N Without this, the directory path won't be broken up into its elements
      pathElements = getPathElements(dirPath)
      #N Without this check, it will fail in the case where dirPath has no elements in it
      if pathElements.length > 0
        #N Without this, we won't know the first element in the path (which is needed to construct the immediate sub-directory content-tree representing the first part of the path)
        pathStart = pathElements[0]
        #N Without this we won't know the rest of the elements so that we can add that part of the dir path into the content tree we've just created
        restOfPath = pathElements[1..-1]
        #N Without this the immedate sub-directory content tree and the chain of sub-directories within that won't be created
        getContentTreeForSubDir(pathStart).addDir(restOfPath)
      end
    end
    
    # recursively sort the files and sub-directories of this content tree alphabetically
    #N Without this, we will have to put up with sub-directories and file-directories being listed in whatever order the listing commands happen to list them in, which may not be consisted across different copies of effectively the same content tree on different systems.
    def sort!
      #N Without this, the immediate sub-directories won't get sorted
      dirs.sort_by! {|dir| dir.name}
      #N Without this, files contained immediately in this directory won't get sorted
      files.sort_by! {|file| file.name}
      #N Without this, files and directories contained within sub-directories of this directory won't get sorted
      for dir in dirs
        #N Without this, this sub-directory won't have its contents sorted
        dir.sort!
      end
    end
    
    # given a relative path, add a file and hash value to this content tree
    #N Without this, we can't add a file description (given as a relative path and a hash value) into the content tree for this directory
    def addFile(filePath, hash)
      #N Without this the path won't be broken up into elements so that we can start by processing the first element
      pathElements = getPathElements(filePath)
      #N Without this check, we would attempt to process an invalid path consisting of an empty string or no path elements (since the path should always contain at least one element consisting of the file name)
      if pathElements.length == 0
        #N Without this, the case of zero path elements will not be treated as an error
        raise "Invalid file path: #{filePath.inspect}"
      end
      #N Without this check, the cases of having the immediate file name (to be added as a file in this directory) and having a file within a sub-directory will not be distinguished
      if pathElements.length == 1
        #N Without this, the single path element will not be treated as being the immediate file name
        fileName = pathElements[0]
        #N Without this, we won't have our object representing the file name and a hash of its contents
        fileContent = FileContent.new(fileName, hash, @pathElements)
        #N Without this, the file&content object won't be added to the list of files contained in this directory
        files << fileContent
        #N Without this, we won't be able to look up the file&content object by name.
        fileByName[fileName] = fileContent
      else
        #N Without this, we won't have the first part of the file path required to identify the immediate sub-directory that it is found in.
        pathStart = pathElements[0]
        #N Without this, we won't have the rest of the path which needs to be passed to the content tree in the immediate sub-directory
        restOfPath = pathElements[1..-1]
        #N Without this, the file & hash won't be added into the sub-directory's content tree
        getContentTreeForSubDir(pathStart).addFile(restOfPath, hash)
      end
    end
    
    # date-time format for reading and writing times, e.g. "2007-12-23 13:03:99.012 +0000"
    #N Without this, we won't have a simple easy to read&write date time format for writing times in and out of content tree files.
    @@dateTimeFormat = "%Y-%m-%d %H:%M:%S.%L %z"
    
    # pretty-print this content tree
    #N Without this, we won't have a way to output a nice easy-to-read description of this content tree object
    def showIndented(name = "", indent = "  ", currentIndent = "")
      #N Without this check, would attempt to output time for directories other than the root directory for which time has not been recorded
      if time != nil
        #N Without this, any recorded time value wouldn't be output
        puts "#{currentIndent}[TIME: #{time.strftime(@@dateTimeFormat)}]"
      end
      #N Without this check, an empty line would be output for root level (which has no name within the content tree)
      if name != ""
        #N Without this,non-root sub-directories would not be displayed
        puts "#{currentIndent}#{name}"
      end
      #N Without this check, directories not to be copied would be shown as to be copied
      if copyDestination != nil
        #N Without this, directories marked to be copied would not be displayed as such
        puts "#{currentIndent} [COPY to #{copyDestination.relativePath}]"
      end
      #N Without this check, directories not be to deleted would be shown as to be deleted
      if toBeDeleted
        #N Without this, directories marked to be deleted would not be displayed as such
        puts "#{currentIndent} [DELETE]"
      end
      #N Without this, output for sub-directories and files would not be indented further than their parent
      nextIndent = currentIndent + indent
      #N Without this, sub-directories of this directory won't be included in the output
      for dir in dirs
        #N Without this, this sub-directory won't be included in the output (suitable indented relative to the parent)
        dir.showIndented("#{dir.name}/", indent = indent, currentIndent = nextIndent)
      end
      #N Without this, files contained immediately in this directory won't be included in the output
      for file in files
        #N Without this, this file and the hash of its contents won't be shown in the output
        puts "#{nextIndent}#{file.name}  - #{file.hash}"
        #N Without this check, files not to be copied would be shown as to be copied
        if file.copyDestination != nil
          #N Without this, files marked to be copied would not be displayed as such
          puts "#{nextIndent} [COPY to #{file.copyDestination.relativePath}]"
        end
        #N Without this check, files not to be deleted would be shown as to be deleted
        if file.toBeDeleted
          #N Without this, files marked to be deleted would not be displayed as such
          puts "#{nextIndent} [DELETE]"
        end
      end
    end

    # write this content tree to an open file, indented
    #N Without this, the details for the content tree could not be output to a file in a format that could be read in again (by readFromFile)
    def writeLinesToFile(outFile, prefix = "")
      #N Without this check, it would attempt to write out a time value when none was available
      if time != nil
        #N Without this, a line for the time value would not be written to the file
        outFile.puts("T #{time.strftime(@@dateTimeFormat)}\n")
      end
      #N Without this, directory information would not be written to the file (for immediate sub-directories)
      for dir in dirs
        #N Without this, a line for this sub-directory would not be written to the file
        outFile.puts("D #{prefix}#{dir.name}\n")
        #N Without this, lines for the sub-directories and files contained with this directory would not be written to the file
        dir.writeLinesToFile(outFile, "#{prefix}#{dir.name}/")
      end
      #N Without this, information for files directly contained within this directory would not be written to the file
      for file in files
      #N Without this, the line for this file would not be written to the file
        outFile.puts("F #{file.hash} #{prefix}#{file.name}\n")
      end
    end
    
    # write this content tree to a file (in a format which readFromFile can read back in)
    #N Without this, information for a content tree could not be output to a named file  in a format that could be read in again (by readFromFile)
    def writeToFile(fileName)
      #N Without this, the user would not have feedback that the content tree is being written to the named file
      puts "Writing content tree to file #{fileName} ..."
      #N Without this, the named file cannot be written to
      File.open(fileName, "w") do |outFile|
        #N Without this, the lines of information for the content tree will not be written to the open file
        writeLinesToFile(outFile)
      end
    end
    
    # regular expression for directory entries in content tree file
    #N Without this, we have no way to parse the "D" directory lines output by writeLinesToFile
    @@dirLineRegex = /^D (.*)$/
    
    # regular expression for file entries in content tree file
    #N Without this, we have no way to parse the "F" file lines output by writeLinesToFile
    @@fileLineRegex = /^F ([^ ]*) (.*)$/
    
    # regular expression for time entry in content tree file
    #N Without this, we have no way to parse the "T" time lines output by writeLinesToFile
    @@timeRegex = /^T (.*)$/
    
    # read a content tree from a file (in format written by writeToFile)
    #N Without this method, we don't know how to read in a content tree from a file written out by writeToFile
    def self.readFromFile(fileName)
      #N Without this, we don't have an empty ContentTree ready to be populated with information read in from the file
      contentTree = ContentTree.new()
      #N Without this, the user does not receive feedback that the content tree is being read in from the named file
      puts "Reading content tree from #{fileName} ..."
      #N Without this, we can't read through the lines in the content tree file
      IO.foreach(fileName) do |line|
        #N Without this, we can't parse a line that might be a "D" directory line
        dirLineMatch = @@dirLineRegex.match(line)
        #N Without this check, we would attempt to parse a non-directory line as if it was a directory line
        if dirLineMatch
          #N Without this, we would not extract the actual directory name from the D line
          dirName = dirLineMatch[1]
          #N Without this, the extracted directory name would not be recorded into the content tree
          contentTree.addDir(dirName)
        else
        #N Without this, we can't parse a line that might be an "F" file line
          fileLineMatch = @@fileLineRegex.match(line)
          #N Without this check, we would attempt to parse a non-file line as if it was a file line
          if fileLineMatch
            #N Without this, we would not extract the actual hash value from the F line
            hash = fileLineMatch[1]
            #N Without this, we would not extract the actual file name from the F line
            fileName = fileLineMatch[2]
            #N Without this, the extracted file name and hash value would not be recorded into the content tree
            contentTree.addFile(fileName, hash)
          else
            #N Without this, we can't parse a line that might be an "T" file line
            timeLineMatch = @@timeRegex.match(line)
            #N Without this check, we would attempt to parse a non-time line as if it was a time line
            if timeLineMatch
              #N Without this, we would not extract the actual time value from the T line
              timeString = timeLineMatch[1]
              #N Without this, the extracted time value would not be recorded into the content tree
              contentTree.time = Time.strptime(timeString, @@dateTimeFormat)
            else
              #N Without this, we would silently ignore an invalid line read in from the content file (which might indicate a bug in the coded which wrote the file, or that we are trying to read the wrong file)
              raise "Invalid line in content tree file: #{line.inspect}"
            end
          end
        end
      end
      return contentTree
    end

    # read a content tree as a map of hashes, i.e. from relative file path to hash value for the file
    # Actually returns an array of the time entry (if any) and the map of hashes
    #N Without this we wouldn't have an easy way to construct a mapping from file name to hash of contents (and also a time value, so we can determine that the hash value might be incorrect for any file with a modification time later than that time) that didn't involve reading in a whole content tree, and then processing that to construct the mapping
    def self.readMapOfHashesFromFile(fileName)
      #N Without this, we wouldn't have an empty map to populate with value to be read from the file
      mapOfHashes = {}
      #N Without this, we wouldn't have an empty time value to populate from the file
      time = nil
      #N Without this, we couldn't read lines from the named file
      File.open(fileName).each_line do |line|
        #N Without this, we can't parse a line that might be an "F" file line
        fileLineMatch = @@fileLineRegex.match(line)
          #N Without this check, we would attempt to parse a non-file line as if it was a file line
          if fileLineMatch
            #N Without this, we would not extract the actual hash value from the F line
            hash = fileLineMatch[1]
            #N Without this, we would not extract the actual file name from the F line
            fileName = fileLineMatch[2]
            #N Without this, the extracted file name and hash value would not be recorded into the map
            mapOfHashes[fileName] = hash
          end
        #N Without this, we can't parse a line that might be an "T" file line
        timeLineMatch = @@timeRegex.match(line)
        #N Without this check, we would attempt to parse a non-time line as if it was a time line
        if timeLineMatch
          #N Without this, we would not extract the actual time value from the T line
          timeString = timeLineMatch[1]
          #N Without this, the extracted time value would not be recorded
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
    #N Without this we wouln't have an easy way to get an immediate sub-directory by name, but returning nil for one that doesn't exist (in the case where the name is from a different directory, and that directory doesn't exist in this one)
    def getDir(dir)
      return dirByName.fetch(dir, nil)
    end
    
    # Get the named file & hash value, if it exists
    #N Without this we wouln't have an easy way to get an immediate file & hash by name, but returning nil for one that doesn't exist (in the case where the name is from a different directory, and that file doesn't exist in this one)
    def getFile(file)
      return fileByName.fetch(file, nil)
    end
    
    # Mark copy operations, given that the corresponding destination directory already exists.
    # For files and directories that don't exist in the destination, mark them to be copied.
    # For sub-directories that do exist, recursively mark the corresponding sub-directory copy operations.
    #N Without this we won't know how to mark which sub-directories and files in this (source) directory need to by marked for copying into the other directory, because they don't exist in the other (destination) directory
    def markCopyOperations(destinationDir)
      #N Without this we can't loop over the immediate sub-directories to determine how each one needs to be marked for copying
      for dir in dirs
        #N Without this we won't have the corresponding sub-directory in the other directory with the same name as this sub-directory (if it exists)
        destinationSubDir = destinationDir.getDir(dir.name)
        #N Without this check, we won't be able to correctly process a sub-directory based on whether or not one with the same name exists in the other directory
        if destinationSubDir != nil
          #N Without this, files and directories missing or changed from the other sub-directory (which does exist) won't get copied
          dir.markCopyOperations(destinationSubDir)
        else
          #N Without this, the corresponding missing sub-directory in the other directory won't get updated from this sub-directory
          dir.markToCopy(destinationDir)
        end
      end
      #N Without this we can't loop over the files to determine how each one needs to be marked for copying
      for file in files
        #N Without this we won't have the corresponding file in the other directory with the same name as this file (if it exists)
        destinationFile = destinationDir.getFile(file.name)
        #N Without this check, this file will get copied, even if it doesn't need to be (it only needs to be if it is missing, or the hash is different)
        if destinationFile == nil or destinationFile.hash != file.hash
          #N Without this, a file that is missing or changed won't get copied (even though it needs to be)
          file.markToCopy(destinationDir)
        end
      end
    end
    
    # Mark delete operations, given that the corresponding source directory exists.
    # For files and directories that don't exist in the source, mark them to be deleted.
    # For sub-directories that do exist, recursively mark the corresponding sub-directory delete operations.
    #N Without this we won't know how to mark which sub-directories and files in this (destination) directory need to by marked for deleting (because they don't exist in the other source directory)
    def markDeleteOptions(sourceDir)
      #N Without this we can't loop over the immediate sub-directories to determine how each one needs to be marked for deleting
      for dir in dirs
        #N Without this we won't have the corresponding sub-directory in the other directory with the same name as this sub-directory (if it exists)
        sourceSubDir = sourceDir.getDir(dir.name)
        #N Without this check, we won't be able to correctly process a sub-directory based on whether or not one with the same name exists in the other directory
        if sourceSubDir == nil
          #N Without this, this directory won't be deleted, even though it doesn't exist at all in the corresponding source directory
          dir.markToDelete()
        else
          #N Without this, files and directories missing from the other source sub-directory (which does exist) won't get deleted
          dir.markDeleteOptions(sourceSubDir)
        end
      end
      #N Without this we can't loop over the files to determine which ones need to be marked for deleting
      for file in files
        #N Without this we won't known if the corresponding file in the source directory with the same name as this file exists
        sourceFile = sourceDir.getFile(file.name)
        #N Without this check, we will incorrectly delete this file whether or not it exists in the source directory
        if sourceFile == nil
          #N Without this, this file which doesn't exist in the source directory won't get deleted from this directory
          file.markToDelete()
        end
      end
    end
  end
  
  # Base class for a content location which consists of a base directory
  # on a local or remote system.
  #N Without this class, there would be no place to put code common to the representation of the local file system and the representation of the remote file system
  class ContentLocation
    
    # The name of a file used to hold a cached content tree for this location (can optionally be specified)
    #N Without the cached content file, it would be necessary to list all files and calculate hashes of all files (for both the local and remote file system) every time a sync operation is performed.
    attr_reader :cachedContentFile
    
    #N Without this constructor, there is no way to construct a content location object with read-only cached content file attribute
    def initialize(cachedContentFile)
      #N Without this the name of the cached content file won't be remembered
      @cachedContentFile = cachedContentFile
    end
    
    # Get the cached content file name, if specified, and if the file exists
    #N Without this there is no easy way to get the existing cached content tree (if the cached content file is specified, and if the file exists)
    def getExistingCachedContentTreeFile
      #N Without this check, it would try to find the cached content file when none was specified
      if cachedContentFile == nil
        #N Without this, there will be no feedback to the user that no cached content file is specified
        puts "No cached content file specified for location"
        return nil
      #N Without this check, it will try to open the cached content file when it doesn't exist (i.e. because it hasn't been created, or, it has been deleted)
      elsif File.exists?(cachedContentFile)
        #N Without this, it won't return the cached content file when it does exist
        return cachedContentFile
      else
        #N Without this, there won't be feedback to the user that the specified cached content file doesn't exist.
        puts "Cached content file #{cachedContentFile} does not yet exist."
        return nil
      end
    end
    
    # Delete any existing cached content file
    #N Without this, there won't be an easy way to delete the cached content file (if it is specified and it exists)
    def clearCachedContentFile
      #N Without this check, it will try to delete a cached content file even when it doesn't exist
      if cachedContentFile and File.exists?(cachedContentFile)
        #N Without this, there will be no feedback to the user that the specified cached content file is being deleted
        puts " deleting cached content file #{cachedContentFile} ..."
        #N Without this, the specified cached content file won't be deleted
        File.delete(cachedContentFile)
      end
    end
    
    # Get the cached content tree (if any), read from the specified cached content file.
    #N Without this method, there won't be an easy way to get the cached content from the cached content file (if the file is specified, and if it exists)
    def getCachedContentTree
      #N Without this, we won't know the name of the specified cached content file (if it is specified)
      file = getExistingCachedContentTreeFile
      #N Without this check, we would attempt to read a non-existent file
      if file
        #N Without this, a content tree that has been cached won't be returned.
        return ContentTree.readFromFile(file)
      else
        return nil
      end
    end
    
    # Read a map of file hashes (mapping from relative file name to hash value) from the
    # specified cached content file
    #N Without this, there won't be an easy way to get a map of file hashes (keyed by relative file name), for the purpose of getting the hashes of existing files which are known not to have changed (by comparing modification time to timestamp, which is also returned)
    def getCachedContentTreeMapOfHashes
      #N Without this, we won't know the name of the specified cached content file (if it is specified)
      file = getExistingCachedContentTreeFile
      #N Without this check, we would attempt to read a non-existent file
      if file
        #N Without this, there won't be feedback to the user that we are reading the cached file hashes
        puts "Reading cached file hashes from #{file} ..."
        #N Without this, a map of cached file hashes won't be returned
        return ContentTree.readMapOfHashesFromFile(file)
      else
        #N Without this, the method wouldn't consistently return an array of timestamp + map of hashes in the case where there is no cached content file
        return [nil, {}]
      end
    end
    
  end
  
  # A directory of files on a local system. The corresponding content tree
  # can be calculated directly using Ruby library functions.
  #N Without this class, there would be no representation for a "local" content location, i.e. a directory on the user's local system
  class LocalContentLocation<ContentLocation
    
    # the base directory, for example of type Based::BaseDirectory. Methods invoked are: allFiles, subDirs and fullPath.
    # For file and dir objects returned by allFiles & subDirs, methods invoked are: relativePath and fullPath
    #N Without this, we won't know where on the local system the directory is
    attr_reader :baseDirectory
    # the ruby class that generates the hash, e.g. Digest::SHA256
    #N Without this, we won't know which hash function to apply to files
    attr_reader :hashClass
    
    #N Without this, we won't be able to construct an object representing a local content location, with read-only attributes specifying the directory, the hash function, and, optionally, the name of the cached content file.
    def initialize(baseDirectory, hashClass, cachedContentFile = nil)
      #N Without this, we won't remember the cached content file name
      super(cachedContentFile)
      #N Without this, we won't remember the base directory
      @baseDirectory = baseDirectory
      #N Without this, we won't remember the hash function
      @hashClass = hashClass
    end
    
    # get the full path of a relative path (i.e. of a file/directory within the base directory)
    #N Without this, we won't have an easy way to calculate the full path of a file or directory in the content tree that is specified by its relative path.
    def getFullPath(relativePath)
      return @baseDirectory.fullPath + relativePath
    end
    
    # get the content tree for this base directory by iterating over all
    # sub-directories and files within the base directory (and excluding the excluded files)
    # and calculating file hashes using the specified Ruby hash class
    # If there is an existing cached content file, use that to get the hash values
    # of files whose modification time is earlier than the time value for the cached content tree.
    # Also, if a cached content file is specified, write the final content tree back out to the cached content file.
    #N Without this we won't have way to get the content tree object describing the contents of the local directory
    def getContentTree
      #N Without this we won't have timestamp and the map of file hashes used to efficiently determine the hash of a file which hasn't been modified after the timestamp
      cachedTimeAndMapOfHashes = getCachedContentTreeMapOfHashes
      #N Without this we won't have the timestamp to compare against file modification times
      cachedTime = cachedTimeAndMapOfHashes[0]
      #N Without this we won't have the map of file hashes
      cachedMapOfHashes = cachedTimeAndMapOfHashes[1]
      #N Without this we won't have an empty content tree which can be populated with data describing the files and directories within the base directory
      contentTree = ContentTree.new()
      #N Without this we won't have a record of a time which precedes the recording of directories, files and hashes (which can be used when this content tree is used as a cached for data when constructing some future content tree)
      contentTree.time = Time.now.utc
      #N Without this, we won't record information about all sub-directories within this content tree
      for subDir in @baseDirectory.subDirs
        #N Without this, this sub-directory won't be recorded in the content tree
        contentTree.addDir(subDir.relativePath)
      end
      #N Without this, we won't record information about the names and contents of all files within this content tree
      for file in @baseDirectory.allFiles
        #N Without this, we won't know the digest of this file (if we happen to have it) from the cached content tree
        cachedDigest = cachedMapOfHashes[file.relativePath]
        #N Without this check, we would assume that the cached digest applies to the current file, even if one wasn't available, or if the file has been modified since the time when the cached value was determined.
        # (Extra note: just checking the file's mtime is not a perfect check, because a file can "change" when actually it or one of it's enclosing sub-directories has been renamed, which might not reset the mtime value for the file itself.)
        if cachedTime and cachedDigest and File.stat(file.fullPath).mtime < cachedTime
          #N Without this, the digest won't be recorded from the cached digest in those cases where we know the file hasn't changed
          digest = cachedDigest
        else
          #N Without this, a new digest won't be determined from the calculated hash of the file's actual contents
          digest = hashClass.file(file.fullPath).hexdigest
        end
        #N Without this, information about this file won't be added to the content tree
        contentTree.addFile(file.relativePath, digest)
      end
      #N Without this, the files and directories in the content tree might be listed in some indeterminate order
      contentTree.sort!
      #N Without this check, a new version of the cached content file will attempt to be written, even when no name has been specified for the cached content file
      if cachedContentFile != nil
        #N Without this, a new version of the cached content file (ready to be used next time) won't be created
        contentTree.writeToFile(cachedContentFile)
      end
      return contentTree
    end
  end
  
  # A directory of files on a remote system
  #N Without this class, there would be no representation for a "remote" content location, i.e. a directory on the remote system
  class RemoteContentLocation<ContentLocation
    # the remote SshContentHost
    #N Without this we won't know which user login on which remote server to connect to.
    attr_reader :contentHost
    
    # the base directory on the remote system
    #N Without this we won't know which directory on the remote system to sync files to
    attr_reader :baseDir
    
    #N Without this we wouldn't be able to create the remote content location object with read-only attributes
    def initialize(contentHost, baseDir, cachedContentFile = nil)
      # Without super, we won't remember the cached content file (if specified)
      super(cachedContentFile)
      # Without this we won't remember which remote server to connect to
      @contentHost = contentHost
      # Without this we won't remember which directoy on the remote server to sync to.
      @baseDir = normalisedDir(baseDir)
    end
    
    #N Without this we won't have any way to close cached open connections (and they will leak)
    def closeConnections
      #N Without this the cached connections won't get closed
      @contentHost.closeConnections()
    end
    
    # list files within the base directory on the remote contentHost
    #N Without this we won't have an easy way to list all files in the remote directory on the remote system
    def listFiles()
      #N Without this the files won't get listed
      contentHost.listFiles(baseDir)
    end
    
    # object required to execute SCP (e.g. "scp" or "pscp", possibly with extra args)
    #N Without this we won't have a handle on the object used to perform SSH/SCP actions
    def sshAndScp
      return contentHost.sshAndScp
    end
    
    # get the full path of a relative path
    #N Without this we won't have an easy way to get the full path of a file or directory specified relative the remote directory
    def getFullPath(relativePath)
      return baseDir + relativePath
    end
    
    # execute an SSH command on the remote host (or just pretend, if dryRun is true)
    #N Without this we won't have a direct method to execute SSH commands on the remote server (with dry-run option)
    def ssh(commandString, dryRun = false)
      contentHost.sshAndScp.ssh(commandString, dryRun)
    end
    
    # list all sub-directories of the base directory on the remote host
    #N Without this we won't have a direct method to list all sub-directories within the remote directory
    def listDirectories
      return contentHost.listDirectories(baseDir)
    end
    
    # list all the file hashes of the files within the base directory
    #N Without this we won't have a direct method to list files within the remote directory, together with their hashes
    def listFileHashes
      return contentHost.listFileHashes(baseDir)
    end
    
    #N Without this we won't have an easy way to present a description of this object (for tracing, feedback)
    def to_s
      return contentHost.locationDescriptor(baseDir)
    end

    # Get the content tree, from the cached content file if it exists, 
    # otherwise get if from listing directories and files and hash values thereof
    # on the remote host. And also, if the cached content file name is specified, 
    # write the content tree out to that file.
    #N Without this we won't have a way to get the content tree representing the contents of the remote directory, possibly using an existing cached content tree file (and if not, possibly saving a cached content tree for next time)
    def getContentTree
      #N Without this check we would try to read the cached content file when there isn't one, or alternatively, we would retrieve the content details remotely, when we could have read them for a cached content file
      if cachedContentFile and File.exists?(cachedContentFile)
        #N Without this, the content tree won't be read from the cached content file
        return ContentTree.readFromFile(cachedContentFile)
      else
        #N Without this, we wouldn't retrieve the remote content details
        contentTree = contentHost.getContentTree(baseDir)
        #N Without this, the content tree might be in an arbitrary order
        contentTree.sort!
        #N Without this check, we would try to write a cached content file when no name has been specified for it
        if cachedContentFile != nil
          #N Without this, the cached content file wouldn't be updated from the most recently retrieved details
          contentTree.writeToFile(cachedContentFile)
        end
        #N Without this, the retrieved sorted content tree won't be retrieved
        return contentTree
      end
    end
    
  end
  
  # The operation of synchronising files on the remote directory with files on the local directory.
  #N Without this class, there would be no representation of the act of syncing a local file system with a remote file system.
  class SyncOperation
    # The source location (presumed to be local)
    #N Without this, we wouldn't know where the source files are
    attr_reader :sourceLocation
    
    # The destination location (presumed to be remote)
    #N Without this, we wouldn't know where the destination to be synced with the source directory is.
    attr_reader :destinationLocation
    
    #N Without this we wouldn't have an easy way to create the sync operation object with all attributes specified (and with read-only attributes)
    def initialize(sourceLocation, destinationLocation)
      #N Without this, we wouldn't remember the (local) source location
      @sourceLocation = sourceLocation
      #N Without this, we wouldn't remember the (remote) destination location
      @destinationLocation = destinationLocation
    end
    
    # Get the local and remote content trees
    #N Without this, we woulnd't have an way to get the source and destination content trees, which we need so that we can determine what files are present locally and remotely, and therefore which files need to be uploaded or deleted in order to sync the remote file system to the local one.
    def getContentTrees
      #N Without this, we wouldn't get the content tree for the local source location
      @sourceContent = @sourceLocation.getContentTree()
      #N Without this, we wouldn't get the content tree for the remote destination location
      @destinationContent = @destinationLocation.getContentTree()
    end
    
    # On the local and remote content trees, mark the copy and delete operations required
    # to sync the remote location to the local location.
    #N Without this, we woundn't have an easy way to mark the content trees for operations required to perform the sync
    def markSyncOperations
      #N Without this, the sync operations won't be marked
      @sourceContent.markSyncOperationsForDestination(@destinationContent)
      #N Without these puts statements, the user won't receive feedback about what sync operations (i.e. copies and deletes) are marked for execution
      puts " ================================================ "
      puts "After marking for sync --"
      puts ""
      puts "Local:"
      #N Without this, the user won't see what local files and directories are marked for copying (i.e. upload)
      @sourceContent.showIndented()
      puts ""
      puts "Remote:"
      #N Without this, the user won't see what remote files and directories are marked for deleting
      @destinationContent.showIndented()
    end
    
    # Delete the local and remote cached content files (which will force a full recalculation
    # of both content trees next time)
    #N Without this, there won't be an easy way to delete all cached content files (thus forcing details for both content trees to be retrieved directly from the source & destination locations)
    def clearCachedContentFiles
      #N Without this, the (local) source cached content file won't be deleted
      @sourceLocation.clearCachedContentFile()
      #N Without this, the (remote) source cached content file won't be deleted
      @destinationLocation.clearCachedContentFile()
    end
    
    # Do the sync. Options: :full = true means clear the cached content files first, :dryRun
    # means don't do the actual copies and deletes, but just show what they would be.
    #N Without this, there won't be a single method that can be called to do the sync operations (optionally doing a dry run)
    def doSync(options = {})
      #N Without this, the content files will be cleared regardless of whether :full options is specified
      if options[:full]
        #N Without this, the content files won't be cleared when the :full options is specified
        clearCachedContentFiles()
      end
      #N Without this, the required content information won't be retrieved (be it from cached content files or from the actual locations)
      getContentTrees()
      #N Without this, the required copy and delete operations won't be marked for execution
      markSyncOperations()
      #N Without this, we won't know if only a dry run is intended
      dryRun = options[:dryRun]
      #N Without this check, the destination cached content file will be cleared, even for a dry run
      if not dryRun
        #N Without this check, the destination cached content file will remain there, even though it is stale once an actual (non-dry-run) sync operation is started.
        @destinationLocation.clearCachedContentFile()
      end
      #N Without this, the marked copy operations will not be executed (or in the case of dry-run, they won't be echoed to the user)
      doAllCopyOperations(dryRun)
      #N Without this, the marked delete operations will not be executed (or in the case of dry-run, they won't be echoed to the user)
      doAllDeleteOperations(dryRun)
      #N Without this check, the destination cached content file will be updated from the source content file, even if it was only a dry-run (so the remote location hasn't actually changed)
      if (not dryRun and @destinationLocation.cachedContentFile and @sourceLocation.cachedContentFile and
          File.exists?(@sourceLocation.cachedContentFile))
        #N Without this, the remote cached content file won't be updated from local cached content file (which is a reasonable thing to do assuming the sync operation completed successfully)
        FileUtils::Verbose.cp(@sourceLocation.cachedContentFile, @destinationLocation.cachedContentFile)
      end
      #N Without this, any cached SSH connections will remain unclosed (until the calling application has terminated, which may or may not happen soon after completing the sync).
      closeConnections()
    end

    # Do all the copy operations, copying local directories or files which are missing from the remote location
    #N Without this, there won't be an easy way to execute (or echo if dry-run) all the marked copy operations
    def doAllCopyOperations(dryRun)
      #N Without this, the copy operations won't be executed
      doCopyOperations(@sourceContent, @destinationContent, dryRun)
    end
    
    # Do all delete operations, deleting remote directories or files which do not exist at the local location
    #N Without this, there won't be an easy way to execute (or echo if dry-run) all the marked delete operations
    def doAllDeleteOperations(dryRun)
      #N Without this, the delete operations won't be executed
      doDeleteOperations(@destinationContent, dryRun)
    end
    
    # Execute a (local) command, or, if dryRun, just pretend to execute it.
    # Raise an exception if the process exit status is not 0.
    #N Without this, there won't be an easy way to execute a local command, echoing it to the user, and optionally _not_ executing it if "dry run" is specified
    def executeCommand(command, dryRun)
      #N Without this, the command won't be echoed to the user
      puts "EXECUTE: #{command}"
      #N Without this check, the command will be executed, even though it is intended to be a dry run
      if not dryRun
        #N Without this, the command won't be executed (when it's not a dry run)
        system(command)
        #N Without this, a command that fails with error will be assumed to have completed successfully (which will result in incorrect assumptions in some cases about what has changed as a result of the command, e.g. apparently successful execution of sync commands would result in the assumption that the remote directory now matches the local directory)
        checkProcessStatus(command)
      end
    end
    
    # Recursively perform all marked copy operations from the source content tree to the
    # destination content tree, or if dryRun, just pretend to perform them.
    def doCopyOperations(sourceContent, destinationContent, dryRun)
      for dir in sourceContent.dirs
        if dir.copyDestination != nil
          sourcePath = sourceLocation.getFullPath(dir.relativePath)
          destinationPath = destinationLocation.getFullPath(dir.copyDestination.relativePath)
          destinationLocation.contentHost.copyLocalToRemoteDirectory(sourcePath, destinationPath, dryRun)
        else
          doCopyOperations(dir, destinationContent.getDir(dir.name), dryRun)
        end
      end
      for file in sourceContent.files
        if file.copyDestination != nil
          sourcePath = sourceLocation.getFullPath(file.relativePath)
          destinationPath = destinationLocation.getFullPath(file.copyDestination.relativePath)
          destinationLocation.contentHost.copyLocalFileToRemoteDirectory(sourcePath, destinationPath, dryRun)
        end
      end
    end
    
    # Recursively perform all marked delete operations on the destination content tree, 
    # or if dryRun, just pretend to perform them.
    def doDeleteOperations(destinationContent, dryRun)
      for dir in destinationContent.dirs
        if dir.toBeDeleted
          dirPath = destinationLocation.getFullPath(dir.relativePath)
          destinationLocation.contentHost.deleteDirectory(dirPath, dryRun)
        else
          doDeleteOperations(dir, dryRun)
        end
      end
      for file in destinationContent.files
        if file.toBeDeleted
          filePath = destinationLocation.getFullPath(file.relativePath)
          destinationLocation.contentHost.deleteFile(filePath, dryRun)
        end
      end
    end
    
    def closeConnections
      destinationLocation.closeConnections()
    end
  end
end
