#!/bin/sh
# function declarations
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

# arg1 the drive path: /dev/sda
# returns the drive size
drive_size() {
    echo `fdisk -l | grep "Disk $1" | cut -d" " -f3,4 | cut -d"," -f1`
}

# arg1 partition number
# arg2 partition size. Format type to be specified after size. 100M, 128k, 4G
# arg3 The disk path. Example /dev/sda
createpartition() {
    info "Creating partition $1 with $2 in disk $3"
    (echo n; echo p; echo $1; echo ; echo "+$2"; echo w) | fdisk $3
    # new partition; primary; partition number; enter; size; write to disk
    info "Partition $1 created"
    if [ $1 == 2 ] # if swap
    then
	(echo t; echo $1; echo 82; echo w) | fdisk $3
	info "Configured swap type"
    fi
}

# clears the partition table
clear_partition_table() {
    echo Clearing the partition table for disk $1
    (echo o; echo w) | fdisk $1
    info "The partition table has been cleared for disk $1"
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


# Find connected drives on the router
driveCount=1 # initialize driveCount to 1

echo Info: Looking for connected drives ...

for drive in `fdisk -l | grep Disk | cut -d" " -f2 | cut -d":" -f1` # look for connected drives in router
do
    driveFound="true" # flag as true for script flow condition
    echo "[$driveCount] -->" $drive "("`drive_size $drive`")" # show user corresponding number for drive to choose
    eval drives$driveCount=$drive # simulate array: drives1=/dev/sda, drives2=/dev/sdb
    driveCount=`expr $driveCount + 1` # increment value of i
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
    echo Info: Type in your drive number to auto format it. You will then be asked how should the drive be formatted.
    echo Info: Enter a drive number or 0 to exit: [0 - `expr $driveCount - 1`]: 
    read driveNumber
    if [ "$driveNumber" == "0" ]
    then
	echo Info: Exiting ...
	exit 0
    fi
fi

# Ask user for confirmation before proceeding with format
eval chosenDrive=\$drives$driveNumber
warning "You have chosen drive $chosenDrive having size `drive_size $chosenDrive` to be formatted. Press y to continue or n to abort installation."
read userConfirmation
if [ $userConfirmation == "n" ]
then
    info "Exiting ..."
    exit 0
fi

info "3 partitions will be created on the drive."
info "1. /opt"
info "2. /mnt"
info "3. swap"


info "Auto partition will now proceed. Leave enough space for swap. A space equivalent to your ram size will be enough for swap."
warning "Write the unit type after the size without spaces. Example: 128M or 4G"
info "How much space would you like to allocate for the swap?"
read swapsize

info "How much space would you like to allocate for the /opt partition?"
read optsize

info "How much space would you like to allocate for the /mnt partition?"
read mntsize

clear_partition_table $chosenDrive

# initialize the partition count
partitionCount=1
for partitionsize in $optsize $swapsize $mntsize
do
    # echo $partition
    createpartition $partitionCount $partitionsize $chosenDrive
    partitionCount=`expr $partitionCount + 1`
    # echo $partitionCount
done

# Test if partitions have been created
optpartition="$chosenDrive""1"
info "Checking partition $optpartition /opt"
is_partition $optpartition "83"
if [ $foundPartition == 0 ]
then
    error "partition was not created. Exiting ..."
    exit 1
else
    optpartitionfound=1
fi

optpartition="$chosenDrive""2"
info "Checking partition $optpartition swap"
is_partition $optpartition "82"
if [ $foundPartition == 0 ]
then
    swappartitionfound=0
    warning "partition was not created but installation will continue nevertheless."
else
    swappartitionfound=1
fi

optpartition="$chosenDrive""3"
info "Checking partition $optpartition /mnt"
is_partition $optpartition "83"
if [ $foundPartition == 0 ]
then
     mntpartitionfound=0
    warning "partition was not created but installation will continue nevertheless."
else
    mntpartitionfound=1
fi

# start formatting drive here.
# umount all volumes before proceeding
for mount in `blkid | cut -d":" -f1`
do
    info "unmounting $mount ..."
    umount $mount
done

# format sda1 as ext3 /opt
info "Formatting $chosenDrive""1"
mkfs.ext3 "$chosenDrive""1"
info "Format completed"
echo ""
info "Setting the partition label Entware"
tune2fs -L Entware $chosenDrive"1"
info "Label set"

# format sda2 as swap
if [ $swappartitionfound == 1 ]
then
    info "Formatting $chosenDrive""2"
    mkswap "$chosenDrive""2"
    info "Format completed"
    echo ""
fi

# format sda3 as ext3 /mnt
if [ $mntpartitionfound == 1 ]
then
    info "Formatting $chosenDrive""3"
    mkfs.ext3 "$chosenDrive""3"
    info "Format completed"
    echo ""
    info "Setting partition label Data"
    tune2fs -L Data $chosenDrive"3"
    info "Label set"
fi


# When partitions have been formatted, call prepare-oleg-entware script
cd /tmp
wget --no-check-certificate https://github.com/abhinavseewoosungkur/scripts/blob/develop/prepare-oleg-entware.sh
# wget http://entware-test.googlecode.com/files/prepare-oleg-entware.sh
sh ./prepare-oleg-entware.sh

cd /opt
wget http://wl500g-repo.googlecode.com/svn/ipkg/entware_install.sh
sh ./entware_install.sh

#### References ####
# http://superuser.com/questions/332252/creating-and-formating-a-partition-using-a-bash-script
# http://www.tldp.org/HOWTO/Partition/fdisk_partitioning.html
# http://www.bashguru.com/2010/01/shell-colors-colorizing-shell-scripts.html
# http://www.cyberciti.biz/faq/linux-partition-howto-set-labels/
