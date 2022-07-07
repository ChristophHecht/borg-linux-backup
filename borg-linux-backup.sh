#!/bin/bash
# Borg Linux Backup Script V1.0

function f_log {
    echo "$(date +"%Y-%m-%d-%H-%M-%S"):$1" | tee -a $LOGFILE
    if [ "$2" = "error" ]
    then
        echo "$(date +"%Y-%m-%d-%H-%M-%S"):UNSUCCESSFULLY FINISHED BACKUP OF $HOST $JOBNAME ON $TIMESTAMP"
    fi
    }

function f_print {
    echo "$(date +"%Y-%m-%d-%H-%M-%S"):$1"
}

function f_mail {
    if [ $SENDMAILS = 1 ]
    then
        if [ "$1" = "error" ]
        then
            sendemail -f $MAILFROM -t $MAILTO -u "ERROR: BORG-LINUX-BACKUP $HOST $JOBNAME ON $TIMESTAMP" -m ":(" -s $MAILHOST -xu $MAILUSER -xp $MAILPASSWORD -o tls=$MAILTLS -a $LOGFILE
        fi
        if [ "$1" = "success" ]
        then
            sendemail -f $MAILFROM -t $MAILTO -u "SUCCESS: BORG-LINUX-BACKUP $HOST $JOBNAME ON $TIMESTAMP" -m ":)" -s $MAILHOST -xu $MAILUSER -xp $MAILPASSWORD -o tls=$MAILTLS -a $LOGFILE
        fi
        if [ "$1" = "warning" ]
        then
            sendemail -f $MAILFROM -t $MAILTO -u "WARNING: BORG-LINUX-BACKUP $HOST $JOBNAME ON $TIMESTAMP" -m ":/" -s $MAILHOST -xu $MAILUSER -xp $MAILPASSWORD -o tls=$MAILTLS -a $LOGFILE
        fi
    fi
}

function f_error {
    f_log "$1" "error"
    f_mail "error"
    f_cleanup
    exit $2
}

function f_cleanup {
    f_log "Cleaning up"
    if [ $LVM_MOUNTED = 1 ]
    then
        f_log "Unmounting LVM Snapshot"
        umount -f $MOUNTPATH | tee -a $LOGFILE
        if [ $PIPESTATUS -ne 0 ]
        then
            f_log "Warning: Could not unmount LVM Snapshot."
            WARNING=1
        fi
        LVM_MOUNTED=0
        f_log "Finished unmounting LVM Snapshot"
    fi

    if [ $LVM_SNAPSHOTTED = 1 ]
    then
        f_log "Deleting LVM Snapshot"
        lvremove -f $SNAPSHOTPATH | tee -a $LOGFILE
        if [ $PIPESTATUS -ne 0 ]
        then
            f_log "Warning: Could not delete LVM Snapshot."
            WARNING=1
        fi
        LVM_SNAPSHOTTED=0
        f_log "Finished deleting LVM Snapshot"
    fi

    if [ $BTRFS_SNAPSHOTTED = 1 ]
    then
        f_log "Deleting BTRFS Snapshot"
        btrfs subvolume delete $SNAPSHOTPATH | tee -a $LOGFILE
        if [ $PIPESTATUS -ne 0 ]
        then
            f_log "Warning: Could not delete BTRFS Snapshot."
            WARNING=1
        fi
        BTRFS_SNAPSHOTTED=0
        f_log "Finished deleting BTRFS Snapshot"
    fi

    if [ $LOCKED = 1 ]
    then
        f_log "Removing lock"
        rm $LOCKFILE | tee -a $LOGFILE
        if [ $PIPESTATUS -ne 0 ]
        then
            f_log "Warning: Could not remove lock."
            WARNING=1
        fi
        LOCKED=0
        f_log "Finished removing lock"
    fi
    f_log "Finished cleaning up"
}

if [ "$#" -ne 1 ]
then
    echo "Usage: $0 <configfile> (located in folder ./config)" >&2
    exit 1
fi

##INPUT
JOBNAME=$1
##INPUT
WORKINGDIRECTORY=$(dirname "$BASH_SOURCE")
CONFIGFILE="$WORKINGDIRECTORY/config/$JOBNAME"
TIMESTAMP="$(date +"%Y-%m-%d-%H-%M-%S")"

#QUIT IF CONFIGFILE DOES NOT EXIST
if [ ! -f $CONFIGFILE ]
then
    f_print "Error: Configfile not found, aborting."
    exit 2
fi

chmod +x $CONFIGFILE
. $CONFIGFILE

#SET ENVIRONMENT VARIABLES
export BORG_PASSPHRASE=$BORG_PASSPHRASE

#SET HOST
HOST=$(hostname)

#SET STATUS VARIABLES FOR CLEANUP
LOCKED=0
LVM_SNAPSHOTTED=0
LVM_MOUNTED=0
BTRFS_SNAPSHOTTED=0
WARNING=0

#SET VARIABLES FOR LVM, IF USED
if [ $BACKUPMETHOD = "lvm" ] || [ $BACKUPMETHOD = "lvm-image" ]
then
    SNAPSHOTNAME="borg-linux-backup-$JOBNAME"
    LVPATH="/dev/$VOLUMEGROUP/$LOGICALVOLUME"
    SNAPSHOTPATH="/dev/$VOLUMEGROUP/$SNAPSHOTNAME"
    MOUNTPATH="$WORKINGDIRECTORY/mounts/$JOBNAME"
fi

#SET VARIABLES FOR BTRFS, IF USED
if [ $BACKUPMETHOD = "btrfs" ]
then
    SNAPSHOTNAME=".snap_$JOBNAME"
    SNAPSHOTPATH="$MOUNTPATH/$SNAPSHOTNAME"
fi

#Set Backup Path
if [ $BACKUPMETHOD = "lvm-image" ] || [ $BACKUPMETHOD = "btrfs" ]
then
    BKUPPATH=$SNAPSHOTPATH
fi

if [ $BACKUPMETHOD = "lvm" ]
then
    BKUPPATH=$MOUNTPATH
fi

if [ $BACKUPMETHOD = "simple" ]
then
    BKUPPATH=$BACKUPPATH
fi

#FILE PATHS
TIMESTAMPFILE="$WORKINGDIRECTORY/timestamps/$JOBNAME"
LOCKFILE="$WORKINGDIRECTORY/locks/$JOBNAME"

#CREATE FOLDER STRUCTURE
DIRTIMESTAMPFILE="$WORKINGDIRECTORY/timestamps/"
DIRLOCKFILE="$WORKINGDIRECTORY/locks/"
DIRLOGFILE="$WORKINGDIRECTORY/logs/"
mkdir -p $DIRTIMESTAMPFILE $DIRLOCKFILE $DIRLOGFILE $MOUNTPATH

#LOGFILE HANDLING
if [ $USE_SAVELOG = 0 ]
then
    LOGFILE="$WORKINGDIRECTORY/logs/$JOBNAME-$TIMESTAMP"
fi
if [ $USE_SAVELOG = 1 ]
then
    LOGFILE="$WORKINGDIRECTORY/logs/$JOBNAME"
    savelog -n -c $LOG_GENERATIONS $LOGFILE
fi

#Logfile erstellen
touch $LOGFILE

f_log "----------STARTING BACKUP OF $HOST $JOBNAME ON $TIMESTAMP----------"

##QUIT IF LOCKFILE EXISTS
if [ -f $LOCKFILE ]
then
    f_error "Error: Lockfile found." 3
fi

##CREATE LOCKFILE
touch $LOCKFILE
LOCKED=1

##LVM (IMAGE) HANDLING:CREATE LVM SNAPSHOT
if [ $BACKUPMETHOD = "lvm" ] || [ $BACKUPMETHOD = "lvm-image" ]
then
    f_log "Creating LVM Snapshot."
    lvcreate -L${SNAPSHOTSIZE} -s -n $SNAPSHOTNAME $LVPATH | tee -a $LOGFILE
    if [ $PIPESTATUS -ne 0 ]
    then
        f_error "Error: LVM Snapshot could not be created." 4
    fi
    LVM_SNAPSHOTTED=1
    f_log "Finished creating LVM Snapshot"
fi

##LVM HANDLING: MOUNT SNAPSHOT
if [ $BACKUPMETHOD = "lvm" ]
then
    f_log "Mounting LVM Snapshot."
    mount $SNAPSHOTPATH $MOUNTPATH | tee -a $LOGFILE
    if [ $PIPESTATUS -ne 0 ]
    then
        f_error "Error: LVM Snapshot could not be mounted." 5
    fi
    LVM_MOUNTED=1
    f_log "Finished mounting LVM Snapshot"
fi

##BTRFS HANDLING:CREATE BTRFS SNAPSHOT
if [ $BACKUPMETHOD = "btrfs" ]
then
    f_log "Creating BTRFS Snapshot."
    btrfs subvolume snapshot $MOUNTPATH $SNAPSHOTPATH | tee -a $LOGFILE
    if [ $PIPESTATUS -ne 0 ]
    then
        f_error "Error: BTRFS Snapshot could not be created." 6
    fi
    BTRFS_SNAPSHOTTED=1
    f_log "Finished creating BTRFS Snapshot"
fi

##DO BACKUP
if [ $BACKUPMETHOD = "simple" ] || [ $BACKUPMETHOD = "lvm" ] || [ $BACKUPMETHOD = "btrfs" ]
then
    f_log "Running Backup Job."
    $BORGLOCATION create --info --compression $COMPRESSION --stats $BORGREPOSITORY::$JOBNAME-$TIMESTAMP $BKUPPATH 2>&1 >/dev/null | tee -a $LOGFILE
    BORGERRORLEVEL=$PIPESTATUS
    if [ $BORGERRORLEVEL -gt 1 ]
    then
        f_error "Error: borg returned $BORGERRORLEVEL." 7
    fi
    if [ $BORGERRORLEVEL -gt 0 ]
    then
        WARNING=1
        f_log "Warning: borg returned $BORGERRORLEVEL."
    fi
    f_log "Finished backup job."
fi

##DO BACKUP LVM-IMAGE
if [ $BACKUPMETHOD = "lvm-image" ]
then
    f_log "Running Backup Job."
    $BORGLOCATION create --read-special --info --compression $COMPRESSION --stats $BORGREPOSITORY::$JOBNAME-$TIMESTAMP $BKUPPATH 2>&1 >/dev/null | tee -a $LOGFILE
    BORGERRORLEVEL=$PIPESTATUS
    if [ $BORGERRORLEVEL -gt 1 ]
    then
        f_error "Error: borg returned $BORGERRORLEVEL." 8
    fi
    if [ $BORGERRORLEVEL -gt 0 ]
    then
        WARNING=1
        f_log "Warning: borg returned $BORGERRORLEVEL."
    fi
    f_log "Finished backup job."
fi

##DO CHECK
if [ $BACKUPMETHOD = "check" ]
    then
    f_log "Running repository check"
    $BORGLOCATION check $BORGREPOSITORY 2>&1 >/dev/null | tee -a $LOGFILE
    BORGERRORLEVEL=$PIPESTATUS
    if [ $BORGERRORLEVEL -gt 1 ]
    then
        f_error "Error: borg returned $BORGERRORLEVEL." 9
    fi
    if [ $BORGERRORLEVEL -gt 0 ]
    then
        WARNING=1
        f_log "Warning: borg returned $BORGERRORLEVEL."
    fi
    f_log "Finished repository check job."
fi

##CLEANUP
f_cleanup

##DO PRUNE
if [ $BACKUPMETHOD != "check" ] && [ $PRUNING = 1 ]
then
    f_log "Pruning borg repo"
    $BORGLOCATION prune --force -s --keep-minutely $KEEPMINUTES -H $KEEPHOURS -d $KEEPDAYS -w $KEEPWEEKS -m $KEEPMONTHS --keep-last $KEEPLAST -P $JOBNAME $BORGREPOSITORY 2>&1 >/dev/null | tee -a $LOGFILE
    BORGERRORLEVEL=$PIPESTATUS
    if [ $BORGERRORLEVEL -gt 1 ]
    then
        f_error "Error: borg returned $BORGERRORLEVEL." 10
    fi
    if [ $BORGERRORLEVEL -gt 0 ]
    then
        WARNING=1
        f_log "Warning: borg returned $BORGERRORLEVEL."
    fi
    f_log "Finished pruning borg repo"
fi

##DO COMPACT
if [ $BACKUPMETHOD != "check" ] && [ $PRUNING = 1 ]
then
    f_log "Compacting borg repo."
    $BORGLOCATION compact $BORGREPOSITORY 2>&1 >/dev/null | tee -a $LOGFILE
    BORGERRORLEVEL=$PIPESTATUS
    if [ $BORGERRORLEVEL -gt 1 ]
    then
        f_error "Error: borg returned $BORGERRORLEVEL."
    fi
    if [ $BORGERRORLEVEL -gt 0 ]
    then
        WARNING=1
        f_error "Warning: borg returned $BORGERRORLEVEL."
    fi
    f_log "Finished compacting borg repo."
fi


##FINISH
if [ $WARNING = 1 ]
then
    f_log "Finished borg-linux-backup with warnings" | tee -a $LOGFILE
    f_mail "warning"
fi
if [ $WARNING = 0 ]
then
    f_log "Successfully finished borg-linux-backup" | tee -a $LOGFILE
    f_mail "success"
fi
rm $TIMESTAMPFILE
touch $TIMESTAMPFILE
exit 0
