#!/bin/sh
# function declarations
warning() {
    echo -e "\033[33mWarning: $1\033[0m"
}

error() {
    echo -e "\033[31mError: $1\033[0m"
}

info() {
    echo -e "Info: $1"
}

# returns the drive size
drive_size() {
    echo `fdisk -l | grep 'Disk $1' | cut -d" " -f3,4 | cut -d"," -f1`
}

createpartition() {
    echo "Creating partition $1 with $2 in disk $3"
}

# clears the partition table
clear_partition_table() {
    echo Clearing the partition table for disk $1
}

# Find connected drives on the router
driveCount=1 # initialize driveCount to 1

echo Info: Looking for connected drives ...

for drive in `fdisk -l | grep Disk | cut -d" " -f2 | cut -d":" -f1` # look for connected drives in router
do
    driveFound="true" # flag as true for script flow condition
    echo "[$driveCount] -->" $drive # show user corresponding number for drive to choose
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
warning "You have chosen drive $chosenDrive to be formatted. Press y to continue or n to abort installation."
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


info "The drive has a capacity of " 
drive_size $chosenDrive
info "Auto partition will now proceed. Leave enough space for swap. A space equivalent to your ram size will be enough for swap."
warning "Write the unit type after the size without spaces. Example: 128M or 4G"
info "How much space would you like to allocate for the swap?"
read swapsize

info "How much space would you like to allocate for the /opt partition?"
read optsize

info "How much space would you like to allocate for the /mnt partition?"
read mntsize

#info $driveSize
# start formatting drive here.

# TODO: Delete all partitions before proceeding

# initialize the partition count

clear_partition_table $chosenDrive

partitionCount=1
for partitionsize in $optsize $swapsize $mntsize
do
    # echo $partition
    createpartition $partitionCount $partitionsize $chosenDrive
    partitionCount=`expr $partitionCount + 1`
    # echo $partitionCount
done
