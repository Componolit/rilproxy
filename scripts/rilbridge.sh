#!/bin/bash -eu
#
# This script creates a bridge between two interfaces and configures it to be
# used with rilproxy. Use a USB Ethernet (ASIX) on the VM side and the regular
# RNDIS device towards the phone side
#

if [ $# -lt 2 ];
then
    echo "$0: <BP interface> <AP interface>"
    exit 1
fi

set -o pipefail

RILBR=rilbr

BPIF=$1
APIF=$2

echo "Setting up bridge: ${BPIF} (BP) <==> ${APIF} (AP)"

sudo ip link set up ${BPIF}
sudo ip link set up ${APIF}

# RILBR may not exist
set +e
sudo ip link set down ${RILBR}
sudo brctl delbr ${RILBR}
set -e

sudo brctl addbr ${RILBR}
sudo brctl stp ${RILBR} off
sudo brctl setageing ${RILBR} 9999

sudo brctl addif ${RILBR} ${BPIF}
sudo brctl addif ${RILBR} ${APIF}

sudo ip link set up ${RILBR}
sudo brctl show ${RILBR}
