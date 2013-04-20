
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

# escapes slashes
# arg1 The string to escape
escapeSlash() {
    echo $1 | sed 's/\//\\\//g'
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

info "Checking presence of Entware ..."
if [ "`which opkg`" == "" ] 
then
    warning "Entware not installed."
    info "Proceeding with Entware installation ..."
    wget http://wl500g-repo.googlecode.com/svn/ipkg/entware_install.sh
    sh entware_install.sh
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

# scgi configuration
echo "scgi_port = 127.0.0.1:5000" >> /opt/etc/rtorrent.conf

info "rtorrent installed."
