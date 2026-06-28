#!/bin/bash

set -eE
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi
# ディスクイメージを作成するために必要なツールをインストール
sudo apt-get update && sudo apt-get -y install  build-essential gcc-aarch64-linux-gnu bison systemd-container \
qemu-user-binfmt qemu-system-arm qemu-efi-aarch64 binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs device-tree-compiler python3 \
python-is-python3 fdisk bc debhelper python3-pyelftools python3-setuptools \
python3-pkg-resources swig libfdt-dev libpython3-dev gawk \
git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex \
libelf-dev bison libgnutls28-dev libdw-dev

#Bootstrap the system
rm -rf $1
mkdir $1
chroot_dir=$1
mem_size=`free --giga|grep Mem|awk '{print $2}'`
if [ $mem_size -gt 13 ]; then
	mount -t tmpfs -o size=12G tmpfs $chroot_dir
fi
#suite=plucky
suite=resolute
#Uri="http://ftp.udx.icscoe.jp/Linux/ubuntu-ports/"
Uri="http://ports.ubuntu.com/ubuntu-ports"
	debootstrap --arch=arm64 $suite $1 $Uri

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export  LC_ALL=C
export  LC_CTYPE=C
export  LANGUAGE=C
export  LANG=C 

#Setup DNS
echo "127.0.0.1 localhost" > $1/etc/hosts
echo "127.0.0.1 ubuntu-desktop" > $1/etc/hosts
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

echo "\n##################	systemd-nspawn	START	#######################\n"

systemd-nspawn -D $1 --resolv-conf=replace-host -E DEBIAN_FRONTEND=noninteractive --as-pid2 apt-get update
systemd-nspawn -D $1 --resolv-conf=replace-host -E DEBIAN_FRONTEND=noninteractive --as-pid2 apt-get -y upgrade
systemd-nspawn -D $1 --resolv-conf=replace-host -E DEBIAN_FRONTEND=noninteractive --as-pid2 apt-get -y dist-upgrade
systemd-nspawn -D $1 --resolv-conf=replace-host -E DEBIAN_FRONTEND=noninteractive --as-pid2 apt-get -y install ubuntu-desktop-minimal gdm3 linux-firmware aptdaemon initramfs-tools vim
systemd-nspawn -D $1 --resolv-conf=replace-host -E DEBIAN_FRONTEND=noninteractive --as-pid2 apt-get -y install build-essential gcc-aarch64-linux-gnu bison \
qemu-user-binfmt qemu-system-arm qemu-efi-aarch64 binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs device-tree-compiler python3 \
python-is-python3 fdisk bc debhelper python3-pyelftools python3-setuptools \
python3-pkg-resources swig libfdt-dev libpython3-dev gawk \
git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex \
libelf-dev bison sudo libgnutls28-dev
echo "\n##################	systemd-nspawn	END	#######################\n"

# Mesa new part1
#echo "--------------- build-dep -y mesa start ---------------------"
# set echo "Types: deb deb-src" to ubuntu.sources
#chroot $1 apt-get build-dep -y mesa
#echo "--------------- build-dep -y mesa end  ----------------------"


echo "=== 1. Mesaソースコードの取得 ==="
if [ "$2" == "upstream" ]; then
    echo "freedesktop staging/26.0 から取得します..."
	# mesa staging 26.0 version
	cp staging_panthor_mesa.sh ./libdrm-amdgpu1.symbols.patch $1 && chmod +x $1/staging_panthor_mesa.sh
	systemd-nspawn -D $1 --resolv-conf=replace-host -E DEBIAN_FRONTEND=noninteractive --as-pid2 /staging_panthor_mesa.sh
else
	# ubuntu version
	cp build_panthor_mesa.sh $1 && chmod +x $1/build_panthor_mesa.sh
systemd-nspawn -D $1 --resolv-conf=replace-host -E DEBIAN_FRONTEND=noninteractive --as-pid2 /build_panthor_mesa.sh
fi
cp $1/*.deb $1/rel.txt .
ls ./*.deb

if [ $mem_size -gt 13 ]; then
	umount $chroot_dir
	sleep 2
fi
