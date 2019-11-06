# installs gl libraries on device
SRC_DIR=./out/target/product/odroidxu3/system/lib
DEST_DIR=/system/lib
ADB=adb

if [ "$#" -eq 1 ]; then
	OPTIONAL_ANDROID_ID="-s $1"
fi

$ADB $OPTIONAL_ANDROID_ID root
$ADB $OPTIONAL_ANDROID_ID shell mount -o rw,remount /dev/block/mmcblk0p2 /system
$ADB $OPTIONAL_ANDROID_ID shell chmod 777 /system/lib
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/libGLESv1_CM.so $DEST_DIR
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/libGLESv2.so $DEST_DIR
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/libEGL.so $DEST_DIR
#$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/libGLLogger.so $DEST_DIR
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/libGLES_trace.so $DEST_DIR
#$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/libGamePM.so $DEST_DIR
#$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/libsurfaceflinger.so $DEST_DIR
# system needs to be rebooted to load the new lib
$ADB $OPTIONAL_ANDROID_ID shell reboot
