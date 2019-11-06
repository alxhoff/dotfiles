# installs driver libraries on device
DEST_DIR=/mnt/sdcard/
SRC_DIR=./rcs_modified
ADB=adb

if [ "$#" -eq 1 ]; then
	OPTIONAL_ANDROID_ID="$1"
fi

$ADB $OPTIONAL_ANDROID_ID root
$ADB $OPTIONAL_ANDROID_ID shell mount -o rw,remount /system
$ADB $OPTIONAL_ANDROID_ID shell chmod 777 /system/lib
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/boot.ini $DEST_DIR

