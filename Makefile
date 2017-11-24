ISO_FILES=\
	obj/local/x86_64/rilproxy_server \
	scripts/install.sh \
	scripts/rilproxy.rc \
	scripts/rilproxy.sh \

all::
	ndk-build
	genisoimage -JR -o deploy.iso ${ISO_FILES}
	adb push obj/local/arm64-v8a/*rilproxy* /data/local/tmp/

clean:
	rm -rf obj libs deploy.iso
