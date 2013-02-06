#!/bin/sh

echo Info: Checking for a partition appropriate for entware...

if [ -e "/dev/discs/disca/part1" ]
  then
    echo Info: Found partition
    echo Info: Writing mount point for /dev/discs/disca/part1 in fstab
    echo "#device                 Mountpoint      FStype  Options         Dump    Pass#" >> /etc/fstab
    echo "/dev/discs/disca/part1  /opt            ext3    rw,noatime      1       1" >> /etc/fstab
  else
    echo Warning: Partition not found for entware installation, exiting...
    exit 1
fi

echo Info: Checking for a partition appropriate for data ...
if [ -e "/dev/discs/disca/part3" ]
    then
    echo Info: Found data partition
    echo Info: Writing mount point for /dev/discs/disca/part3 in fstab
    echo "/dev/discs/disca/part3  /mnt            ext3    rw,noatime      1       1" >> /etc/fstab
else
    echo Warning: No data partition found
fi

echo Info: Checking for a suitable swap partition...
if [ -e "/dev/discs/disca/part2" ]
    then
    echo Info: Found swap partition
    echo Info: Writing mount point for /dev/discs/disca/part2 in fstab
    echo "/dev/discs/disca/part2  none            swap    sw              0       0">> /etc/fstab
    else
    echo Info: No swap partition found
fi


echo Info: Making fstab persitent in flashfs ...
echo "/etc/fstab" >> /usr/local/.files
flashfs save && flashfs commit && flashfs enable

echo Info: Configuring startup and shutdown scripts...
mkdir -p /usr/local/sbin/
touch /usr/local/sbin/post-mount
touch /usr/local/sbin/pre-shutdown
chmod +x /usr/local/sbin/*

echo Info: saving in flashfs ...
flashfs save && flashfs commit && flashfs enable

echo Info: Configuring post-mount script ...
echo "#! /bin/sh" >> /usr/local/sbin/post-mount
echo "/opt/etc/init.d/rc.unslung start" >> /usr/local/sbin/post-mount

echo Info: Configuring pre-shutdown script
echo "#! /bin/sh" >> /usr/local/sbin/pre-shutdown
echo ""  >> /usr/local/sbin/pre-shutdown
echo "/opt/etc/init.d/rc.unslung stop" >> /usr/local/sbin/pre-shutdown
echo ""  >> /usr/local/sbin/pre-shutdown
echo "sleep 10s" >> /usr/local/sbin/pre-shutdown
echo ""  >> /usr/local/sbin/pre-shutdown
echo "for i in `cat /proc/mounts | awk '/ext3/{print($1)}'` ; do"  >> /usr/local/sbin/pre-shutdown
echo "  mount -oremount,ro $i" >> /usr/local/sbin/pre-shutdown
echo "done" >> /usr/local/sbin/pre-shutdown
echo "" >> /usr/local/sbin/pre-shutdown
echo "swapoff -a" >> /usr/local/sbin/pre-shutdown
echo ""  >> /usr/local/sbin/pre-shutdown
echo "sleep 1s"  >> /usr/local/sbin/pre-shutdown

echo Info: Making flashfs persistent
flashfs save && flashfs commit && flashfs enable

echo Info: Your router will now reboot ...
sleep 3s
reboot
