#!/bin/bash
# Borg Linux Backup Script V1.0 Config File

###########################
##Borg Backup Settings##
###########################

#Location of your borg binary, you usually don't have to change this 
BORGLOCATION=borg

#Path to your borg Repository (Refer to borg Docs) 
BORGREPOSITORY="myuser@myhost:myrepo"

##Set this, if your repo is encypted with a password
#BORGPASSPHRASE=""

##Choose a compression algorithm
COMPRESSION="lz4"


#################
##BACKUP METHOD##
#################
##Possible values:
## simple: Just backup a path of a mounted filesystem recursively
## lvm: Create a lvm snapshot and backup the files on the filesystem
## lvm-image: Create a lvm snapshot and backup the whole device. Suitable for bare metal restores. Can use more storage that simple or lvm, because the whole device is backed up, which can include data which is deleted in the file system.
## btrfs: Create a btrfs snapshot and backup the files on the filesystem
## check: Do not perform a backup, do only check the specified repo
BACKUPMETHOD="simple"


#######################
##SIMPLE METHOD SETUP##
#######################

##Path to backup recursively
#BACKUPPATH=""

############################
##LVM (IMAGE) METHOD SETUP##
############################

##Name of volume group containing the logical volume to backup
#VOLUMEGROUP=""

##Name of logical volume to backup
#LOGICALVOLUME=""

##Size of Snapshot, e. g. 2G for 2 gigabytes
#SNAPSHOTSIZE=""

######################
##BTRFS METHOD SETUP##
######################

##Mountpath of the btrfs filesystem
#MOUNTPATH=""

###########
##PRUNING##
###########

##Should borg Linux Backup do pruning? If yes, define at least one "KEEP" Parameter. Pruning is never done in "check" Method. (0/1)
PRUNING=0

##Minutely backups to keep
#KEEPMINUTES=0

##Hourly backups to keep
#KEEPHOURS=0

##Daily backups to keep
#KEEPDAYS=90

##Weekly backups to keep
#KEEPWEEKS=0

##Monthly backups to keep
#KEEPMONTHS=0

##Monthly backups to keep
#KEEPYEARLY=0

##Number of last backups that should always be kept
#KEEPLAST=90

###############
##MAIL Config##
###############

##Should borg Linux Backup send mails? (0/1)
SENDMAILS=0

##Sender mail address
#MAILFROM=""

##Recipient mail address
#MAILTO=""

##SMTP Server
#MAILHOST=""

##SMTP Username
#MAILUSER=""

##SMTP Password
#MAILPASSWORD=""

##USE TLS (no/yes)
#MAILTLS=""

###########
##Logging##
###########

## Should savelog be used for log rotation?
USE_SAVELOG=0

## How many log generations should be kept for this job?
LOG_GENERATIONS=7
