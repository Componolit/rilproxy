all::
	ndk-build
	adb push obj/local/arm64-v8a/*rilproxy* /data/local/tmp/

clean:
	rm -rf obj libs
