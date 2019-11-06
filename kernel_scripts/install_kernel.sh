#!/bin/sh

while [ "$1" != "" ]; do
    case $1 in
		-s | --device)  		shift
								ANDROID_DEVICE="-s $1"
								;;
		-b | --build-kernel)	BUILD=1
								;;
        * )  					;;
    esac
    shift
done

if [ ! -z $BUILD ]; then
	./build_rcs.sh odroidxu3 kernel
fi

./install_libs.sh "$ANDROID_DEVICE"

adb $ANDROID_DEVICE reboot fastboot

fastboot flash kernel ~/Work/Optigame/android_builds/odroid_4.4.4/kernel/samsung/exynos5422/arch/arm/boot/zImage-dtb

fastboot reboot
