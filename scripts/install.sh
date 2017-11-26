#!/system/bin/sh

set -eu

SOURCE_DIR=/mnt/media_rw/CDROM

echo "Mounting /system rw"
mount -o rw,remount /system

echo "Copying files"
cp -v ${SOURCE_DIR}/rilproxy_server /system/bin/rilproxy_server
cp -v ${SOURCE_DIR}/rilproxy_server.sh /system/bin/rilproxy_server.sh
cp -v ${SOURCE_DIR}/rilproxy_server.rc /system/etc/init/rilproxy_server.rc

echo "Fixing permissions"
chmod 755 /system/bin/rilproxy_server.sh
chmod 644 /system/etc/init/rilproxy_server.rc

echo "Backing up RIL rc file"

if [ -e "/system/etc/init/rild.rc" ];
then
    mv /system/etc/init/rild.rc /system/etc/init/rild.rc.bak
fi

# Set noril
sed -i -e 's/ro.radio.noril yes/ro.radio.noril no/' /system/etc/init.sh
