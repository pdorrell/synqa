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
          #N Without raising this error, and unexpected directory not in the base directory would just be ignored
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
      ssh(remoteFileHashLinesCommand.join(" ")) do |line| 
        puts " #{line}"
        yield line 
      end
    end
    
    # List all files within the base directory to stdout
    def listFiles(baseDir)
      baseDir = normalisedDir(baseDir)
      ssh(findFilesCommand(baseDir).join(" ")) do |line| 
        puts " #{line}"
      end
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
    
    # The relative name of this file in the content tree (relative to the base dir)
    def relativePath
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
    
    # the path of the directory that this content tree represents, relative to the base directory
    def relativePath
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
        puts "#{currentIndent} [COPY to #{copyDestination.relativePath}]"
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
          puts "#{nextIndent} [COPY to #{file.copyDestination.relativePath}]"
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
    
    # the base directory, for example of type Based::BaseDirectory. Methods invoked are: allFiles, subDirs and fullPath.
    # For file and dir objects returned by allFiles & subDirs, methods invoked are: relativePath and fullPath
    attr_reader :baseDirectory
    # the ruby class that generates the hash, e.g. Digest::SHA256
    attr_reader :hashClass
    
    def initialize(baseDirectory, hashClass, cachedContentFile = nil)
      super(cachedContentFile)
      @baseDirectory = baseDirectory
      @hashClass = hashClass
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
    # the remote SshContentHost
    attr_reader :contentHost
    
    # the base directory on the remote system
    attr_reader :baseDir
    
    def initialize(contentHost, baseDir, cachedContentFile = nil)
      super(cachedContentFile)
      @contentHost = contentHost
      @baseDir = normalisedDir(baseDir)
    end
    
    def closeConnections
      @contentHost.closeConnections()
    end
    
    # list files within the base directory on the remote contentHost
    def listFiles()
      contentHost.listFiles(baseDir)
    end
    
    # object required to execute SCP (e.g. "scp" or "pscp", possibly with extra args)
    def sshAndScp
      return contentHost.sshAndScp
    end
    
    # get the full path of a relative path
    def getFullPath(relativePath)
      return baseDir + relativePath
    end
    
    # execute an SSH command on the remote host (or just pretend, if dryRun is true)
    def ssh(commandString, dryRun = false)
      contentHost.sshAndScp.ssh(commandString, dryRun)
    end
    
    # list all sub-directories of the base directory on the remote host
    def listDirectories
      return contentHost.listDirectories(baseDir)
    end
    
    # list all the file hashes of the files within the base directory
    def listFileHashes
      return contentHost.listFileHashes(baseDir)
    end
    
    def to_s
      return contentHost.locationDescriptor(baseDir)
    end

    # Get the content tree, from the cached content file if it exists, 
    # otherwise get if from listing directories and files and hash values thereof
    # on the remote host. And also, if the cached content file name is specified, 
    # write the content tree out to that file.
    def getContentTree
      if cachedContentFile and File.exists?(cachedContentFile)
        return ContentTree.readFromFile(cachedContentFile)
      else
        contentTree = contentHost.getContentTree(baseDir)
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
      if (not dryRun and @destinationLocation.cachedContentFile and @sourceLocation.cachedContentFile and
          File.exists?(@sourceLocation.cachedContentFile))
        FileUtils::Verbose.cp(@sourceLocation.cachedContentFile, @destinationLocation.cachedContentFile)
      end
      closeConnections()
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
