#!/bin/sh

# Author: Abhinav Seewoosungkur
# Thanks to:
# Александр Рыжов for having given the requirements for this script
# Victor Merkushov for having provided his router to test this script
#
# Target: Oleg Firmware
#
# What the script does
# 1. Iterates through a list of connected drives
# 2. Ask user which drive to use for Entware
# 3. Iterates through a list of partitions for the selected drive
# 4. Looks for Linux partition type 83 and ask which one to use for Entware
# 5. Repeats step 4 for Data partition
# 6. Looks for a swap partition
# 7. Adds the UUID to the fstab
# 8. Writes the startup and shutdown scripts
# 9. Saves changes to flash
# 10. Auto mounts all partitions
# 11. Installs the Entware package manager.

# Text formatters
warning() {
    echo -e "\033[33mWarning: $1\033[0m"
}

error() {
    echo -e "\033[31mError: $1\033[0m"
}

success() {
    echo -e "\033[32mSuccess: $1\033[0m"
}

info() {
    echo -e "Info: $1"
}

# Get the drive size
# arg1 the drive path: /dev/sda
# returns the drive size
drive_size() {
    echo `fdisk -l | grep "Disk $1" | cut -d" " -f3,4 | cut -d"," -f1`
}

# converts kilobyte into gigabyte
# arg1 partition path: /dev/sda1
kilo2giga() {
 echo `expr \`fdisk -l | grep $1 | awk '{print $4}' | sed 's/+//g'\` / 1024 / 1024`
}

# converts kilobyte into megabyte
# arg1 partition path: /dev/sda1
kilo2mega() {
 echo `expr \`fdisk -l | grep $1 | awk '{print $4}' | sed 's/+//g'\` / 1024`
}

# check if a partition exists with a format type
# arg1 partition path
# arg2 fdisk partition type number
is_partition() {
    foundPartition=0
    if [ `fdisk -l | grep $1 | awk '{print $5}'` == $2 ]
    then 
	foundPartition=1
	success "Partition created"
    else
	foundPartition=0
	Error "Partition not created"
    fi
}

persistflash() {
    flashfs save && flashfs commit && flashfs enable
}

clear_fstab () {
    if [ -e "/etc/fstab" ]
    then
	info "removing /etc/fstab ..."
	rm /etc/fstab
    else
	info "No fstab found, proceeding ..."
    fi
}

clear_startup_shutdown_scripts() {
    if [ -e "/usr/local/sbin/post-mount" ]
    then
	info "Removing post-mount ... "
	rm  /usr/local/sbin/post-mount
    fi

    if [ -e "/usr/local/sbin/pre-shutdown" ]
	then
	info "Removing pre-shutdown ..."
	rm /usr/local/sbin/pre-shutdown
    fi
}


# Find connected drives on the router
driveCount=1 # initialize driveCount to 1

echo Info: Looking for connected drives ...

for drive in `fdisk -l | grep Disk | cut -d" " -f2 | cut -d":" -f1` # look for connected drives in router
do
    driveFound="true" # flag as true for script flow condition
    echo "[$driveCount] -->" $drive "("`drive_size $drive`")" # show user corresponding number for drive to choose
    eval drives$driveCount=$drive # simulate array: drives1=/dev/sda, drives2=/dev/sdb
    driveCount=`expr $driveCount + 1` # increment value of driveCount
done



if [ $driveCount == "1" ] # No drives found. Warn user
then
    error "no connected drives found. Check if your USB drive has been connected" 
    error "and check your USB drive\'s status LED. If an external hard disk is used," 
    error "check if the router is providing enough power. Reboot the router if" 
    error "the drive detection still fails."
    exit 1
else
    # found drive, ask user to choose the desired drive to be formatted
    echo Info: Enter a drive number or 0 to exit: [0 - `expr $driveCount - 1`]: 
    read driveNumber
    if [ "$driveNumber" == "0" ]
    then
	echo Info: Exiting ...
	exit 0
    fi
fi

# Ask user for confirmation before selecting this drive
eval chosenDrive=\$drives$driveNumber
warning "You have chosen drive $chosenDrive having size `drive_size $chosenDrive` to be used for Entware." 
warning "Press y to continue or n to abort installation."
read userConfirmation
if [ $userConfirmation == "n" ]
then
    info "Exiting ..."
    exit 0
fi

# Entware partition selection
partCount=1 # initialize part count to 1
# iterate through a list of ext linux partitions for the chosen drive
for part in `fdisk -l | grep "$chosenDrive[0-9]" | grep "83 Linux" | awk '{print $1}'` 
do
    partFound="true"

    echo "[$partCount] -->" `fdisk -l | grep $part | awk '{print $1}'` - `kilo2giga $part` GB or `kilo2mega $part` MB
    eval parts$partCount=$part # simulate an array for partitions
    partCount=`expr $partCount + 1` # increment value of partCount
done

if [ $partCount == "1" ] # no linux partition found 
then
    error "no linux partition found for Entware"
    error "Exiting ..."
    exit 1
else
    # found partition. ask user to select the partition for Entware
    info "Type the partition number for Entware"
    read entwarePartitionNumber
fi

eval entwarePartition=\$parts$entwarePartitionNumber
# echo $entwarePartition
    
echo
# Data partition selection
partCount=1 # initialize part count to 1
# iterate through a list of ext linux partitions for the chosen drive
for part in `fdisk -l | grep -v $entwarePartition | grep "$chosenDrive[0-9]" | grep "83 Linux" | awk '{print $1}'`
do
    partFound="true"
    echo "[$partCount] -->" `fdisk -l | grep $part | awk '{print $1}'` -  `kilo2giga $part` GB or `kilo2mega $part` MB
    eval parts$partCount=$part # simulate an array for partitions
    partCount=`expr $partCount + 1` # increment value of partCount
done

if [ $partCount == "1" ] # no linux partition found 
then
    error "no linux partition found for Data"
    error "Exiting ..."
    exit 1
else
    # found partition. ask user to select the partition for Data
    info "Type the partition number for Data"
    read dataPartitionNumber
fi


eval dataPartition=\$parts$dataPartitionNumber
# echo $dataPartition

echo
# Swap partition selection
partCount=1 # initialize part count to 1
# iterate through a list of ext linux partitions for the chosen drive
for part in `fdisk -l | grep "$chosenDrive[0-9]" | grep "82 Linux swap" | awk '{print $1}'`
do
    partFound="true"
    echo "[$partCount] -->" `fdisk -l | grep $part | awk '{print $1}'` - `expr \`fdisk -l | grep $part | awk '{print $4}' | sed 's/+//g'\` / 1024` MB
    eval parts$partCount=$part # simulate an array for partitions
    partCount=`expr $partCount + 1` # increment value of partCount
done

if [ $partCount == "1" ] # no linux partition found 
then
    warning "no linux partition found for swap"
    # exit 1
else
    # found partition. ask user to select the partition for swap
    info "Type the partition number for swap"
    read swapPartitionNumber
fi


eval swapPartition=\$parts$swapPartitionNumber

# Assign the UUID for each partition to their variables.
# Command explained. 
# Get the list of partitions and their UUIDs from blkid --> /dev/discs/disca/part1: LABEL="Entware" UUID="5f0a447e-57ab-46bf-9057-6ce248c6af18"
# $entwarePartition contains /dev/sda1. This needs to be translated to /dev/discs/disca/part1 for Oleg's blkid output.
# sed 's/sd/discs\/disc/g' | sed 's/[0-9]^*/\/part&/g'     does the translation
# sed -n 's/.*UUID=\"\([^\"]*\)\".*/\1/p'`     retrieves the UUID string from blkid
entwareUUID=`blkid | grep \`echo $entwarePartition | sed 's/sd/discs\/disc/g' | sed 's/[0-9]^*/\/part&/g'  \` | sed -n 's/.*UUID=\"\([^\"]*\)\".*/\1/p'`
dataUUID=`blkid | grep \`echo $dataPartition | sed 's/sd/discs\/disc/g' | sed 's/[0-9]^*/\/part&/g'  \` | sed -n 's/.*UUID=\"\([^\"]*\)\".*/\1/p'`
swapUUID=`blkid | grep \`echo $swapPartition | sed 's/sd/discs\/disc/g' | sed 's/[0-9]^*/\/part&/g'  \` | sed -n 's/.*UUID=\"\([^\"]*\)\".*/\1/p'`


if [ $entwareUUID != "" ]
then
    # clear fstab before proceeding
    clear_fstab
    echo Info: Writing mount point for $entwarePartition in fstab
    echo "#device                 Mountpoint      FStype  Options         Dump    Pass#" >> /etc/fstab
    echo "UUID="$entwareUUID"  /opt      ext3    rw,noatime 1       1" >> /etc/fstab
else
    error "Partition not found for Entware installation, exiting..."
    exit 1
fi

echo ""

echo Info: Checking for a partition appropriate for Data ...

if [ $dataUUID != "" ]
then
    echo Info: Writing mount point for $dataPartition in fstab
    echo "UUID="$dataUUID"  /mnt      ext3    rw,noatime 1       1" >> /etc/fstab
else
    warning "Partition not selected for Data installation. Installation will nevertheless continue."
fi


echo Info: Checking for a suitable swap partition...
if [ $swapUUID != "" ]
then
    echo Info: Writing mount point for $swapPartition in fstab
    echo "UUID="$swapUUID"  none            swap    sw              0       0" >> /etc/fstab
else
    warning "No swap partition found. This will not affect the installation but swap is strongly"
    warning "recommended if the router is to be used for webserver or memory hungry programs."
fi

echo Info: Making fstab persitent in flashfs ...
if [ -e "/usr/local/.files" ]
then
    info "Removing  /usr/local/.files"
    rm  /usr/local/.files
fi
echo "/etc/fstab" >> /usr/local/.files
persistflash

echo Info: Configuring startup and shutdown scripts...
clear_startup_shutdown_scripts
mkdir -p /usr/local/sbin/
touch /usr/local/sbin/post-mount
touch /usr/local/sbin/pre-shutdown
chmod +x /usr/local/sbin/*

echo Info: saving in flashfs ...
persistflash

echo Info: Configuring post-mount script ...
echo "#! /bin/sh" >> /usr/local/sbin/post-mount
echo "/opt/etc/init.d/rc.unslung start" >> /usr/local/sbin/post-mount
echo Info: Configuring pre-shutdown script
echo "#! /bin/sh" >> /usr/local/sbin/pre-shutdown
echo "/opt/etc/init.d/rc.unslung stop" >> /usr/local/sbin/pre-shutdown
echo "sleep 10s" >> /usr/local/sbin/pre-shutdown
echo "for i in `cat /proc/mounts | awk '/ext3/{print($1)}'` ; do"  >> /usr/local/sbin/pre-shutdown
echo "  mount -oremount,ro $i" >> /usr/local/sbin/pre-shutdown
echo "done" >> /usr/local/sbin/pre-shutdown
echo "swapoff -a" >> /usr/local/sbin/pre-shutdown
echo "sleep 1s"  >> /usr/local/sbin/pre-shutdown

echo Info: Making flashfs persistent
persistflash

# mount all volumes
info "Mounting volumes..."
mount -a

echo Ready to install Entware package management

cd /opt
wget http://wl500g-repo.googlecode.com/svn/ipkg/entware_install.sh
sh ./entware_install.sh

#### References ####
# http://www.bashguru.com/2010/01/shell-colors-colorizing-shell-scripts.html
# http://www.cyberciti.biz/faq/linux-partition-howto-set-labels/
# http://www.cyberciti.biz/faq/linux-finding-using-uuids-to-update-fstab/
# http://stackoverflow.com/questions/13565658/right-tool-to-filter-the-uuid-from-the-output-of-blkid-program-using-grep-cut
