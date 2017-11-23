all::
	ndk-build
	genisoimage -JR -o deploy.iso obj/local/x86_64/*rilproxy*
	adb push obj/local/arm64-v8a/*rilproxy* /data/local/tmp/

clean:
	rm -rf obj libs
