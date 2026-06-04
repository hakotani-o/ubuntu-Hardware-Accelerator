#!/bin/bash

export LANGUAGE=C
export LC_ALL=C
export LANG=C

	 rm -rf build && mkdir build

	mem_size=`free --giga|grep Mem|awk '{print $2}'`
	if [ $mem_size -gt 10 ]; then
		 mount -t tmpfs -o size=10G tmpfs build
	fi

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
mount --bind /dev  "build/chroot/root/dev"
mount --bind /proc "build/chroot/root/proc"
mount --bind /sys  "build/chroot/root/sys"
# Mesa new part3
chroot build/chroot apt-get -y install build-essential meson ninja-build pkgconf pkgconf-bin python3-mako \
  libdrm-dev libpciaccess-dev libffi-dev libsensors-dev libxml2-dev \
  libx11-dev libx11-xcb-dev libxcb-dri2-0-dev libxcb-dri3-dev libxcb-glx0-dev \
  libxcb-present-dev libxcb-randr0-dev libxcb-shm0-dev libxcb-xfixes0-dev libxcb1-dev \
  libxdmcp-dev libxext-dev libxrandr-dev libxrender-dev libxshmfence-dev libxxf86vm-dev \
  libwayland-dev libwayland-bin libwayland-egl-backend-dev wayland-protocols \
  libglvnd-core-dev libvulkan-dev glslang-tools spirv-tools spirv-tools-dev \
libclc-21-dev llvm-21-dev libllvmspirvlib-21-dev libclang-cpp21-dev libclang-21-dev \
git
chroot build/chroot /bin/bash -c "apt-get install -y gstreamer1.0-plugins-bad gstreamer1.0-plugins-good gstreamer1.0-tools clapper mpv vulkan-tools mesa-utils"
# mesa
mkdir build/chroot/bbb
chroot build/chroot /bin/bash -c "cd bbb && git clone --depth 1 https://gitlab.freedesktop.org/mesa/libdrm && cd libdrm/ && mkdir build && cd build/ && meson && ninja install"
#chroot build/chroot /bin/bash -c "cd bbb && git clone --depth 1 -b staging/25.3 https://gitlab.freedesktop.org/mesa/mesa.git && cd mesa && mkdir build && cd build && meson -Dvulkan-drivers=panfrost -Dgallium-drivers=panfrost -Dlibunwind=false -Dprefix=/opt/panfrost && ninja install && echo /opt/panfrost/lib/aarch64-linux-gnu | tee /etc/ld.so.conf.d/0-panfrost.conf && echo 'VK_DRIVER_FILES="/opt/panfrost/share/vulkan/icd.d/panfrost_icd.aarch64.json"' >> /etc/environment"

# Mesaの仕入れとビルド（Panthor最適化版）
chroot build/chroot /bin/bash -c "cd bbb && git clone --depth 1 -b staging/25.3 https://gitlab.freedesktop.org/mesa/mesa.git && cd mesa && mkdir build && cd build && meson setup .. -Dvulkan-drivers=panfrost -Dgallium-drivers=panfrost -Dplatforms=x11,wayland -Dbuildtype=release -Dprefix=/opt/panthor && ninja install"
# -Dlibunwind=false

# 共有ライブラリのパスを通す
chroot build/chroot /bin/bash -c "echo /opt/panthor/lib/aarch64-linux-gnu | tee /etc/ld.so.conf.d/0-panthor.conf && ldconfig"

# Vulkanドライバーの環境変数を定義
chroot build/chroot /bin/bash -c "echo 'VK_DRIVER_FILES=\"/opt/panthor/share/vulkan/icd.d/panfrost_icd.aarch64.json\"' >> /etc/environment"

chroot build/chroot /bin/bash -c "cat << 'EOF' > /etc/profile.d/rockchip-panthor.sh
# 1. 明示的に新グラフィックドライバ（Panthor）をロードする指示
# export MESA_LOADER_DRIVER_OVERRIDE=panthor

# 2. FirefoxをWayland（GPUアクセラレーション必須環境）で動かす設定
export MOZ_ENABLE_WAYLAND=1

# 3. Chromium/Chrome系列でPanthor GPUを強制認識させるフラグ
export CHROMIUM_FLAGS=\"--enable-features=UseOzonePlatform --ozone-platform=wayland --enable-gpu-rasterization --enable-zero-copy\"
EOF
chmod +x /etc/profile.d/rockchip-panthor.sh"

umount "build/chroot/root/sys"
umount "build/chroot/root/proc"
umount "build/chroot/root/dev"
rm -rf build/chroot/bbb



	setup_mountpoint build/chroot
	 mkdir build/chroot/kernel
	 cp *.deb build/chroot/kernel
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
	if [ $mem_size -gt 10 ]; then
		umount build
		sleep 2
	fi  
	exit 0
