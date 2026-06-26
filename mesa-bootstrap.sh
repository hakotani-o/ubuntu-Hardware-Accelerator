#!/bin/bash

set -eE
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

kernel=`ls ./linux*.deb|wc -l`
if [ $kernel -ne 3 ]; then
	echo "Build kernel first"
	exit 1
fi

#Bootstrap the system
rm -rf $1
mkdir $1
chroot_dir=$1
mem_size=`free --giga|grep Mem|awk '{print $2}'`
if [ $mem_size -gt 10 ]; then
	mount -t tmpfs -o size=10G tmpfs $chroot_dir
fi
rm -f wget-log* kernel_version

#suite=plucky
suite=resolute
#Uri="https://mirror.hashy0917.net/ubuntu-ports/"
Uri="http://ftp.udx.icscoe.jp/Linux/ubuntu-ports/"
#Uri="http://ports.ubuntu.com/ubuntu-ports"
	debootstrap --arch=arm64 $suite arm64 $Uri

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export  LC_ALL=C
export  LC_CTYPE=C
export  LANGUAGE=C
export  LANG=C 

#Setup DNS
echo "127.0.0.1 localhost" > $1/etc/hosts
echo "nameserver 8.8.8.8" > $1/etc/resolv.conf
echo "nameserver 8.8.4.4" >> $1/etc/resolv.conf

#sources.list setup
rm $1/etc/hostname
echo "ubuntu-desktop" > $1/etc/hostname
{
echo "Types: deb"
echo "URIs: $Uri"
echo "Suites: $suite $suite-updates $suite-backports"
echo "Components: main universe restricted multiverse"
echo "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg"
echo ""
echo "## Ubuntu security updates. Aside from URIs and Suites,"
echo "## this should mirror your choices in the previous section."
echo "Types: deb"
echo "URIs: $Uri"
echo "Suites: $suite-security"
echo "Components: main universe restricted multiverse"
echo "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg"
} > $1/etc/apt/sources.list.d/ubuntu.sources
rm -f $1/etc/apt/sources.list

{
echo "Package: firefox*"
echo "Pin: release o=LP-PPA-mozillateam"
echo "Pin-Priority: 1001"
echo ""
echo "Package: firefox*"
echo "Pin: release o=Ubuntu"
echo "Pin-Priority: -1"
echo ""
echo "Package: thunderbird*"
echo "Pin: release o=LP-PPA-mozillateam"
echo "Pin-Priority: 1001"
echo ""
echo "Package: thunderbird*"
echo "Pin: release o=Ubuntu"
echo "Pin-Priority: -1"
} > $1/etc/apt/preferences.d/mozillateam-ppa
echo "sudo apt install firefox-esr thunderbird-gnome-support"

{
echo 'Package: *'
echo 'Pin: release o=LP-PPA-xtradeb-apps'
echo 'Pin-Priority: 100'
echo ''
echo 'Package: chromium*'
echo 'Pin: release o=LP-PPA-xtradeb-apps'
echo 'Pin-Priority: 700'
echo ''
echo 'Package: chromium-browser'
echo 'Pin: release *'
echo 'Pin-Priority: -1'
} > $1/etc/apt/preferences.d/xtradeb-chromium-ppa

#setup custom packages

systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 apt-get update
systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 apt-get -y upgrade
systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 apt-get install -y software-properties-common
systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 add-apt-repository -y ppa:mozillateam/ppa
systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 add-apt-repository -y ppa:xtradeb/apps 
systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 apt update
systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 apt-get -y dist-upgrade
systemd-nspawn -D $1 \
  --resolv-conf=replace-host \
  --as-pid2 \
  --setenv=DEBIAN_FRONTEND=noninteractive \
  --setenv=DEBCONF_NONINTERACTIVE_SEEN=true \
apt-get -y install ubuntu-desktop-minimal gdm3 linux-firmware oem-config-gtk ubiquity-frontend-gtk ubiquity-slideshow-ubuntu yaru-theme-unity yaru-theme-icon yaru-theme-gtk aptdaemon initramfs-tools vim cloud-guest-utils e2fsprogs sudo dialog
#systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 apt-get -y install  build-essential gcc-aarch64-linux-gnu bison \
#qemu-user-binfmt qemu-system-arm qemu-efi-aarch64 binfmt-support \
#flex libssl-dev bc rsync kmod cpio xz-utils parted \
#udev dosfstools python3 \
#python-is-python3 fdisk bc debhelper python3-pyelftools python3-setuptools \
#python3-pkg-resources swig libfdt-dev libpython3-dev gawk \
#git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex \
#libelf-dev bison sudo libgnutls28-dev cloud-guest-utils e2fsprogs


systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 /bin/bash -c "apt-get install -y gstreamer1.0-plugins-bad gstreamer1.0-plugins-good gstreamer1.0-tools clapper mpv vulkan-tools mesa-utils"

systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 apt-get -y purge cloud-init flash-kernel fwupd nano grub-efi-arm64

systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 apt-get update
systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 apt-get -y upgrade

sed -i 's/#EXTRA_GROUPS=.*/EXTRA_GROUPS="video"/g' $1/etc/adduser.conf
sed -i 's/#ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/g' $1/etc/adduser.conf


mkdir -p "$1/etc/initramfs-tools"
echo "MODULES=most" > "$1/etc/initramfs-tools/conf.d/kdump-workaround.conf"

# 構築時のみカーネルパッケージのフック（自動更新）を無効化する
mkdir -p "$1/etc/kernel/postinst.d"
chmod -x "$1/etc/kernel/postinst.d/kdump-tools" 2>/dev/null || true

# kernel
mkdir $1/kkk && rm -f libdrm-dev_*.deb libegl1-mesa-dev_*.deb libgbm-dev_*.deb && \
rm -f libgl1-mesa-dev_*.deb libgles2-mesa-dev_*.deb mesa-common-dev_*.deb && \
rm -f mesa-opencl-icd_*.deb mesa-teflon-delegate_*.deb mesa-drm-shim_*.deb && \
rm -f libdrm-tests_*.deb && cp *.deb $1/kkk 

systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 /bin/bash -c "apt-get -y purge \$(dpkg --list | grep -Ei 'linux-image|linux-headers|linux-modules|linux-rockchip' | awk '{ print \$2 }')"
systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 /bin/bash -c "cd kkk && dpkg -i *.deb"

rm -rf $1/kkk
kernel_version="`ls -1 $1/boot/vmlinu?-*|sed 's#-# #' | awk '{ print $2 }'`"
echo "kernel_version=$kernel_version" > kernel_version
# install U-Boot
systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 apt-get -y install u-boot-tools u-boot-menu

# Default kernel command line arguments
echo -n "rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" > $1/etc/kernel/cmdline
echo -n " quiet splash plymouth.ignore-serial-consoles crashkernel=2M-:256M" >> $1/etc/kernel/cmdline

# Override u-boot-menu config
mkdir -p $1/usr/share/u-boot-menu/conf.d
cat << 'EOF' > $1/usr/share/u-boot-menu/conf.d/ubuntu.conf
U_BOOT_UPDATE="true"
U_BOOT_PROMPT="1"
U_BOOT_PARAMETERS="$(cat $1/etc/kernel/cmdline)"
U_BOOT_TIMEOUT="20"
EOF

rm -f $1/var/lib/dbus/machine-id
true > $1/etc/machine-id
touch $1/var/log/syslog
chown syslog:adm $1/var/log/syslog
systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 ssh-keygen -A
# debug
echo "linux-version"
systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 linux-version list

# chromium
mkdir -p $1/etc/chromium.d/
echo 'export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --enable-features=AcceleratedVideoDecoder,V4l2VideoDecode --disable-features=UseChromeOSDirectVideoDecoder"' > $1/etc/chromium.d/opi5-v4l2


systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 apt-get  clean
systemd-nspawn -D $1 --resolv-conf=replace-host --as-pid2 apt-get -y autoremove


rm -f wget-log*
rm -f $1/boot/*.old
#tar the rootfs
rootfs="./ubuntu.rootfs.tar.gz"
echo "rootfs=$rootfs" > ./rootfs
cd $1
rm -rf ../$rootfs
sync
echo " Now create $rootfs "
tar -zcf ../$rootfs --xattrs --xattrs-include='*' ./*
cd ..
echo "DISK usage"
df $1  
# Exit trap is no longer needed
trap '' EXIT
if [ $mem_size -gt 10 ]; then
	umount $1
	sleep 2
fi
exit 0
