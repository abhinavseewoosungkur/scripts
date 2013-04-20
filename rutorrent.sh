# Definitions
lighttpdrc=/opt/etc/lighttpd/lighttpd.conf
rtorrentservice=/opt/etc/init.d/S99rtorrent

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
    echo -e "\033[34mInfo: $1\033[0m"
}

# configures the rtorrent rc file
# arg1 The key
# arg2 The value
setRtorrentConfig() {
    escaped=`escapeSlash $2`
    sed -i "s/#$1.*/$1 = $escaped/g" /opt/etc/rtorrent.conf
}

# configures the lighttpd rc file
# arg1 The key
# arg2 The value
setLighttpdConfig() {
    escaped=`escapeSlash $2`
    sed -i "s/#$1.*/$1 = $escaped/g" /opt/etc/lighttpd/lighttpd.conf
}

# escapes slashes
# arg1 The string to escape
escapeSlash() {
    echo $1 | sed 's/\//\\\//g'
}

# add line after block of code
# arg1 block start expression
# arg2 Line to add
# arg3 File to process
addLineAfterBlock() {
    sed -e "/$1/{:a;n;/^$/!ba;i\$2' -e '}" -i $3
}

# uncomment configuration
# arg1 The configuration regexp
# arg2 the filename
uncomment() {
    sed "/${1}/ s/# *//" -i $2
}

# comment configuration
# arg1 The configuration
# arg2 the filename

comment() {
    sed "/${1}/ s/^/# /" -i $2 
}

# uncomment configuration
# arg1 The configuration regexp
# arg2 the filename
uncommentPHP() {
    sed "/${1}/ s/\/\/ *//" -i $2
}

# comment configuration
# arg1 The configuration
# arg2 the filename

commentPHP() {
    sed "/${1}/ s/^/\/\/ /" -i $2 
}


# read the rtorrent work directory
echo -n `info "Enter the work directory for rtorrent or press Enter to use /mnt/rtorrent/work: "` 
read work
if [ -n $work ]
then 
    work=/mnt/rtorrent/work
fi

# read the rtorrent session directory
echo -n `info "Enter the session directory for rtorrent or press Enter to use /mnt/rtorrent/session: "`
read session
if [ -n $session ] 
then
    session=/mnt/rtorrent/session
fi

# read the rtorrent port range
echo -n `info "Enter the port range for rtorrent or press Enter to use 51777-51780: "`
read port_range
if [ -n $port_range ]
then
    port_range=51777-51780
fi

# read lighttpd port
echo -n `info "Enter the port for lighttpd or press Enter to use 8010: "`
read lighttpd_port
if [ -n $lighttpd_port ]
then
    lighttpd_port=8010
fi


info "Checking presence of Entware ..."
if [ "`which opkg`" == "" ] 
then
    warning "Entware not installed."
    info "Proceeding with Entware installation ..."
    wget -O - http://wl500g-repo.googlecode.com/svn/ipkg/entware_install.sh | sh
else
    info "Great! Entware found"
fi

info "Updating the Entware repository ..."
opkg update

# enable this after script dev is finished
# if [ "`which rtorrent`" !=  "" ]
# then
#     error "rtorrent is present. It is recommended to run this script on a" 
#     error "freshly installed Entware. Remove rtorrent, rutorrent, lighttpd"
#     error "and all their configuration files before procedding."
#     exit 1
# fi

info "Installing rtorrent and its dependencies ..."
opkg install rtorrent screen dtach

info "Making sure /opt/etc exists before proceeding ..."
[ -d /opt/etc ] || mkdir -p /opt/etc

info "Downloading the rtorrent configuration file ..."
cd /opt/etc
wget http://libtorrent.rakshasa.no/export/1303/trunk/rtorrent/doc/rtorrent.rc
mv rtorrent.rc rtorrent.conf

info "Making directories for rtorrent ..."
[ -d $work ] || mkdir -p $work
[ -d $session ] || mkdir -p $session

info "Proceeding with rtorrent configuration ..."

setRtorrentConfig directory $work
setRtorrentConfig session $session
setRtorrentConfig port_range $port_range

# scgi configuration.
echo "scgi_port = 127.0.0.1:5000" >> /opt/etc/rtorrent.conf

info "rtorrent installed."

info "Now installing lighttpd ..."
opkg install lighttpd lighttpd-mod-fastcgi lighttpd-mod-scgi

# Add mod_scgi and mod_fastcgi modules
# Look for the server.modules block of code and insert the 2 modules after
# it
info "Adding server modules ..."
sed -e '/#server.modules = (/{:a;n;/^$/!ba;i\server.modules += ( "mod_scgi" )' -e '}' -i /opt/etc/lighttpd/lighttpd.conf
sed -e '/#server.modules = (/{:a;n;/^$/!ba;i\server.modules += ( "mod_fastcgi" )' -e '}' -i /opt/etc/lighttpd/lighttpd.conf

info "Enabling logging for lighttpd ..."
uncomment server.errorlog $lighttpdrc

info "Setting server.port to $lighttpd_port"
setLighttpdConfig server.port 8010

info "Adding scgi.server config"
echo "scgi.server = (" >> $lighttpdrc
echo "        \"/RPC2\" =>" >> $lighttpdrc
echo "               ( \"127.0.0.1\" =>"  >> $lighttpdrc
echo "                        (" >> $lighttpdrc
echo "                                \"host\" => \"127.0.0.1\"",  >> $lighttpdrc
echo "                                \"port\" => 5000," >> $lighttpdrc
echo "                                \"check-local\" => \"disable\"" >> $lighttpdrc
echo "                        )" >> $lighttpdrc
echo "                )" >> $lighttpdrc
echo "        )" >> $lighttpdrc

info "Adding fastcfgi.server config"
echo "fastcgi.server             = ( \".php\" =>" >> $lighttpdrc
echo "                               ( \"localhost\" =>" >> $lighttpdrc
echo "                                 (" >> $lighttpdrc
echo "                                   \"socket\" => \"/tmp/php-fastcgi.socket\"," >> $lighttpdrc
echo "                                  \"bin-path\" => \"/opt/bin/php-fcgi\"" >> $lighttpdrc
echo "                                 )" >> $lighttpdrc
echo "                               )" >> $lighttpdrc
echo "                            )" >> $lighttpdrc


info "Installing php5-cli and php5-fastcgi"
opkg install php5-cli
opkg install php5-fastcgi

info "Fixing php link ..."
cd /opt/bin
ln -s php-cli php

info "Restarting the lighttpd server ..."
/opt/etc/init.d/S80lighttpd restart

info "Installing more rutorrent dependencies ..."
opkg install php5-mod-json curl

info "Now ready to install rutorrent ..."
opkg install rutorrent


info "Use port instead of socket for rutorrent"
commentPHP "$scgi_port = 0" /opt/share/www/rutorrent/conf/config.php
commentPHP "$scgi_host = \"unix" /opt/share/www/rutorrent/conf/config.php

uncommentPHP "$scgi_port = 5000" /opt/share/www/rutorrent/conf/config.php
uncommentPHP "$scgi_host = \"127" /opt/share/www/rutorrent/conf/config.php


info "Deploying the rtorrent service script ..."
info "Removing script if existent"

if [ -f $rtorrentservice ]
then
    info "Removing script"
    rm $rtorrentservice
fi
info "Deploying ..."
echo "#!/bin/sh" >> $rtorrentservice
echo "ENABLED=yes" >> $rtorrentservice
echo "PROCS=screen" >> $rtorrentservice
echo "ARGS=\"-dm -S rtorrent rtorrent -n -o import=/opt/etc/rtorrent.conf\"" >> $rtorrentservice
echo "PREARGS=\"\"" >> $rtorrentservice
echo "DESC=$PROCS" >> $rtorrentservice
echo "PATH=/opt/sbin:/opt/bin:/opt/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> $rtorrentservice
echo ". /opt/etc/init.d/rc.func" >> $rtorrentservice

info "Deployment done."

info "Making sript executable ..."
chmod +x $rtorrentservice

info "Starting rtorrent ..."
/opt/etc/init.d/S99rtorrent start

info "Restarting lighttpd ..."
/opt/etc/init.d/S80lighttpd restart

warning "Check your rutorrent before proceeding. Press Enter to continue"
read rutorrentcheck







#### References ####
# http://www.unix.com/shell-programming-scripting/158109-uncomment-comment-one-specific-line-config-file.html
