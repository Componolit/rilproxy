VERBOSE ?= @
ABI ?= armeabi-v7a
# ABI = arm64-v8a

ISO_FILES=\
	scripts/install.sh \
	scripts/rilproxy_server.rc \
	scripts/rilproxy_server.sh \

all::
	@echo Chose "device", "vm32", "vm64" or "build" target.
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

clean:
	rm -rf obj libs deploy.iso
