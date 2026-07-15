#!/bin/bash
# key-renda-kidou の .app バンドルをビルドするスクリプト
#
# 使い方:
#   scripts/build-app.sh            → build/key-renda-kidou.app を作成
#   scripts/build-app.sh --install  → 作成後 ~/Applications にコピーして起動
#
# Xcode不要（コマンドラインツールのみでビルド可能）

set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="key-renda-kidou"
APP_DIR="build/${APP_NAME}.app"

echo "▶ リリースビルドを実行中..."
swift build -c release

echo "▶ .appバンドルを組み立て中..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/release/KeyRendaKidou" "$APP_DIR/Contents/MacOS/${APP_NAME}"
cp "scripts/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "▶ 署名中（ad-hoc署名）..."
codesign --force --sign - --identifier "com.morifumi.key-renda-kidou" "$APP_DIR"

echo "✅ 完成: $APP_DIR"

if [[ "${1:-}" == "--install" ]]; then
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"

    # 起動中なら終了してから差し替える
    if pgrep -x "$APP_NAME" > /dev/null; then
        echo "▶ 起動中のアプリを終了します..."
        pkill -x "$APP_NAME" || true
        sleep 1
    fi

    rm -rf "$INSTALL_DIR/${APP_NAME}.app"
    cp -R "$APP_DIR" "$INSTALL_DIR/"
    echo "✅ インストール完了: $INSTALL_DIR/${APP_NAME}.app"

    echo "▶ アプリを起動します..."
    open "$INSTALL_DIR/${APP_NAME}.app"
    echo ""
    echo "【注意】再ビルド後は署名が変わるため、システム設定 → プライバシーとセキュリティ →"
    echo "「入力監視」で key-renda-kidou を一度オフ→オンにし直す必要がある場合があります。"
fi
