VERBOSE ?= @
ABI ?= armeabi-v7a
# ABI = arm64-v8a

CFLAGS = -Werror -Wall -Wextra -Isrc
LDFLAGS = -fPIC
vpath %.c src

DUMMY := $(shell mkdir -p obj)

ISO_FILES=\
	scripts/install.sh \
	scripts/rilproxy_server.rc \
	scripts/rilproxy_networking.sh \

all::
	@echo Chose \"device\", \"vm32\", \"vm64\", \"swbridge\" or \"build\" target.
	@false

build::
	$(VERBOSE)ndk-build

vm32:: build
	$(VERBOSE)genisoimage -JR -o deploy.iso ${ISO_FILES} obj/local/x86/rilproxy_server

vm64:: build
	$(VERBOSE)genisoimage -JR -o deploy.iso ${ISO_FILES} obj/local/x86_64/rilproxy_server

device:: build
	$(VERBOSE)adb root
	$(VERBOSE)adb shell setprop persist.sys.usb.config rndis,adb
	$(VERBOSE)adb remount /system
	$(VERBOSE)adb push obj/local/$(ABI)/rilproxy_client /system/bin/
	$(VERBOSE)adb push scripts/rilproxy_client.sh /system/bin/
	$(VERBOSE)adb shell chmod 755 /system/bin/rilproxy_client.sh
	$(VERBOSE)adb push scripts/rilproxy_client.rc /system/etc/init/
	$(VERBOSE)adb shell chmod 644 /system/etc/init/rilproxy_client.rc
	$(VERBOSE)adb reboot

run:: build
	$(VERBOSE)adb shell su -c setprop persist.sys.usb.config rndis,adb && sleep 2
	$(VERBOSE)adb shell su -c mount -o remount,rw /system
	$(VERBOSE)adb push obj/local/$(ABI)/rilproxy_client /data/local/tmp/
	$(VERBOSE)adb push scripts/rilproxy_client.sh /data/local/tmp/
	$(VERBOSE)adb shell su -c sh /data/local/tmp/rilproxy_client.sh rndis0
	$(VERBOSE)adb shell su -c stop zygote
	$(VERBOSE)adb shell su -c /system/bin/rilproxy_client /dev/socket/rild 192.168.37.254 18912

swbridge: obj/swbridge.o obj/shared.o
	$(CC) $(LDFLAGS) -o $@ $^
	sudo setcap cap_net_raw+ep $@

obj/%.o: src/%.c
	$(CC) $(CFLAGS) -o $@ -c $^

clean:
	rm -rf obj libs deploy.iso
