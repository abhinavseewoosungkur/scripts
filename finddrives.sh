#!/bin/sh
# function declarations
warning() {
    echo -e "\033[33m$1\033[0m"
}

error() {
    echo -e "\033[31m$1\033[0m"
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
    error "Error: no connected drives found. Check if your USB drive has been connected" 
    error "Error: and check your USB drive\'s status LED. If an external hard disk is used," 
    error "Error: check if the router is providing enough power. Reboot the router if" 
    error "Error: the drive detection still fails."
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
# echo -e "\033[33mLight Colors\033[0m"
# echo -e "\033[33mWarning: You have chosen drive $chosenDrive to be formatted. Press y to continue or n to abort installation.\033[0m"
warning "You have chosen drive $chosenDrive to be formatted. Press y to continue or n to abort installation."
read userConfirmation
if [ $userConfirmation == "n" ]
then
    echo Info: Exiting ...
    exit 0
fi


# start formatting drive here.
