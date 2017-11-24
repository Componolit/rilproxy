#!/system/bin/sh

INTERFACE=$1
IP_LOCAL=$2
IP_REMOTE=$3
PORT_REMOTE=$4

echo "Setting up interface"
ip link set up dev ${INTERFACE}
ip address add ${IP_LOCAL} dev ${INTERFACE}
ip rule add from all lookup main pref 99

echo "Starting rilproxy server"
/system/bin/rilproxy_server /dev/socket/rild ${IP_REMOTE} ${PORT_REMOTE}
