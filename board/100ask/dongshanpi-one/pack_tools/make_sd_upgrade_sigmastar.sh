#!/bin/bash
#----------------------------------------
# PATH Define
#----------------------------------------

TARGET_DIR=$BINARIES_DIR
AUTO_UPDATE_SCRIPT=$TARGET_DIR/auto_update.txt
TMP_UPGRADE_FILE=TMP_SigmastarUpgradeSD.bin
PADDED_BIN=$TARGET_DIR/padded.bin
PAD_DUMMY_BIN=$TARGET_DIR/dummy_pad
UPGRADE_FILE=$TARGET_DIR/SigmastarUpgradeSD.bin
SCRIPT_FILE=$TARGET_DIR/upgrade_script.txt

upgrade_bin_version=`date +"%m%d%H%M"`

#lunch `print_lunch_menu | grep aosp_$TARGET_DEVICE-userdebug | cut -d. -f1`

#----------------------------------------
# Globe Value Define
#----------------------------------------
SECURE_UPGRADE=0
USB_CRC_CHECK=0
SPILT_SIZE=16384
SCRIPT_SIZE=0x4000 #16KB
PAD_DUMMY_SIZE=10240 #10KB
FILE_CRC_HEADER_SIZE=8 #8Byte
currentImageOffset=$SCRIPT_SIZE
MAGIC_STRING=12345678
FullUpgrade="n"
#CRC_SEGMENT_SIZE should align to 0x1000
CRC_SEGMENT_SIZE=0x200000 #2MB

function func_process_main_script()
{
    #BUILD_TIME=`date '+%Y-%m-%d %T'`
    #BUILD_PATH=`pwd`
    echo "[start] func_process_main_script"
    echo "# <- this is for comment / total file size must be less than 4KB" >> $SCRIPT_FILE
    echo "#<upgrade_bin_version=$upgrade_bin_version>" >> $SCRIPT_FILE

	setpartition=0

	#confirm each image is upgrade or not.
	mainScript=""
	tmp2="
"
	tmpScript=$(grep "estar" $AUTO_UPDATE_SCRIPT | grep "\[\[")
	for mainContent in $tmpScript
	do
		imageName=$(echo $mainContent | awk '{print $2}' | cut -d '/' -f 2)
		mainScript=$mainScript$mainContent$tmp2
		
	done

	#pad set_config to usb script
	tmpScript=$(grep "set_config" $AUTO_UPDATE_SCRIPT)
	mainScript=$mainScript$tmpScript
	#pad set_partition to usb script
	if [ "$setpartition" == "0" ]; then
		tmpScript=$(grep "set_partition" $AUTO_UPDATE_SCRIPT)
		mainScript=$tmpScript$tmp2$mainScript
	fi


    echo "UpgradeImage Generating....."
    for mainContent in $mainScript
    do
        if [ "$(echo $mainContent | awk '{print $1}')" == "estar" ];then
            func_process_sub_script $(echo $mainContent|awk '{print $2}')
        else
            if [ "$mainContent" != "reset" ] && [ "$mainContent" != "printenv" ] && [ "$mainContent" != "% <- this is end of file symbol" ];then
                echo $mainContent >> $SCRIPT_FILE
            fi
        fi
    done
}

function func_process_sub_script()
{
    filePath=$1
    fileName=$(echo $1 | cut -d '/' -f 2 | cut -d '[' -f 3)
    echo "" >> $SCRIPT_FILE
    echo "# File Partition: "$fileName >> $SCRIPT_FILE
    filecontent=$(grep -Ev "^\s*$|#" $TARGET_DIR/$filePath)
    for subContent in $filecontent
    do
        if [ "$subContent" != "% <- this is end of file symbol" ] && [ "$subContent" != "sync_mmap" ]; then
            subContent_prefix=$(echo $subContent | awk '{print $1}')
            if [ "$subContent_prefix" == "tftp" ]; then
                DRAM_BUF_ADDR=$(echo $subContent | awk '{print $2}')
                imagePath=$(echo $subContent | awk '{print $3}')
                imageSize=$(stat -c%s $TARGET_DIR/$imagePath)
                imageSize_withcrc=$(($imageSize+$FILE_CRC_HEADER_SIZE))
                printf "fatload mmc 0 %s \$(SdUpgradeImage) 0x%x 0x%x\n" $DRAM_BUF_ADDR $imageSize_withcrc $currentImageOffset >> $SCRIPT_FILE
                printf "crccheck 0x%x 0x%x\n" $DRAM_BUF_ADDR $imageSize_withcrc >> $SCRIPT_FILE

                cat $TARGET_DIR/$imagePath >>$TARGET_DIR/image_crc.bin

                CRC_VALUE=`crc32  $TARGET_DIR/image_crc.bin`
                printf $CRC_VALUE >> $TARGET_DIR/image_crc.bin
                cat $TARGET_DIR/image_crc.bin >> $TMP_UPGRADE_FILE
                rm -rf $TARGET_DIR/image_crc.bin

                # align image to 0x1000(4K)
                ImageAlignSize=0
                NOT_ALAIN_IMAGE_SIZE=$(($imageSize_withcrc & 0xfff))
                if [ $NOT_ALAIN_IMAGE_SIZE != 0 ]; then
                    ImageAlignSize=$((0x1000-$NOT_ALAIN_IMAGE_SIZE))
                    for ((i=0; i<$ImageAlignSize; i++))
                    do
                        printf "\xff" >>$PADDED_BIN
                    done

                    cat $PADDED_BIN >>$TMP_UPGRADE_FILE
                    rm $PADDED_BIN
                fi
                currentImageOffset=$(($currentImageOffset+$imageSize_withcrc+$ImageAlignSize))
            else
                #fix ubi write 0x20400000 tvcustomer ${filesize} to ubi write 0x20400000 tvcustomer 0xfffff
                #Begin
                CMD=$(echo $subContent | awk '{print $2}')
                if [ "$CMD" == "write.p" ] || [ "$CMD" == "write.boot" ] || [ "$CMD" == "unlzo" ] || [ "$CMD" == "unlzo.cont" ] || [ "$CMD" == "write.e" ] || [ "$CMD" == "write" ]; then
                    #change 10 mechanism to 16 mechanism
                    imageSize_16=0x$(echo "obase=16; $imageSize" | bc)
                    imageAddr=$(echo "$DRAM_BUF_ADDR")
                    subContent=${subContent/'$(filesize)'/$imageSize_16}
                    subContent=${subContent/'${filesize}'/$imageSize_16}
                    subContent=${subContent/'${fileaddr}'/$imageAddr}
                fi
                #fix nand write.e ${fileaddr} recovery $(filesize) to nand write.e xxx recovery xxx
                #fix setenv recoverycmd nand read.e 0x25000000 recovery $(filesize) to setenv recoverycmd nand read.e 0x25000000 recovery xxx
                CMD_NAND=$(echo $subContent | awk '{print $1}')
                if [ "$CMD_NAND" == "ncishash" ] || [ "$CMD_NAND" == "setenv" ]; then
                    imageSize_16=0x$(echo "obase=16; $imageSize" | bc)
                    subContent=${subContent/'$(filesize)'/$imageSize_16}
                fi
                #End
                subContent=$(echo $subContent | tr -d '\r\n')
                echo $subContent >> $SCRIPT_FILE
            fi
        fi
    done
}

function func_init()
{
    # delete related file
    rm -f $SCRIPT_FILE
    rm -f $UPGRADE_FILE
    rm -f $TMP_UPGRADE_FILE
    #ANDROID_BUILD_TOP=`pwd`
    #export PATH=$PATH:$ANDROID_BUILD_TOP/prebuilts/tools/linux-x86/crc
    dos2unix $AUTO_UPDATE_SCRIPT $TARGET_DIR/scripts/* 1>/dev/null 2>&1
}

function func_generate_script_file()
{

    echo "% <- this is end of script symbol" >>$SCRIPT_FILE

    # pad script to script_file size
    SCRIPT_FILE_SIZE=$(stat -c%s $SCRIPT_FILE)
    PADDED_SIZE=$(($SCRIPT_SIZE-$SCRIPT_FILE_SIZE))

    printf "\xff" >$PAD_DUMMY_BIN
    for ((i=1; i<$PAD_DUMMY_SIZE; i++))
    do
        printf "\xff" >>$PAD_DUMMY_BIN
    done

    while [ $PADDED_SIZE -gt $PAD_DUMMY_SIZE ]
    do
        cat $PAD_DUMMY_BIN >> $SCRIPT_FILE
        PADDED_SIZE=$(($PADDED_SIZE-$PAD_DUMMY_SIZE))
    done

    if [ $PADDED_SIZE != 0 ]; then
        printf "\xff" >$PADDED_BIN
        for ((i=1; i<$PADDED_SIZE; i++))
        do
            printf "\xff" >>$PADDED_BIN
        done
        cat $PADDED_BIN >> $SCRIPT_FILE
        rm $PADDED_BIN
    fi
}

function func_generate_upgrade_file()
{
    # generate $UPGRADE_FILE
    cat $SCRIPT_FILE > $UPGRADE_FILE
    cat $TMP_UPGRADE_FILE >> $UPGRADE_FILE
    rm $TMP_UPGRADE_FILE

    # pad mangic to $UPGRADE_FILE
    printf "%s" $MAGIC_STRING >> $UPGRADE_FILE

    # pad $UPGRADE_FILE crc to $UPGRADE_FILE
    #CRC_VALUE=`crc -a $SCRIPT_FILE | grep "CRC32" | awk '{print $3;}'`
    #split -d -a 2 -b $SPILT_SIZE $SCRIPT_FILE $SCRIPT_FILE.
    #printf "script file crc %s\n" $CRC_VALUE
    #cat $SCRIPT_FILE.01 >> $UPGRADE_FILE
    #rm -f $SCRIPT_FILE.*
    #crc -a $UPGRADE_FILE

    # copy the first 16 bytes to last
    dd if=$UPGRADE_FILE of=./first16.bin bs=16 count=1;
    cat ./first16.bin >> $UPGRADE_FILE
    rm -f ./first16.bin
}

function parsing_para()
{
    while [ $# != 0 ]; do
        tmp1=$1
        tmp2=`echo $1|cut -d= -f1`
        case "$tmp2" in
        "FullUpgrade" )
            FullUpgrade=`echo $tmp1|cut -d= -f2`
            ;;
        * )
            echo "unknown parameter !!"
            exit 1
            ;;
        esac
        shift
    done

    if [ "$FullUpgrade" == "Y" ];then
        tmp=$FullUpgrade
    else
        read -p "Full Upgrade? (Y/n)" tmp
    fi
}

#-----------------------------------------------
# Main():Generate Upgrade Image via Tftp Script
#-----------------------------------------------
IFS="
"
func_init;
func_process_main_script;
func_generate_script_file;
func_generate_upgrade_file;
