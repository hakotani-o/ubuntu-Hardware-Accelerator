#!/bin/bash
set -x

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
# Mesa
	apt-get -y install bindgen cbindgen directx-headers-dev flatbuffers-compiler flatbuffers-compiler-dev glslang-tools libclang-21-dev libclang-common-21-dev libclang-cpp21 libclang-cpp21-dev libclang-dev libclang1-21 libclc-21 libclc-21-dev libdisplay-info-dev libdrm-dev libdrm-etnaviv1 libdrm-freedreno1 libdrm-nouveau2 libdrm-radeon1 libdrm-tegra0 libffi-dev libflatbuffers-dev libflatbuffers23.5.26 libgc1 libglvnd-core-dev libllvmspirvlib-21-dev libllvmspirvlib21.1 liblzma-dev libobjc-15-dev libobjc4 libpciaccess-dev libpfm4 libpkgconf7 libpng-dev librust-allocator-api2-dev librust-arbitrary-dev librust-bumpalo-dev librust-cfg-if-dev librust-critical-section-dev librust-crossbeam-deque-dev librust-crossbeam-epoch+std-dev librust-crossbeam-epoch-dev librust-crossbeam-utils-dev librust-derive-arbitrary-dev librust-either-dev librust-equivalent-dev librust-erased-serde-dev librust-foldhash-dev librust-getrandom-dev librust-hashbrown-dev librust-indexmap-dev librust-itoa-dev librust-js-sys-dev librust-libc-dev librust-log-dev librust-malloc-size-of-dev librust-memchr-dev librust-no-panic-dev librust-once-cell-dev librust-parking-lot-core-dev librust-paste-dev librust-portable-atomic-dev librust-ppv-lite86-dev librust-proc-macro2-dev librust-quote-dev librust-rand-chacha-dev librust-rand-core+getrandom-dev librust-rand-core+serde-dev librust-rand-core+std-dev librust-rand-core-dev librust-rand-dev librust-rayon-core-dev librust-rayon-dev librust-rustc-hash-2-dev librust-rustversion-dev librust-ryu-dev librust-serde-core-dev librust-serde-derive-dev librust-serde-dev librust-serde-fmt-dev librust-serde-json-dev librust-serde-test-dev librust-smallvec-dev librust-sval-buffer-dev librust-sval-derive-dev librust-sval-dev librust-sval-dynamic-dev librust-sval-fmt-dev librust-sval-ref-dev librust-sval-serde-dev librust-syn-dev librust-unicode-ident-dev librust-value-bag-dev librust-value-bag-serde1-dev librust-value-bag-sval2-dev librust-void-dev librust-wasm-bindgen-dev librust-wasm-bindgen-macro-dev librust-wasm-bindgen-macro-support-dev librust-wasm-bindgen-shared-dev librust-zerocopy-derive-dev librust-zerocopy-dev libsensors-dev libset-scalar-perl libstd-rust-1.93 libstd-rust-1.93-dev libva-dev libva-glx2 libva-wayland2 libva-x11-2 libvulkan-dev libwayland-bin libwayland-dev libwayland-egl-backend-dev libx11-dev libx11-xcb-dev libxau-dev libxcb-dri2-0 libxcb-dri2-0-dev libxcb-dri3-dev libxcb-glx0-dev libxcb-present-dev libxcb-randr0-dev libxcb-render0-dev libxcb-shape0-dev libxcb-shm0-dev libxcb-sync-dev libxcb-xfixes0-dev libxcb1-dev libxdmcp-dev libxext-dev libxml2-dev libxrandr-dev libxrender-dev libxshmfence-dev libxtensor-dev libxxf86vm-dev llvm-21 llvm-21-dev llvm-21-linker-tools llvm-21-runtime llvm-21-tools llvm-spirv-21 meson ninja-build nlohmann-json3-dev pkgconf pkgconf-bin python3-mako python3-pycparser rustc rustc-1.93 rustfmt rustfmt-1.93 spirv-tools spirv-tools-dev spirv-tools-headers valgrind wayland-protocols x11proto-dev xorg-sgml-doctools xtl-dev xtrans-dev
	mkdir mesa && cd mesa && git clone --depth 1 -b staging/25.3 https://gitlab.freedesktop.org/mesa/mesa.git && cd mesa && mkdir build && cd build && meson setup .. -Dvulkan-drivers=panfrost -Dgallium-drivers=panfrost -Dlibunwind=false -Dprefix=/opt/panthor && ninja install && cd ..
	echo /opt/panthor/lib/aarch64-linux-gnu | tee /etc/ld.so.conf.d/0-panthor.conf && ldconfig
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
	rm -rf mesa

	dpkg -i kernel/*
	cd / && rm -rf kernel
	apt-get -y purge cloud-init flash-kernel fwupd ufw grub-efi-arm64
	apt-get -y autoremove
	apt-get  clean
	sync
