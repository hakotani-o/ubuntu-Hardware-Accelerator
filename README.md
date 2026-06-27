# Ubuntu 26.04 LTS Mini-Image with Hardware Acceleration for Orange Pi 5 / 5 Plus

Orange Pi 5 および Orange Pi 5 Plus 向けに、極限まで軽量化・最適化された Ubuntu 26.04 LTS (Resolute Raccoon) のハードウェアアクセラレーション対応カスタムディスクイメージ、およびその自動ビルドツールです。

最新のメインライン環境（Linux Kernel 7.0系 ＆ Mesa 26.0系）を採用し、不要なモジュールやコンポーネントを徹底的に排除することで、超軽量かつ圧倒的にスムーズなデスクトップ体験を実現しています。

## 🚀 主な特徴

- **完全メインラインのグラフィックス駆動**:
  Mesa 26.0 (Panfrost/PanVK) により、Mali-G610 GPU のポテンシャルを100%引き出し、GNOME (Wayland) デスクトップ環境でシルクのように滑らかな描画を実現。
- **効率的なハードウェア動画デコード**:
  Linux 7.0 カーネルの V4L2 Request API と GStreamer 1.28+ (v4l2codecs) が直接連携。低発熱・低CPU負荷での4K動画再生をサポート。
- **極限のミニマリズム (1.6 GB)**:
  カーネルを限界までコンパクト化し、圧縮後のイメージサイズをわずか **1.6 GB (xz)** に集約。
- **100% Snap-Free**:
  Ubuntu 標準の Snap デーモンおよび Snap アプリを完全に排除。システムのオーバーヘッドを極限まで低減しています。
- **MesaをPanthor専用にリメイク**:
  軽量化のためMesaの再構築とUbuntu標準版、Freedesktop Mesa 26.0版の２種類を採用

## 🛠️ カーネルの最適化（無効化されたコンポーネント）

本イメージは、サーバー/特化型デスクトップとしての純粋なパフォーマンスを追求するため、以下の不要な機能をカーネルレベルで無効化し、メモリフットプリントとビルドサイズを最小化しています。

- **ネットワーク関連**: Wi-Fi, Bluetooth, IPv6, Netfilter (ファイアウォール), VLAN, DVB_NET, CAN バス
- **ファイルシステム**: NFS (Network File System)
- **入力デバイス**: ジョイスティック、タブレット、タッチスクリーン
- **その他**: `CONFIG_FTRACE` (デバッグトレース), `CONFIG_SND_HDA` (不要なオーディオドライバ), その他不要なPHYドライバ群

## 📊 パフォーマンスの目安

GNOME (Wayland) セッションにおいて、GPUが完全に駆動しているため、X11ベースのデスクトップ環境と比較して圧倒的なグラフィックス性能を発揮します。
- **GNOME (Wayland)**: `glmark2-es2-wayland` Orangepi-5 スコア **3000** をマーク

## 📦 ハードウェアアクセラレーションの体感・テスト方法

### 1. 3Dグラフィックス (GPU) のテスト
Mesa Panfrost/PanVK が正常にグラフィックスを処理しているか確認します。

```bash
# OpenGL ES のテスト
sudo apt install glmark2-es2-wayland
glmark2-es2-wayland

# Vulkan のテスト
sudo apt install vulkan-tools
vkcube
```

### 2. ビデオデコード (VPU) の確認
カーネルの V4L2 コーデックエンジンが、最新の GStreamer 経由で H.264/H.265/AV1 を認識しているか確認します。

```bash
gst-inspect-1.0 v4l2codecs
```
*`v4l2slh264dec`、`v4l2slh265dec`、`v4l2slav1dec` 等が表示されれば正常です。動画再生には GStreamer を直接叩く「Clapper」などのモダンなプレイヤーの利用を推奨します。*

### 3. 🔥 Special Feature: Pure APT Native Browsing (Snap-free)
このディスクイメージは、Orange Pi 5 / 5 Plus のハードウェアパワーを極限まで引き
出すため、**完全にSnapを排除したクリーンな設計**を採用しています。

初期状態でのディスク容量（イメージサイズ）を最小限に抑えつつ、ユーザーがいつでも
「本物のAPTネイティブ版」の Firefox, Thunderbird および chromium を導入できるよう、**Mozil
la Team PPA と xtradeb packaging team PPA の事前マッピング（APT Pinning）**をあらかじめシステムに組み込んであ
ります。

これにより、Ubuntu公式の「Snap強制ダミーパッケージ」に邪魔されることなく、超軽量
・高速なブラウジング環境をワンコマンドで手に入れることができます。
### 🚀 How to Install Native Firefox & Thunderbird & Chromium

イメージ起動後、ターミナルで以下のコマンドを実行するだけで、PPAからネイティブパ
ッケージ（APT版）が直接インストールされます。

```bash
sudo apt update
sudo apt install firefox-esr thunderbird-gnome-support chromium
```

*   **No Snap Overhead**: 起動が遅い、メモリを無駄に消費するSnapデーモンは一切動
きません。
*   **Hardware Accelerator Friendly**: SBCのリソースを最大限に活かした、軽快なパ
フォーマンスを体感してください。


## 🛠️ 開発者について (Authors)

本プロジェクトは、人間のエンジニアの構想力とAIの技術的サポートが融合した「AI共同開発（AI Co-Development）」によって誕生しました。

- **Main Lead & Build Architect**: hakotani
  - **GitHub**: [@hakotani-o](https://github.com)
  - *コンセプト設計、高度なカーネルカスタマイズ、Mesa隔離ビルド、およびGitHub自動化パイプラインの構築を担当。*

- **AI Co-Pilot & Technical Advisor**: Google AI
  - *カーネルオプションの最適化提案、Mesaビルドフラグの検証、最新Linux 7.0/Mesa 25.3環境におけるV4L2/GStreamer周りのトラブルシューティングをサポート。*

---
*本プロジェクトは、GitHub Actions を用いてソースからのカーネルビルド、Mesaの隔離コンパイル（`/opt/panthor`）、およびリリースへのアップロードを完全に自動化しています。*
