#!/bin/bash

CPU_JOB_NUM=$(grep processor /proc/cpuinfo | awk '{field=$NF};END{print field+1}')
CLIENT=$(whoami)

ROOT_DIR=$(pwd)

if [ $# -lt 1 ]
then
    echo "Usage: ./build.sh <PRODUCT> [ kernel | platform | all ]"
    exit 0
fi

if [ ! -f device/hardkernel/$1/build-info.sh ]
then
    echo "NO PRODUCT to build!!"
    exit 0
fi

source device/hardkernel/$1/build-info.sh
BUILD_OPTION=$2

if [ "x$OUT_DIR_COMMON_BASE" == "x" ]; then
OUT_DIR="$ROOT_DIR/out/target/product/$PRODUCT_BOARD"
#OUT_HOSTBIN_DIR="$ROOT_DIR/vendor/samsung_slsi/script"
OUT_HOSTBIN_DIR="$ROOT_DIR/out/host/linux-x86/bin"
else
BASE_DIR=$OUT_DIR_COMMON_BASE/`basename $ROOT_DIR`
OUT_DIR="$BASE_DIR/target/product/$PRODUCT_BOARD"
OUT_HOSTBIN_DIR="$BASE_DIR/host/linux-x86/bin"
fi

KERNEL_CROSS_COMPILE_PATH=arm-eabi-
KERNEL_DIR="$ROOT_DIR/kernel/samsung/exynos5422"

function check_exit()
{
    if [ $? != 0 ]
    then
        exit $?
    fi
}

function build_kernel()
{
    echo
    echo '[[[[[[[ Build android kernel ]]]]]]]'
    echo

    START_TIME=`date +%s`
    pushd $KERNEL_DIR
    echo "set defconfig for $PRODUCT_BOARD"
    echo
    make-3.81 ARCH=arm $PRODUCT_BOARD"_defconfig"
    check_exit
    echo "make-3.81 -j$CPU_JOB_NUM ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE_PATH"
    echo
    make-3.81 -j$CPU_JOB_NUM ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE_PATH
    echo "make-3.81 ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE_PATH -C $PWD M=$ROOT_DIR/hardware/wifi/realtek/drivers/8192cu/rtl8xxx_CU"
    make-3.81 ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE_PATH -C $PWD M=$ROOT_DIR/hardware/wifi/realtek/drivers/8192cu/rtl8xxx_CU
    echo "make-3.81 ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE_PATH -C $PWD M=$ROOT_DIR/hardware/wifi/realtek/drivers/rtl8812au"
    make-3.81 ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE_PATH -C $PWD M=$ROOT_DIR/hardware/wifi/realtek/drivers/rtl8812au
    echo "make-3.81 clean -C ../../../hardware/backports ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE_PATH KLIB_BUILD=$PWD"
    make-3.81 clean -C ../../../hardware/backports ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE_PATH KLIB_BUILD=$PWD
    echo "make-3.81 -C ../../../hardware/backports ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE_PATH KLIB_BUILD=$PWD defconfig-odroidxu3"
    make-3.81 -C ../../../hardware/backports ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE_PATH KLIB_BUILD=$PWD defconfig-odroidxu3
    echo "make-3.81 -C ../../../hardware/backports ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE_PATH KLIB_BUILD=$PWD"
    make-3.81 -C ../../../hardware/backports ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE_PATH KLIB_BUILD=$PWD
    check_exit
    END_TIME=`date +%s`

    let "ELAPSED_TIME=$END_TIME-$START_TIME"
    echo "Total compile time is $ELAPSED_TIME seconds"

    popd
}

function build_android()
{
        echo
        echo '[[[[[[[ Build android platform ]]]]]]]'
        echo

        START_TIME=`date +%s`
        echo "source build/envsetup.sh"
        source build/envsetup.sh
        echo
        echo "lunch $PRODUCT_BOARD-eng"
        lunch $PRODUCT_BOARD-eng
        echo
        echo "make-3.81 -j$CPU_JOB_NUM"
        echo
        make-3.81 -j$CPU_JOB_NUM
        check_exit

        END_TIME=`date +%s`
        let "ELAPSED_TIME=$END_TIME-$START_TIME"
        echo "Total compile time is $ELAPSED_TIME seconds"
}

function make-3.81_uboot_img()
{
    pushd $OUT_DIR

    echo
    echo '[[[[[[[ make-3.81 ramdisk image for u-boot ]]]]]]]'
    echo

    mkimage -A arm -O linux -T ramdisk -C none -a 0x40800000 -n "ramdisk" -d ramdisk.img ramdisk-uboot.img
    check_exit

    rm -f ramdisk.img

    echo
    popd
}

function make-3.81_fastboot_img()
{
    echo
    echo '[[[[[[[ make-3.81 additional images for fastboot ]]]]]]]'
    echo

    if [ ! -f $KERNEL_DIR/arch/arm/boot/zImage ]
    then
        echo "No zImage is found at $KERNEL_DIR/arch/arm/boot"
        echo
        return
    fi

    echo 'boot.img ->' $OUT_DIR
    cp $KERNEL_DIR/arch/arm/boot/zImage-dtb $OUT_DIR/zImage-dtb
    $OUT_HOSTBIN_DIR/mkbootimg --kernel $OUT_DIR/zImage-dtb --ramdisk $OUT_DIR/ramdisk.img -o $OUT_DIR/boot.img
    check_exit

    echo 'update.zip ->' $OUT_DIR
    zip -j $OUT_DIR/update.zip $OUT_DIR/android-info.txt $OUT_DIR/boot.img $OUT_DIR/system.img
    check_exit

    echo
}

SYSTEMIMAGE_PARTITION_SIZE=$(grep "BOARD_SYSTEMIMAGE_PARTITION_SIZE " device/hardkernel/odroidxu3/BoardConfig.mk | awk '{field=$NF};END{print field}')

function copy_root_2_system()
{
    echo
    echo '[[[[[[[ copy ramdisk rootfs to system ]]]]]]]'
    echo

    cp $KERNEL_DIR/arch/arm/boot/zImage-dtb $OUT_DIR/zImage-dtb
    mkdir -p $OUT_DIR/system/lib/modules/backports
    find $KERNEL_DIR -name *.ko | xargs -i cp {} $OUT_DIR/system/lib/modules/
    find $ROOT_DIR/hardware/wifi/realtek/drivers -name *.ko | xargs -i cp {} $OUT_DIR/system/lib/modules
    find $ROOT_DIR/hardware/backports -name *.ko | xargs -i cp {} $OUT_DIR/system/lib/modules/backports

    rm -rf $OUT_DIR/system/init
    rm -rf $OUT_DIR/system/sbin/adbd
    rm -rf $OUT_DIR/system/sbin/healthd
    cp -arp $OUT_DIR/root/* $OUT_DIR/system/
    mv $OUT_DIR/system/init $OUT_DIR/system/bin/
    ln -sf /bin/init $OUT_DIR/system/init
    mv $OUT_DIR/system/sbin/adbd $OUT_DIR/system/bin/
    ln -sf /system/bin/adbd $OUT_DIR/system/sbin/adbd
    mv $OUT_DIR/system/sbin/healthd $OUT_DIR/system/bin/
    ln -sf /system/bin/healthd $OUT_DIR/system/sbin/healthd

    echo $SYSTEMIMAGE_PARTITION_SIZE

    find $OUT_DIR/system -name .svn | xargs rm -rf
    $OUT_HOSTBIN_DIR/make-3.81_ext4fs -s -l $SYSTEMIMAGE_PARTITION_SIZE -a system $OUT_DIR/system.img $OUT_DIR/system

    sync
}

function make-3.81_update_zip()
{
    echo
    echo '[[[[[[[ make-3.81 update zip ]]]]]]]'
    echo

    if [ ! -d $OUT_DIR/update ]
    then
        mkdir $OUT_DIR/update
    else
        rm -rf $OUT_DIR/update/*
    fi

    echo '$PRODUCT_BOARD'

    cp $OUT_DIR/zImage-dtb $OUT_DIR/update/
    cp $OUT_DIR/zImage-dtb $OUT_DIR/update/zImage
    cp $OUT_DIR/ramdisk.img $OUT_DIR/update/
    cp $OUT_DIR/system.img $OUT_DIR/update/
    cp $OUT_DIR/userdata.img $OUT_DIR/update/
    cp $OUT_DIR/cache.img $OUT_DIR/update/

    if [ -f $OUT_DIR/update.zip ]
    then
        rm -rf $OUT_DIR/update.zip
        rm -rf $OUT_DIR/update.zip.md5sum
    fi

    echo 'update.zip ->' $OUT_DIR
    pushd $OUT_DIR
    zip -r update.zip update/*
    md5sum update.zip > update.zip.md5sum
    check_exit

    echo
    popd
}


echo
echo '                Build android for '$PRODUCT_BOARD''
echo

export JAVA_HOME=/opt/jdk1.6.0_45/
export PATH=$JAVA_HOME/bin:$PATH

case "$BUILD_OPTION" in
    kernel)
        build_kernel
        ;;
    platform)
        build_android
        copy_root_2_system
        make-3.81_update_zip
        ;;
    all)
        build_kernel
        build_android
        copy_root_2_system
        make-3.81_update_zip
        ;;
    *)
        build_kernel
        build_android
        copy_root_2_system
        make-3.81_update_zip
        ;;
esac

echo ok success !!!

exit 0
