insmod /config/modules/4.9.84/cifs.ko
insmod /config/modules/4.9.84/nls_utf8.ko
insmod /config/modules/4.9.84/grace.ko
insmod /config/modules/4.9.84/sunrpc.ko
insmod /config/modules/4.9.84/lockd.ko
insmod /config/modules/4.9.84/nfs.ko
insmod /config/modules/4.9.84/nfsv2.ko
insmod /config/modules/4.9.84/fat.ko
insmod /config/modules/4.9.84/msdos.ko
insmod /config/modules/4.9.84/vfat.ko
insmod /config/modules/4.9.84/ntfs.ko
insmod /config/modules/4.9.84/usb-common.ko
insmod /config/modules/4.9.84/usbcore.ko
insmod /config/modules/4.9.84/ehci-hcd.ko
insmod /config/modules/4.9.84/usb-storage.ko
insmod /config/modules/4.9.84/usbhid.ko
insmod /config/modules/4.9.84/mdrv_crypto.ko
insmod /config/modules/4.9.84/soundcore.ko
insmod /config/modules/4.9.84/snd.ko
insmod /config/modules/4.9.84/snd-timer.ko
insmod /config/modules/4.9.84/snd-pcm.ko
#kernel_mod_list
insmod /config/modules/4.9.84/mhal.ko
#misc_mod_list
insmod /config/modules/4.9.84/mi_common.ko
insmod /config/modules/4.9.84/mi_sys.ko cmdQBufSize=128 logBufSize=0
insmod /config/modules/4.9.84/mi_gfx.ko
insmod /config/modules/4.9.84/mi_divp.ko
insmod /config/modules/4.9.84/mi_vdec.ko
insmod /config/modules/4.9.84/mi_ai.ko
insmod /config/modules/4.9.84/mi_ao.ko
insmod /config/modules/4.9.84/mi_disp.ko
insmod /config/modules/4.9.84/mi_alsa.ko
insmod /config/modules/4.9.84/mi_venc.ko
insmod /config/modules/4.9.84/mi_panel.ko
#mi module
major=`cat /proc/devices | busybox awk "\\$2==\""mi_poll"\" {print \\$1}"`
busybox mknod /dev/mi_poll c $major 0
insmod /config/modules/4.9.84/fbdev.ko
#misc_mod_list_late
mdev -s
export TERM=vt102
export TERMINFO=/config/terminfo
echo /customer/pq.ini  0x148 > /sys/class/mstar/mdisp/pq
