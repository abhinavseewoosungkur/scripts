# Author: Abhinav Seewoosungkur


# Definitions
rtorrentrc=/opt/etc/rtorrent.conf
lighttpdrc=/opt/etc/lighttpd/lighttpd.conf
rtorrentservice=/opt/etc/init.d/S99rtorrent
rtorrentreviver=/opt/etc/rtorrentreviver

# Text formatters
# Yellow
warning() {
    echo -e "\033[33mWarning: $1\033[0m"
}

# Red
error() {
    echo -e "\033[31mError: $1\033[0m"
}

# Green
success() {
    echo -e "\033[32mSuccess: $1\033[0m"
}

# Cyan
info() {
    echo -e "\033[36mInfo: $1\033[0m"
}

# Magenta
# arg1 The string to format
# arg2 Text Modifier
prompt() {
    echo -e "\033[$2;35mPrompt: $1\033[0m"
}

# escapes slashes
# arg1 The string to escape
escapeSlash() {
    echo $1 | sed 's/\//\\\//g'
}

# Check if Entware is present on the router. 
# If not, prompt for installation and update the repo.
checkEntware() {
    info "Checking presence of Entware ..."
    if [ "`which opkg`" == "" ] 
    then
	warning "Entware not installed."
	echo -n `prompt "Entware is needed to install rutorrent / rtorrent. Proceed with Entware installation? [ y ]"`
	read installentware
	if [[ "$installentware" == "" ]]
	then
	    wget -O - http://wl500g-repo.googlecode.com/svn/ipkg/entware_install.sh | sh
	else
	    exit 1
	fi
    else
	info "Great! Entware found"
    fi

    info "Updating the Entware repository ..."
    opkg update
}

# configures the rtorrent rc file
# arg1 The key
# arg2 The value
setRtorrentConfig() {
    escaped=`escapeSlash $2`
    sed -i "s/.*$1 =.*/$1 = $escaped/g" /opt/etc/rtorrent.conf
}

# configures the lighttpd rc file
# arg1 The key
# arg2 The value
setLighttpdConfig() {
    escaped=`escapeSlash $2`
    sed -i "s/#$1.*/$1 = $escaped/g" /opt/etc/lighttpd/lighttpd.conf
}

# add line after block of code
# arg1 block start expression
# arg2 Line to add
# arg3 File to process
addLineAfterBlock() {
    sed -e "/$1/{:a;n;/^$/!ba;i\$2' -e '}" -i $3
}

# uncomment shell configuration
# arg1 The configuration regexp
# arg2 the filename
uncomment() {
    sed "/${1}/ s/# *//" -i $2
}

# comment shell configuration
# arg1 The configuration
# arg2 the filename

comment() {
    sed "/${1}/ s/^/# /" -i $2 
}

# uncomment PHP configuration
# arg1 The configuration regexp
# arg2 the filename
uncommentPHP() {
    sed "/${1}/ s/\/\/ *//" -i $2
}

# comment PHP configuration
# arg1 The configuration
# arg2 the filename

commentPHP() {
    sed "/${1}/ s/^/\/\/ /" -i $2 
}

# install all rutorrent plugins available when script is executed
installrutorrentplugins() {
    for plugin in `opkg list | grep rutorrent-plugin | awk '{print $1}'`
    do
	opkg install $plugin
    done
}

# fix the rutorrent diskspace plugin by changing
# the specified rtorrent work directory
fixdiskpaceplugin() {
if [ -f /opt/share/www/rutorrent/plugins/diskspace/action.php ]
then
    escaped=`escapeSlash "$work"`
    sed -i "s/\$topDirectory/\"$escaped\"/g" /opt/share/www/rutorrent/plugins/diskspace/action.php
fi
/opt/etc/init.d/S80lighttpd restart
}

# Check for the presence of Entware before proceeding
checkEntware

# read the rtorrent work directory
echo -n `prompt "Work directory for rtorrent [ /mnt/rtorrent/work ]: "` 
read work
if [[ "$work" == "" ]]
then 
    work=/mnt/rtorrent/work
fi

# # read the rtorrent session directory
# echo -n `prompt "Session directory for rtorrent [ /mnt/rtorrent/session ]: "`
# read session
# if [[ "$session" == "" ]] 
# then
#     session=/mnt/rtorrent/session
# fi
session=/opt/etc/rtorrent/session

# read the rtorrent port range
echo -n `prompt "Port range for rtorrent [ 51777-51780 ]: "`
read port_range
if [[ "$port_range" == "" ]]
then
    port_range=51777-51780
fi

# read the rtorrent DHT port
echo -n `prompt "DHT Port for rtorrent [ 6881 ]: "`
read dhtport
if [[ "$dhtport" == "" ]]
then
    dhtport=6881
fi

# read lighttpd port
echo -n `prompt "Port for lighttpd [ 8010 ]: "`
read lighttpd_port
if [[ "$lighttpd_port" == "" ]]
then
    lighttpd_port=8010
fi

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
setRtorrentConfig dht_port $dhtport
uncomment dht $rtorrentrc
uncomment min_peers $rtorrentrc
uncomment max_peers $rtorrentrc
uncomment min_peers_seed $rtorrentrc
uncomment max_peers_seed $rtorrentrc
uncomment max_uploads $rtorrentrc
uncomment download_rate $rtorrentrc
uncomment upload_rate $rtorrentrc
uncomment check_hash $rtorrentrc
uncomment use_udp_trackers $rtorrentrc
uncomment peer_exchange $rtorrentrc
uncomment max_memory_usage $rtorrentrc

# scgi configuration.
# echo "scgi_port = 127.0.0.1:5000" >> /opt/etc/rtorrent.conf
echo "scgi_local = /opt/var/rpc.socket" >> /opt/etc/rtorrent.conf
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
setLighttpdConfig server.port $lighttpd_port

info "Adding scgi.server config"
echo "scgi.server = (" >> $lighttpdrc
echo "        \"/RPC2\" =>" >> $lighttpdrc
echo "               ( \"127.0.0.1\" =>"  >> $lighttpdrc
echo "                        (" >> $lighttpdrc
# echo "                                \"host\" => \"127.0.0.1\"",  >> $lighttpdrc
# echo "                                \"port\" => 5000," >> $lighttpdrc
echo "                                \"socket\" => \"/opt/var/rpc.socket\"," >> $lighttpdrc
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

# info "Fixing php link ..."
# cd /opt/bin
# ln -s php-cli php



info "Restarting the lighttpd server ..."
/opt/etc/init.d/S80lighttpd restart

info "Installing rutorrent dependencies ..."
opkg install php5-mod-json curl

info "Now ready to install rutorrent ..."
opkg install rutorrent

# Specify php path in rutorrent config
sed -i "s/\"php\".*''/\"php\"  => '\/opt\/bin\/php-cli'/g" /opt/share/www/rutorrent/conf/config.php

# info "Use port instead of socket for rutorrent"
# commentPHP "$scgi_port = 0" /opt/share/www/rutorrent/conf/config.php
# commentPHP "$scgi_host = \"unix" /opt/share/www/rutorrent/conf/config.php

# uncommentPHP "$scgi_port = 5000" /opt/share/www/rutorrent/conf/config.php
# uncommentPHP "$scgi_host = \"127" /opt/share/www/rutorrent/conf/config.php


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

info "Restarting rtorrent ..."
/opt/etc/init.d/S99rtorrent restart

info "Restarting lighttpd ..."
/opt/etc/init.d/S80lighttpd restart

info "Installing rtorrent WatchDog ..."
info "Deploying the reviver script ..."
echo "#!/bin/sh" >> $rtorrentreviver
echo "if [ \`/opt/etc/init.d/S99rtorrent check | awk '{print \$5}'\` = \"dead.\"  ] ; then" >> $rtorrentreviver
echo "        if [ -e  $session/rtorrent.lock ] ; then" >> $rtorrentreviver
echo "                rm  $session/rtorrent.lock" >> $rtorrentreviver
echo "        fi" >> $rtorrentreviver
echo "        /opt/etc/init.d/S99rtorrent start" >> $rtorrentreviver
echo "        echo \"restarted failed rtorrent on \" \`date\` >> /opt/var/log/rtorrent.log" >> $rtorrentreviver
echo "fi" >> $rtorrentreviver

info "Making script executable ..."
chmod +x $rtorrentreviver

info "Installing cron ..."
opkg install cron
mv /opt/etc/rtorrentreviver /opt/etc/cron.1min/

info "Fixing cron username"
# check if id exists
if [ "`which id`" == ""  ]
then 
    opkg install coreutils-id
fi
username=`id -u -n`
sed -i "s/root \//$username \//g" /opt/etc/crontab 

info "Restarting the cron service ..."
/opt/etc/init.d/S10cron restart


info "rtorrent / rutorrent ready to download. "
prompt "Navigate to http://routerip:$lighttpd_port/rutorrent to verify installation."
prompt "Press Enter to continue" 5
read continue

success "Congratulations! You now have an awesome torrent server on your router."
prompt "Ready to supercharge rutorrent with all the plugins? [ y ] :"
read installpluginsprompt
if [[ "$installpluginsprompt" == "" ]]
then
    installrutorrentplugins
    fixdiskpaceplugin
fi


#### References ####
# http://www.unix.com/shell-programming-scripting/158109-uncomment-comment-one-specific-line-config-file.html
