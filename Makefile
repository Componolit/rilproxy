all::
	ndk-build
	adb push obj/local/arm64-v8a/*rilproxy* /data/local/tmp/
	genisoimage -JR -o deploy.iso obj/local/x86_64/*rilproxy*

clean:
	rm -rf obj libs
