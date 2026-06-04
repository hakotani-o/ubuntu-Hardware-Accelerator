#!/bin/bash
set -e # エラーが発生したらその時点で停止
set -x

echo "=== 1. 最小限のビルドツールのインストール ==="
sudo apt update
sudo apt install -y build-essential devscripts debhelper meson ninja-build \
    pkg-config python3-mako libdrm-dev libwayland-dev wayland-protocols \
    libx11-dev libxext-dev libxdamage-dev libxfixes-dev libxcb-glx0-dev \
    libxcb-shm0-dev libxcb-dri2-0-dev libxcb-dri3-dev libxshmfence-dev \
    libxrandr-dev libxxf86vm-dev libexpat1-dev libzstd-dev zlib1g-dev \
    python3-ply python3-yaml

echo "=== 2. ソースパッケージリポジトリの有効化とソース取得 ==="
# Ubuntu 24.04の新しい形式と従来の形式の両方に対応
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    # 「deb-src」がまだ含まれていない「Types: deb」の行だけを置換する
    sudo sed -i '/deb-src/!s/Types: deb/Types: deb deb-src/g' /etc/apt/sources.list.d/ubuntu.sources
    cat /etc/apt/sources.list.d/ubuntu.sources
else
    # 従来の形式（すでにコメントアウトが解除されている場合は何もしない）
    sudo sed -i 's/^#\s*deb-src/deb-src/' /etc/apt/sources.list
    cat /etc/apt/sources.list
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
sed -i 's/-Dgallium-drivers=.*/-Dgallium-drivers=panfrost/' debian/rules

# vulkan-drivers の行を置換 (panfrost,swrast のみに制限)
# ※Mesaのバージョンにより指定名が panfrost か panvk か異なるため、ソースフォルダ名から自動判定
if [ -d "src/vulkan/drivers/panvk" ]; then
    VULKAN_DRIVER_NAME="panvk"
else
    VULKAN_DRIVER_NAME="panfrost"
fi
sed -i "s/-Dvulkan-drivers=.*/-Dvulkan-drivers=${VULKAN_DRIVER_NAME},swrast \\/" debian/rules

# LLVMを必須とする他のドライバー（iris, radeonsi等）を無効化したため、LLVM依存設定自体をオフにする
sed -i 's/-Dllvm=enabled/-Dllvm=disabled/g' debian/rules

echo "=== 4. パッケージバージョンの変更 (自動上書き防止) ==="
# バージョン末尾に「~panthor1」を自動付与
export DEBEMAIL="user@localhost"
export DEBFULLNAME="Panthor Builder"
debchange --v "echo \$(dpkg-parsechangelog -S Version)~panthor1" "Custom Panthor-only build without heavy dependencies"

echo "=== 5. 依存チェックを無視してビルド実行 ==="
# -d フラグで不要なビルド依存（Intel/AMD用ライブラリなど）のチェックをスキップ
debuild -us -uc -b -d

echo "=== 6. ビルド完了 ==="
cd ..
echo "以下のディレクトリにPanthor専用の .deb パッケージが生成されました:"
pwd
ls -l *.deb

echo "--------------------------------------------------"
echo "インストールする場合は、以下のコマンドを実行してください："
echo "cd $(pwd) && sudo dpkg -i *.deb"
echo "--------------------------------------------------"



# ubuntu-imageのフックやchroot内で実行する処理のイメージ
#dpkg -i /tmp/patches/mesa-panthor/*.deb
#apt-get install -f -y  # 実行に必要な最小限の依存（libdrm等）だけを自動解決

