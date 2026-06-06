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

# 1. デスクトップ環境を絶対に削除させないためのロック（おまじない）
echo "gnome-shell hold" | sudo dpkg --set-selections
echo "gdm3 hold" | sudo dpkg --set-selections
echo "ubuntu-desktop-minimal hold" | sudo dpkg --set-selections

	apt-get install -y gstreamer1.0-plugins-good gstreamer1.0-plugins-base gstreamer1.0-gl clapper mpv vulkan-tools mesa-utils
	dpkg -i --force-depends kernel/*
	apt-get install -f -y --no-remove
	cd / && rm -rf kernel
# 1. ユーザー「ubuntu」を作成し、パスワードを「ubuntu」に設定
# (既存の作成方法で消えていた場合、グループ指定などを強固にします)
sudo useradd -m -s /bin/bash -G sudo,video,render,plugdev,audio,dialoutubuntu
echo "ubuntu:ubuntu" | sudo chpasswd

# 2. 【★ここが最重要：Ubuntuを騙すおまじない★】
# 「すでに初回セットアップは全員終わっていますよ」というダミーの完了ファイルを強制配置します
# これにより、起動時にUbuntuがユーザーを消去・リセットする処理を完全に封じ込めます
sudo mkdir -p /var/lib/oem-config
sudo touch /var/lib/oem-config/oem-config.done

# 3. 画面が真っ黒になる原因のサービスを完全に無効化・偽装
sudo systemctl disable oem-config.service || true
sudo systemctl disable oem-config.timer || true
sudo systemctl set-default graphical.target

 apt-get -y --reinstall install ubuntu-desktop-minimal gdm3 linux-firmware snapd cloud-initramfs-growroot oem-config-gtk ubiquity-frontend-gtk ubiquity-slideshow-ubuntu yaru-theme-unity yaru-theme-icon yaru-theme-gtk aptdaemon initramfs-tools vim
 apt-get -y --reinstall install build-essential gcc-aarch64-linux-gnu bison \
qemu-user-binfmt qemu-system-arm qemu-efi-aarch64 binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs device-tree-compiler python3 \
python-is-python3 fdisk bc debhelper python3-pyelftools python3-setuptools \
python3-pkg-resources swig libfdt-dev libpython3-dev gawk \
git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex \
libelf-dev bison sudo libgnutls28-dev

	
	apt-get -y purge cloud-init flash-kernel fwupd ufw grub-efi-arm64
#	apt-get -y autoremove
	apt-get  clean
	sync
