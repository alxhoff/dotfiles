#!/bin/bash
echo "Building ath9k modules"
KERNEL_SRC_DIR="$HOME/ubuntu-trusty"
MODULE_DIR=/lib/modules/$(uname -r)
ATH_MODULE_DIR=$MODULE_DIR/kernel/drivers/net/wireless/ath/ath9k
ATH_BUILD_DIR="$KERNEL_SRC_DIR/drivers/net/wireless/ath/ath9k"
COMMAND="make -C $MODULE_DIR/build M=$ATH_BUILD_DIR modules"
echo $COMMAND
eval $COMMAND

BUILT_MODULES=$(ls $ATH_BUILD_DIR | grep *.ko)
echo "Built modules $BUILT_MODULES"

echo "Copying modules to $ATH_MODULE_DIR"
sudo cp $ATH_BUILD_DIR/*.ko $ATH_MODULE_DIR/ 

echo "Modprobe"

for file in $ATH_MODULE_DIR/*.ko
do
	MODULE_NAME=$(basename -- "$file")
	MODULE_NAME="${MODULE_NAME%.*}"
	COMMAND="sudo modprobe $MODULE_NAME"
	echo $COMMAND
	eval $COMMAND
done

echo "Depmod"
sudo depmod

echo "DONE - Please reboot"
