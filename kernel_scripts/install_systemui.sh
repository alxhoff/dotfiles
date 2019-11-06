# installs new systemui to device
SRC_DIR_SYSTEMUI=./out/target/product/odroidxu3/system/priv-app
SRC_DIR_LIB=./out/target/product/odroidxu3/system/lib
DEST_DIR_SYSTEMUI=/system/priv-app
DEST_DIR_LIB=/system/lib
ADB=adb

if [ "$#" -eq 1 ]; then
	OPTIONAL_ANDROID_ID="-s $1"
fi

$ADB $OPTIONAL_ANDROID_ID root
$ADB $OPTIONAL_ANDROID_ID shell mount -o rw,remount /dev/block/mmcblk0p2 /system
$ADB $OPTIONAL_ANDROID_ID shell chmod 777 /system/priv-app
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR_SYSTEMUI/SystemUI.apk $DEST_DIR_SYSTEMUI
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR_LIB/libinfo_jni.so $DEST_DIR_LIB

