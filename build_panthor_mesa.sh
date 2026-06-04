#!/bin/bash
set -e # エラーが発生したらその時点で停止
set -x

echo "=== 1. 最小限のビルドツールのインストール ==="
sudo apt update
sudo apt install -y build-essential devscripts debhelper ninja-build \
    pkg-config python3-mako libdrm-dev libwayland-dev wayland-protocols \
    libx11-dev libxext-dev libxdamage-dev libxfixes-dev libxcb-glx0-dev \
    libxcb-shm0-dev libxcb-dri2-0-dev libxcb-dri3-dev libxshmfence-dev \
    libxrandr-dev libxxf86vm-dev libexpat1-dev libzstd-dev zlib1g-dev \
    python3-ply python3-yaml python3-pip python3-setuptools glslang-tools \
    spirv-tools libclc-20-dev llvm-20-dev libclang-cpp20-dev \
    libllvmspirvlib-20-dev libclang-20-dev libwayland-egl-backend-dev \
    libxcb-randr0-dev  libdrm-dev libpciaccess-dev libffi-dev libsensors-dev libxml2-dev \
  libx11-dev libx11-xcb-dev libxcb-dri2-0-dev libxcb-dri3-dev libxcb-glx0-dev \
  libxcb-present-dev libxcb-randr0-dev libxcb-shm0-dev libxcb-xfixes0-dev libxcb1-dev \
  libxdmcp-dev libxext-dev libxrandr-dev libxrender-dev libxshmfence-dev libxxf86vm-dev \
  libwayland-dev libwayland-bin libwayland-egl-backend-dev wayland-protocols \
  libglvnd-core-dev libvulkan-dev glslang-tools spirv-tools python3-pycparser


# 2. apt版の古いmesonが入っていれば削除し、pipで最新版のmesonをシステムに導入します
sudo apt-get remove -y meson
sudo python3 -m pip install --break-system-packages --upgrade meson

# 【★ここを追加★】debuildが認識できる場所にシンボリックリンクを作成します
sudo ln -sf /usr/local/bin/meson /usr/bin/meson


echo "=== 2. ソースパッケージリポジトリの有効化とソース取得 ==="
# Ubuntu 24.04の新しい形式と従来の形式の両方に対応
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    # 「deb-src」がまだ含まれていない「Types: deb」の行だけを置換する
    sudo sed -i '/deb-src/!s/Types: deb/Types: deb deb-src/g' /etc/apt/sources.list.d/ubuntu.sources
#    cat /etc/apt/sources.list.d/ubuntu.sources
else
    # 従来の形式（すでにコメントアウトが解除されている場合は何もしない）
    sudo sed -i 's/^#\s*deb-src/deb-src/' /etc/apt/sources.list
#    cat /etc/apt/sources.list
fi
sudo apt update

# 作業ディレクトリの作成
WORK_DIR="$HOME/panthor-mesa-build"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# ソースのダウンロード
apt source mesa
MESA_SRC_DIR=$(ls -d mesa-*)
cd "$MESA_SRC_DIR"

echo "=== 3. debian/rules の書き換え (Panthor最適化) ==="
# gallium-drivers の行を置換 (panfrost,kmsro,zink,softpipe のみに制限)
sed -i 's/-Dgallium-drivers=.*/-Dgallium-drivers=panfrost,kmsro,zink,softpipe/' debian/rules
# (既存のドライバー書き換え処理のあとに以下を追加してください)
# 存在しないファイルでエラーになるのを防ぐため、rm に -f フラグを追加する
sed -i 's/rm debian\/tmp\/usr\/lib\/\*\/libEGL_mesa.so/rm -f debian\/tmp\/usr\/lib\/\*\/libEGL_mesa.so/g' debian/rules
sed -i 's/rm debian\/tmp\/usr\/lib\/\*\/libGLX_mesa.so/rm -f debian\/tmp\/usr\/lib\/\*\/libGLX_mesa.so/g' debian/rules
# vdpauファイルが存在しない場合に mv コマンドでエラーになるのを防ぐパッチ
#sed -i 's/mv debian\/tmp\/usr\/lib\/\*\/vdpau/if [ -d debian\/tmp\/usr\/lib\/\*\/vdpau ]; then mv debian\/tmp\/usr\/lib\/\*\/vdpau/g' debian/rules
#sed -i 's/libvdpau\*.so\*/libvdpau\*.so\*; fi/g' debian/rules
echo "=== 3. debian/rules の書き換え (Panthor最適化) ==="
# (前略：rm -f の2行は残したままでOKです)
# 【★前回のvdpauの2行を消して、この1行に差し替えます★】
# vdpauを移動させようとする処理（連続する3行）を、先頭に「#」をつけて丸ごと無効化します
sed -i '/install -m755 -d debian\/mesa-vdpau-drivers/,/debian\/mesa-vdpau-drivers\/usr\/lib/ s/^/#/' debian/rules
# 【★今回新しく追加する1行★】
# _drv_video.soを移動させようとする処理（連続する2行）を、先頭に「#」をつけて無効化します
sed -i '/install -m755 -d debian\/mesa-va-drivers/,/debian\/mesa-va-drivers\/usr\/lib/ s/^/#/' debian/rules
truncate -s 0 debian/mesa-drm-shim.install
truncate -s 0 debian/mesa-opencl-icd.install
# 【★今回新しく追加する2行★】
# Vulkanパッケージの指示書から、生成されなかったレイヤーファイルの記述を削除します
sed -i '/libVkLayer_/d' debian/mesa-vulkan-drivers.install
sed -i '/implicit_layer.d/d' debian/mesa-vulkan-drivers.install
# 【★今回新しく追加する1行★】
# Vulkanパッケージの指示書から、explicit_layer の記述も削除します
sed -i '/explicit_layer.d/d' debian/mesa-vulkan-drivers.install
# 【★今回新しく追加する1行★】
# Vulkanパッケージの指示書から、AMD用の設定ファイルの記述を削除します
sed -i '/00-radv-defaults.conf/d' debian/mesa-vulkan-drivers.install


# vulkan-drivers の行を置換 (panfrost,swrast のみに制限)
# ※Mesaのバージョンにより指定名が panfrost か panvk か異なるため、ソースフォルダ名から自動判定
if [ -d "src/vulkan/drivers/panvk" ]; then
    VULKAN_DRIVER_NAME="panvk"
else
    VULKAN_DRIVER_NAME="panfrost"
fi
sed -i "s/-Dvulkan-drivers=.*/-Dvulkan-drivers=${VULKAN_DRIVER_NAME},swrast/" debian/rules

# LLVMを必須とする他のドライバー（iris, radeonsi等）を無効化したため、LLVM依存設定自体をオフにする
sed -i 's/-Dllvm=enabled/-Dllvm=disabled/g' debian/rules

echo "=== 4. パッケージバージョンの変更 (自動上書き防止) ==="
# バージョン末尾に「~panthor1」を自動付与
CURRENT_VERSION=$(dpkg-parsechangelog -S Version)
export DEBEMAIL="user@localhost"
export DEBFULLNAME="Panthor Builder"
debchange --force-bad-version --newversion "${CURRENT_VERSION}~panthor1" "Custom Panthor-only build without heavy dependencies"

echo "=== 5. 依存チェックを無視してビルド実行 ==="
# -d フラグで不要なビルド依存（Intel/AMD用ライブラリなど）のチェックをスキップ
debuild -us -uc -b -d

echo "=== 6. ビルド完了 ==="
cd ..
echo "以下のディレクトリにPanthor専用の .deb パッケージが生成されました:"
pwd
ls -l *.deb
cp *.deb ..
cd ..
echo "--------------------------------------------------"
echo "インストールする場合は、以下のコマンドを実行してください："
echo "cd $(pwd) && sudo dpkg -i *.deb"
echo "--------------------------------------------------"



# ubuntu-imageのフックやchroot内で実行する処理のイメージ
#dpkg -i /tmp/patches/mesa-panthor/*.deb
#apt-get install -f -y  # 実行に必要な最小限の依存（libdrm等）だけを自動解決

