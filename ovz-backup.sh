#!/bin/sh

#List of openvz containers by ID only
vzlist="
100
101
"

#Variables
date=$(date '+%m-%d-%Y')
vzdump=$(which vzdump)
vzdumpfolder="/vz/dump"
vzdumpopts="--quiet --dumpdir $vzdumpfolder --tmpdir $vzdumpfolder --compress --stdexcludes"
scp=$(which scp)
scpopts="-q"
backuphost="backup.myhost.com"
backupfolder="/mnt/drive1/backup-users/backupovz" # no trailing slash 
backupuser="backupovz"

## START LOOP
for i in $vzlist; do
  checkvmid=$(vzlist -a $i 2>/dev/null)
  vmname=$(vzlist -Ho hostname $i)
  time=$(date '+%r')
  dumpfile="$vmname-$date-vzdump.tgz"
  lockfile="/tmp/$i-vmdump.lock"
  
  #Check if ID exists
  if [ -z "$checkvmid" ]; then
      echo
      echo "[$time on $date] ERROR Virtual machine $i does not exist...I will not run for this VM!"
      echo
      continue
  fi

  #Check for lock file
  if [ -e "$lockfile" ]; then
      echo
      echo "[$time on $date] ERROR lock file exists for $vmname...I will not run for this VM!"
      echo
      continue
  fi

  #Create lock file
  touch $lockfile 1>/dev/null

  #Remove any already existing backup
  if [ -f "$vzdumpfolder/vzdump-$i.tgz" ]; then
      echo -n "[$time on $date] Dump file existed already...deleting it..."
      rm -rf $vzdumpfolder/vzdump-$i.tgz 1>/dev/null
      echo "Done."
  fi

  echo
  echo -n "[$time on $date] Start backup of VM $vmname..."
  $vzdump $vzdumpopts $i
  echo "Done."

  #rename local file
  #touch $vzdumpfolder/vzdump-$i.tgz
  mv $vzdumpfolder/vzdump-$i.tgz $vzdumpfolder/$dumpfile 1>/dev/null

  #delete log file
  rm -rf $vzdumpfolder/vzdump-$i.log

  #send the backup
  echo -n "[$time on $date] Sending backup of VM $vmname to remote server $backuphost..."
  $scp $scpopts $vzdumpfolder/$dumpfile $backupuser@$backuphost:$backupfolder/$dumpfile
  echo "Done."

  #delete lock file
  rm -rf $lockfile 1>/dev/null

  #delete local tar file
  rm -rf $vzdumpfolder/$dumpfile

done

## ALL DONE
echo
echo "Done."
echo

exit 0
