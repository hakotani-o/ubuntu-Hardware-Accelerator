#!/bin/bash

set -eE
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi
# ディスクイメージを作成するために必要なツールをインストール
sudo apt-get update && sudo apt-get -y install  build-essential gcc-aarch64-linux-gnu bison \
qemu-user-static qemu-system-arm qemu-efi-aarch64 binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs device-tree-compiler python3 \
python-is-python3 fdisk bc debhelper python3-pyelftools python3-setuptools \
python3-pkg-resources swig libfdt-dev libpython3-dev gawk \
git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex \
libelf-dev bison libgnutls28-dev libdw-dev

setup_mountpoint() {
    local mountpoint="$1"

    if [ ! -c /dev/mem ]; then
        mknod -m 660 /dev/mem c 1 1
        chown root:kmem /dev/mem
    fi

    mount dev-live -t devtmpfs "$mountpoint/dev"
    mount devpts-live -t devpts -o nodev,nosuid "$mountpoint/dev/pts"
    mount proc-live -t proc "$mountpoint/proc"
    mount sysfs-live -t sysfs "$mountpoint/sys"
    mount securityfs -t securityfs "$mountpoint/sys/kernel/security"
    # Provide more up to date apparmor features, matching target kernel
    # cgroup2 mount for LP: 1944004
    mount -t cgroup2 none "$mountpoint/sys/fs/cgroup"
    mount -t tmpfs none "$mountpoint/tmp"
    mount -t tmpfs none "$mountpoint/var/lib/apt/lists"
    mount -t tmpfs none "$mountpoint/var/cache/apt"
}
teardown_mountpoint() {
    # Reverse the operations from setup_mountpoint
    local mountpoint
    mountpoint=$(realpath "$1")

    # ensure we have exactly one trailing slash, and escape all slashes for awk
    mountpoint_match=$(echo "$mountpoint" | sed -e's,/$,,; s,/,\\/,g;')'\/'
    # sort -r ensures that deeper mountpoints are unmounted first
    awk </proc/self/mounts "\$2 ~ /$mountpoint_match/ { print \$2 }" | LC_ALL=C sort -r | while IFS= read -r submount; do
        mount --make-private "$submount"
        umount "$submount"
    done
}

#Bootstrap the system
rm -rf $1
mkdir $1
chroot_dir=$1
mem_size=`free --giga|grep Mem|awk '{print $2}'`
if [ $mem_size -gt 10 ]; then
	mount -t tmpfs -o size=10G tmpfs $chroot_dir
fi
#suite=plucky
suite=resolute
#Uri="http://ftp.udx.icscoe.jp/Linux/ubuntu-ports/"
Uri="http://ports.ubuntu.com/ubuntu-ports"
	debootstrap --arch=arm64 $suite arm64 $Uri

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export  LC_ALL=C
export  LC_CTYPE=C
export  LANGUAGE=C
export  LANG=C 
chroot $1 apt-get clean

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

#setup custom packages
setup_mountpoint $chroot_dir

chroot $1 apt-get update
chroot $1 apt-get -y upgrade
chroot $1 apt-get -y dist-upgrade
chroot $1 apt-get -y install ubuntu-desktop-minimal gdm3 linux-firmware snapd cloud-initramfs-growroot oem-config-gtk ubiquity-frontend-gtk ubiquity-slideshow-ubuntu yaru-theme-unity yaru-theme-icon yaru-theme-gtk aptdaemon initramfs-tools vim
chroot $1 apt-get -y install  build-essential gcc-aarch64-linux-gnu bison \
qemu-user-binfmt qemu-system-arm qemu-efi-aarch64 binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs device-tree-compiler python3 \
python-is-python3 fdisk bc debhelper python3-pyelftools python3-setuptools \
python3-pkg-resources swig libfdt-dev libpython3-dev gawk \
git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex \
libelf-dev bison sudo libgnutls28-dev

# Mesa new part3
chroot $1 apt-get -y install build-essential meson ninja-build pkgconf pkgconf-bin python3-mako \
  libdrm-dev libpciaccess-dev libffi-dev libsensors-dev libxml2-dev \
  libx11-dev libx11-xcb-dev libxcb-dri2-0-dev libxcb-dri3-dev libxcb-glx0-dev \
  libxcb-present-dev libxcb-randr0-dev libxcb-shm0-dev libxcb-xfixes0-dev libxcb1-dev \
  libxdmcp-dev libxext-dev libxrandr-dev libxrender-dev libxshmfence-dev libxxf86vm-dev \
  libwayland-dev libwayland-bin libwayland-egl-backend-dev wayland-protocols \
  libglvnd-core-dev libvulkan-dev glslang-tools spirv-tools spirv-tools-dev \
libclc-21-dev llvm-21-dev libllvmspirvlib-21-dev libclang-cpp21-dev libclang-21-dev


# Mesa new part1
#echo "--------------- build-dep -y mesa start ---------------------"
# set echo "Types: deb deb-src" to ubuntu.sources
#chroot $1 apt-get build-dep -y mesa
#echo "--------------- build-dep -y mesa end  ----------------------"

# デフォルト値を設定（未指定ならubuntu）
MESA_SOURCE="${MESA_SOURCE:-ubuntu}"



echo "=== 1. Mesaソースコードの取得 ==="
if [ "${MESA_SOURCE}" = "upstream" ]; then
    echo "freedesktop staging/26.0 から取得します..."
	# mesa staging 26.0 version
	cp staging_panthor_mesa.sh libdrm-amdgpu1.symbols.patch $1 && chmod +x $1/staging_panthor_mesa.sh
	chroot $1 /staging_panthor_mesa.sh
else
	# ubuntu version
	cp build_panthor_mesa.sh $1 && chmod +x $1/build_panthor_mesa.sh
	chroot $1 /build_panthor_mesa.sh
fi
cp $1/*.deb .
cp $1/rel.txt .
ls *.deb
teardown_mountpoint $chroot_dir
if [ $mem_size -gt 10 ]; then
	umount $chroot_dir
	sleep 2
fi
