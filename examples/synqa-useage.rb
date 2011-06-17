# Sample code for synqa useage -- you will need to fill in your own details

require 'synqa.rb'
require 'based'
require 'digest/sha2'

STDOUT.sync = true

include Synqa
sha256Sum = Sha256SumCommand.new()    # sha256sum (with 2 characters between hash and file name)
sha256 = Sha256Command.new()          # sha256 -r (with 1 space between hash and file name)

localContentLocation = LocalContentLocation.new(Based::BaseDirectory.new("c:/dev/src/project"), 
                                                Digest::SHA256, 
                                                "c:/temp/synqa/local.project.content.cache.txt")

remoteHost = SshContentHost.new("username@host.example.com", 
                                sha256, "plink", "pscp")

# Note: the specification of plink & pscp assumes that keys are managed with Pageant, and therefore
# do not need to be specified on the command line.
                                
remoteContentLocation = RemoteContentLocation.new(remoteHost, 
                                                  "/home/username/public", 
                                                  "c:/temp/synqa/remote.project.content.cache.txt")

# Note: the cache files are currently written, but not yet used to speed up the sync 

syncOperation = SyncOperation.new(localContentLocation, remoteContentLocation)

syncOperation.doSync(:dryRun => true)  # set to false to make it actually happen
