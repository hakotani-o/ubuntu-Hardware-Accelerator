#!/bin/bash
set -x


# Mesa new part1
#echo "--------------- build-dep -y mesa start ---------------------"
# set echo "Types: deb deb-src" to ubuntu.sources
#chroot $1 apt-get build-dep -y mesa
#echo "--------------- build-dep -y mesa end  ----------------------"

# Mesa new part3
apt-get update && apt-get -y install build-essential meson ninja-build pkgconf pkgconf-bin python3-mako \
  libdrm-dev libpciaccess-dev libffi-dev libsensors-dev libxml2-dev \
  libx11-dev libx11-xcb-dev libxcb-dri2-0-dev libxcb-dri3-dev libxcb-glx0-dev \
  libxcb-present-dev libxcb-randr0-dev libxcb-shm0-dev libxcb-xfixes0-dev libxcb1-dev \
  libxdmcp-dev libxext-dev libxrandr-dev libxrender-dev libxshmfence-dev libxxf86vm-dev \
  libwayland-dev libwayland-bin libwayland-egl-backend-dev wayland-protocols \
  libglvnd-core-dev libvulkan-dev glslang-tools spirv-tools spirv-tools-dev \
libclc-21-dev llvm-21-dev libllvmspirvlib-21-dev libclang-cpp21-dev libclang-21-dev git
 
apt-get install -y gstreamer1.0-plugins-bad gstreamer1.0-plugins-good gstreamer1.0-tools clapper mpv vulkan-tools mesa-utils

# mesa librdm
mkdir Mesa
cd Mesa && git clone --depth 1 https://gitlab.freedesktop.org/mesa/libdrm && cd libdrm/ && mkdir build && cd build/ && meson && ninja install && cd ../..

# Mesaの仕入れとビルド（Panthor最適化版）
git clone --depth 1 -b staging/25.3 https://gitlab.freedesktop.org/mesa/mesa.git && cd mesa && mkdir build && cd build && meson setup .. -Dvulkan-drivers=panfrost -Dgallium-drivers=panfrost -Dplatforms=x11,wayland -Dlibunwind=false -Dbuildtype=release -Dprefix=/opt/panthor && ninja install && cd ../../..


# 共有ライブラリのパスを通す
echo /opt/panthor/lib/aarch64-linux-gnu | tee /etc/ld.so.conf.d/0-panthor.conf && ldconfig

# Vulkanドライバーの環境変数を定義
echo 'VK_DRIVER_FILES=\"/opt/panthor/share/vulkan/icd.d/panfrost_icd.aarch64.json\"' >> /etc/environment

cat << 'EOF' > /etc/profile.d/rockchip-panthor.sh
# 1. 明示的に新グラフィックドライバ（Panthor）をロードする指示
# export MESA_LOADER_DRIVER_OVERRIDE=panthor

# 2. FirefoxをWayland（GPUアクセラレーション必須環境）で動かす設定
export MOZ_ENABLE_WAYLAND=1

# 3. Chromium/Chrome系列でPanthor GPUを強制認識させるフラグ
export CHROMIUM_FLAGS=\"--enable-features=UseOzonePlatform --ozone-platform=wayland --enable-gpu-rasterization --enable-zero-copy\"
EOF
chmod +x /etc/profile.d/rockchip-panthor.sh

rm -rf Mesa


	sed -i 's/#EXTRA_GROUPS=.*/EXTRA_GROUPS="video"/g' /etc/adduser.conf
	sed -i 's/#ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/g' /etc/adduser.conf
	echo -n "rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" > /etc/kernel/cmdline
	echo -n " quiet splash plymouth.ignore-serial-consoles" >> /etc/kernel/cmdline
	# Override u-boot-menu config 
	mkdir -p /usr/share/u-boot-menu/conf.d
	cat << 'EOF' > /usr/share/u-boot-menu/conf.d/ubuntu.conf
	U_BOOT_UPDATE="true"
	U_BOOT_PROMPT="1"
	U_BOOT_PARAMETERS="$(cat /etc/kernel/cmdline)"
	U_BOOT_TIMEOUT="20" 
EOF

	rm -f /var/lib/dbus/machine-id
	true > /etc/machine-id
	touch /var/log/syslog
	chown syslog:adm /var/log/syslog
	ssh-keygen -A

	dpkg -i kernel/*
	cd / && rm -rf kernel
	apt-get -y purge cloud-init flash-kernel fwupd ufw grub-efi-arm64
	apt-get -y autoremove
	apt-get  clean
	sync
