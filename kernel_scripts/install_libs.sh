# installs driver libraries on device
DEST_DIR=/system/lib/modules
SRC_DIR=./kernel/samsung/exynos5422
ADB=adb

if [ "$#" -eq 1 ]; then
	OPTIONAL_ANDROID_ID="$1"
fi

$ADB $OPTIONAL_ANDROID_ID root
$ADB $OPTIONAL_ANDROID_ID shell mount -o rw,remount /system
$ADB $OPTIONAL_ANDROID_ID shell chmod 777 /system/lib
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/sound/usb/snd-usbmidi-lib.ko $DEST_DIR
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/sound/usb/snd-usb-audio.ko $DEST_DIR
# activates ethernet
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/drivers/net/usb/smsc95xx.ko $DEST_DIR
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/drivers/net/usb/usbnet.ko $DEST_DIR
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/drivers/net/usb/r8152.ko $DEST_DIR
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/drivers/net/usb/cdc_ether.ko $DEST_DIR
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/drivers/net/usb/ax88179_178a.ko $DEST_DIR
$ADB $OPTIONAL_ANDROID_ID push $SRC_DIR/drivers/net/wireless/rtl8192cu/8192cu.ko $DEST_DIR
