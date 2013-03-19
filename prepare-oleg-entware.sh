#!/bin/sh

# Automates the configuration of the Oleg firmware to automount the /opt , /mnt and swap partitions. 
# The script also configures services to be started and stopped at router boot and shutdown. 

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


echo Info: Checking for a partition appropriate for Entware ...

if [ `blkid | grep Entware | cut -d"\"" -f2` == "Entware" ]
  then
    # clear fstab before proceeding
    clear_fstab
    echo Info: Found Entware partition on `blkid | grep Entware | cut -d":" -f1`
    echo Info: Writing mount point for `blkid | grep Entware | cut -d":" -f1` in fstab
    echo "#device                 Mountpoint      FStype  Options         Dump    Pass#" >> /etc/fstab
    echo "UUID="`blkid | grep Entware | cut -d"\"" -f4`"  /opt      ext3    rw,noatime 1       1" >> /etc/fstab
else
    error "Partition not found for entware installation, exiting..."
    exit 1
fi

echo ""

echo Info: Checking for a partition appropriate for Data ...

if [ `blkid | grep Data | cut -d"\"" -f2` == "Data" ]
  then
    echo Info: Found Data partition on `blkid | grep Data | cut -d":" -f1`
    echo Info: Writing mount point for `blkid | grep Data | cut -d":" -f1` in fstab
    echo "UUID="`blkid | grep Data | cut -d"\"" -f4`"  /mnt      ext3    rw,noatime 1       1" >> /etc/fstab
else
    warning "Partition not found for Data installation. Installation will nevertheless continue."
fi


echo Info: Checking for a suitable swap partition...
if [ -e `fdisk -l | grep swap | awk '{print $1}'` ]
then
    echo Info: Found swap partition `fdisk -l | grep swap | awk '{print $1}'`
    echo Info: Writing mount point for `fdisk -l | grep swap | awk '{print $1}'` in fstab
    echo "`fdisk -l | grep swap | awk '{print $1}'`  none            swap    sw              0       0" >> /etc/fstab
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

# install entware
# call entware script here or in main script
# echo Info: Your router will now reboot ...
# sleep 3s
# reboot


#### References ####
# http://www.cyberciti.biz/faq/linux-finding-using-uuids-to-update-fstab/
