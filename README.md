borg-linux-backup is a script, backing up the files of a linux filesystem with borg and supporting various ways  to secure data consistency in the backup. The script can send an email. It also creates a timestamp file to monitor the last successful backup by the timestamp of that file. The script needs to be run as root.

The only argument given to borg-linux-backup.sh is the name of the config file of the specific job located in ./config/ folder. The name of the config file is also the jobname, located in the archive namein borg.

For mail sending the programm sendemail and the libarys perl libaries Net::SSLeay and IO::Socket::SSL need to be installed. Under debian and ubuntu, this can be done with "apt install sendemail libnet-ssleay-perl libio-socket-ssl-perl".

Supported modes for consistency:

simple: Just backup a path of a mounted filesystem recursively
lvm: Create a lvm snapshot and backup the files on the filesystem
lvm-image: Create a lvm snapshot and backup the whole device. Suitable for bare metal restores. Can use more storage that simple or lvm, because the whole device is backed up, which can include data which is deleted in the file system.
btrfs: Create a btrfs snapshot and backup the files on the filesystem
check: Do not perform a backup, do only check the specified repo
