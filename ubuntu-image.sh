#!/bin/bash

export LANGUAGE=C
export LC_ALL=C
export LANG=C

	 rm -rf build && mkdir build

	mem_size=`free --giga|grep Mem|awk '{print $2}'`
	if [ $mem_size -gt 13 ]; then
		 mount -t tmpfs -o size=13G tmpfs build
	fi
df
	 apt-get update
	 apt-get -y install git snapd qemu-user-static ubuntu-dev-tools
	 snap install --classic ubuntu-image
#	 snap install --channel=latest/edge --classic ubuntu-image
	 ubuntu-image --debug --workdir build classic image-definition.yaml

#	 rm -rf build/root
	 chmod +x setup-script.sh
	 cp setup-script.sh build/chroot/

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

	setup_mountpoint build/chroot
#	 mkdir build/chroot/kernel
# コピー先のフォルダを作成（例：/path/to/rootfs/kernel）
TARGET_DIR="build/chroot/kernel"
mkdir -p "$TARGET_DIR"

# 1. すべての .deb ファイルをすべてコピー
# cp linux-*.deb "$TARGET_DIR/"
cp *.deb "$TARGET_DIR/"

# 2. 【★ここがポイント★】Mesaの山から、不要な「-dev」や「-dbg（デバッグ用）」、
#    および他社用（va-drivers, vdpau等）を完全に除外し、必要な本体だけを狙ってコピー
# find ./ -maxdepth 1 -name "*.deb" \
#  ! -name "*-dev_*.deb" \
#  ! -name "*-dbg_*.deb" \
#  ! -name "*va-drivers_*.deb" \
#  ! -name "*vdpau-drivers_*.deb" \
#  ! -name "*opencl-icd_*.deb" \
#  ! -name "*drm-shim_*.deb" \
#  ! -name "*teflon-delegate_*.deb" \
#  -exec cp {} "$TARGET_DIR/" \;

echo "=== 選別完了: /kernel の中身は以下の通りです ==="
ls -l "$TARGET_DIR"
 
	 chroot build/chroot /setup-script.sh
	teardown_mountpoint build/chroot
	 rm build/chroot/setup-script.sh
	 rm -rf build/chroot/kernel
	rootfs="./ubuntu.rootfs.tar.gz"
	echo "rootfs=$rootfs" > rootfs
	kernel_version="`ls -1 build/chroot/boot/vmlinu?-*|sed 's#-# #' | awk '{ print $2 }'`"
	echo "kernel_version=$kernel_version" > kernel_version

	cd build/chroot &&  tar -zcf ../../$rootfs --xattrs ./*
	cd ../..
	if [ $mem_size -gt 13 ]; then
		umount build
		sleep 2
	fi  

