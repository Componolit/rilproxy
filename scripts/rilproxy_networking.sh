#!/system/bin/sh

INTERFACE=$1
IP_LOCAL=$2

echo "Setting up interface"
ip link set up dev ${INTERFACE}
ip address add ${IP_LOCAL} dev ${INTERFACE}
ip rule add from all lookup main pref 99

