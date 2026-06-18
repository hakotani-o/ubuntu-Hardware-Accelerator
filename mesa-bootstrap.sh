#!/bin/bash

set -eE
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

kernel=`ls linux*.deb|wc -l`
if [ $kernel -ne 3 ]; then
	echo "Build kernel first"
	exit 1
fi

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
if [ $mem_size -gt 6 ]; then
	mount -t tmpfs -o size=10G tmpfs $chroot_dir
fi
rm -f wget-log* kernel_version

#suite=plucky
suite=resolute
#Uri="https://mirror.hashy0917.net/ubuntu-ports/"
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

#setup custom packages
setup_mountpoint $chroot_dir

chroot $1 apt-get update
chroot $1 apt-get -y upgrade
chroot $1 apt-get install -y software-properties-common
chroot $1 add-apt-repository -y ppa:mozillateam/ppa
chroot $1 apt update
chroot $1 apt-get -y dist-upgrade
chroot $1 apt-get -y install ubuntu-desktop-minimal gdm3 linux-firmware oem-config-gtk ubiquity-frontend-gtk ubiquity-slideshow-ubuntu yaru-theme-unity yaru-theme-icon yaru-theme-gtk aptdaemon initramfs-tools vim
chroot $1 apt-get -y install  build-essential gcc-aarch64-linux-gnu bison \
qemu-user-binfmt qemu-system-arm qemu-efi-aarch64 binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs device-tree-compiler python3 \
python-is-python3 fdisk bc debhelper python3-pyelftools python3-setuptools \
python3-pkg-resources swig libfdt-dev libpython3-dev gawk \
git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex \
libelf-dev bison sudo libgnutls28-dev cloud-guest-utils e2fsprogs

# Mesa new part3
#chroot $1 apt-get -y install build-essential meson ninja-build pkgconf pkgconf-bin python3-mako \
#  libdrm-dev libpciaccess-dev libffi-dev libsensors-dev libxml2-dev \
#  libx11-dev libx11-xcb-dev libxcb-dri2-0-dev libxcb-dri3-dev libxcb-glx0-dev \
#  libxcb-present-dev libxcb-randr0-dev libxcb-shm0-dev libxcb-xfixes0-dev libxcb1-dev \
#  libxdmcp-dev libxext-dev libxrandr-dev libxrender-dev libxshmfence-dev libxxf86vm-dev \
#  libwayland-dev libwayland-bin libwayland-egl-backend-dev wayland-protocols \
#  libglvnd-core-dev libvulkan-dev glslang-tools spirv-tools spirv-tools-dev \
#libclc-21-dev llvm-21-dev libllvmspirvlib-21-dev libclang-cpp21-dev libclang-21-dev


# Mesa new part1
#echo "--------------- build-dep -y mesa start ---------------------"
# set echo "Types: deb deb-src" to ubuntu.sources
#chroot $1 apt-get build-dep -y mesa
#echo "--------------- build-dep -y mesa end  ----------------------"

chroot $1 /bin/bash -c "apt-get install -y gstreamer1.0-plugins-bad gstreamer1.0-plugins-good gstreamer1.0-tools clapper mpv vulkan-tools mesa-utils"

chroot $1 apt-get -y purge cloud-init flash-kernel fwupd nano grub-efi-arm64

chroot $1 apt-get update
chroot $1 apt-get -y upgrade

# systemctl stop apparmor

sed -i 's/#EXTRA_GROUPS=.*/EXTRA_GROUPS="video"/g' $1/etc/adduser.conf
sed -i 's/#ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/g' $1/etc/adduser.conf

# kernel
mkdir $1/kkk && rm -f libdrm-dev_*.deb libegl1-mesa-dev_*.deb libgbm-dev_*.deb && \
rm -f libgl1-mesa-dev_*.deb libgles2-mesa-dev_*.deb mesa-common-dev_*.deb && \
rm -f mesa-opencl-icd_*.deb mesa-teflon-delegate_*.deb mesa-drm-shim_*.deb && \
rm -f libdrm-tests_*.deb && cp *.deb $1/kkk
chroot $1 /bin/bash -c "apt-get -y purge \$(dpkg --list | grep -Ei 'linux-image|linux-headers|linux-modules|linux-rockchip' | awk '{ print \$2 }')"
chroot $1 /bin/bash -c "cd kkk && dpkg -i *.deb"

# mesa
#mkdir $1/bbb
#chroot $1 /bin/bash -c "cd bbb && git clone --depth 1 https://gitlab.freedesktop.org/mesa/libdrm && cd libdrm/ && mkdir build && cd build/ && meson && ninja install"

# Mesaの仕入れとビルド（Panthor最適化版）
#chroot $1 /bin/bash -c "cd bbb && git clone --depth 1 -b staging/26.0 https://gitlab.freedesktop.org/mesa/mesa && cd mesa && mkdir build && cd build && meson setup .. -Dvulkan-drivers=panfrost -Dgallium-drivers=panfrost -Dlibunwind=false -Dprefix=/opt/panthor && ninja install"

# 共有ライブラリのパスを通す
#chroot $1 /bin/bash -c "echo /opt/panthor/lib/aarch64-linux-gnu | tee /etc/ld.so.conf.d/0-panthor.conf && ldconfig"

# Vulkanドライバーの環境変数を定義
#chroot $1 /bin/bash -c "echo 'VK_DRIVER_FILES=\"/opt/panthor/share/vulkan/icd.d/panfrost_icd.aarch64.json\"' >> /etc/environment"

#chroot $1 /bin/bash -c "cat << 'EOF' > /etc/profile.d/rockchip-panthor.sh
# 1. 明示的に新グラフィックドライバ（Panthor）をロードする指示
# export MESA_LOADER_DRIVER_OVERRIDE=panthor

# 2. FirefoxをWayland（GPUアクセラレーション必須環境）で動かす設定
#export MOZ_ENABLE_WAYLAND=1

# 3. Chromium/Chrome系列でPanthor GPUを強制認識させるフラグ
#export CHROMIUM_FLAGS=\"--enable-features=UseOzonePlatform --ozone-platform=wayland --enable-gpu-rasterization --enable-zero-copy\"
#EOF
#chmod +x /etc/profile.d/rockchip-panthor.sh"


rm -rf $1/aaa $1/bbb $1/kkk
kernel_version="`ls -1 $1/boot/vmlinu?-*|sed 's#-# #' | awk '{ print $2 }'`"
echo "kernel_version=$kernel_version" > kernel_version
# install U-Boot
chroot $1 apt-get -y install u-boot-tools u-boot-menu

# Default kernel command line arguments
echo -n "rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" > $1/etc/kernel/cmdline
echo -n " quiet splash plymouth.ignore-serial-consoles" >> $1/etc/kernel/cmdline

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
chroot $1 ssh-keygen -A
# debug
echo "linux-version"
chroot $1 linux-version list

chroot $1 apt-get  clean
chroot $1 apt-get -y autoremove


teardown_mountpoint $chroot_dir
rm -f wget-log*
rm -f $1/boot/*.old
#tar the rootfs
rootfs="ubuntu.rootfs.tar.gz"
echo "rootfs=$rootfs" > rootfs
cd $1
rm -rf ../$rootfs
sync
tar -zcf ../$rootfs --xattrs --xattrs-include='*' ./*
cd ..
echo "DISK usage"
df $1  
# Exit trap is no longer needed
trap '' EXIT
if [ $mem_size -gt 6 ]; then
	umount $1
	sleep 2
fi
exit 0
