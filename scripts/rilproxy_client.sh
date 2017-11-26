#!/system/bin/sh

log "rilproxy networking starting."
ip link set up dev $1
ip address add 192.168.37.1/24 dev $1
ip rule add from all lookup main pref 99
log "rilproxy networking done."

